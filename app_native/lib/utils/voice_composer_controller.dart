import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/voice_recorder.dart';

enum VoiceComposerState { idle, starting, recording, sending, failed }

class VoiceComposerController extends ChangeNotifier {
  VoiceComposerController({required this.recorder, required this.onSend});
  final VoiceRecorder recorder;
  final Future<void> Function(RecordedVoice) onSend;
  VoiceComposerState state = VoiceComposerState.idle;
  RecordedVoice? pending;
  String? error;
  int seconds = 0;
  Timer? _timer;
  bool _released = false;
  bool _cancel = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_disposed || state != VoiceComposerState.idle) return;
    _released = false;
    _cancel = false;
    seconds = 0;
    error = null;
    state = VoiceComposerState.starting;
    notifyListeners();
    try {
      await recorder.start();
      if (_disposed) {
        await recorder.cancel();
        return;
      }
      state = VoiceComposerState.recording;
      notifyListeners();
      if (_released) {
        await finish(cancel: _cancel);
        return;
      }
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        seconds++;
        notifyListeners();
        if (seconds >= 120) unawaited(finish());
      });
    } catch (_) {
      try {
        await recorder.cancel();
      } catch (error) {
        debugPrint('Voice recording cleanup failed: $error');
      }
      if (!_disposed) {
        state = VoiceComposerState.idle;
        error = 'Không thể ghi âm. Hãy cho phép truy cập micro và thử lại.';
        notifyListeners();
      }
    }
  }

  Future<void> finish({bool cancel = false}) async {
    if (_disposed) return;
    if (state == VoiceComposerState.starting) {
      _released = true;
      _cancel = _cancel || cancel;
      return;
    }
    if (state != VoiceComposerState.recording) return;
    _timer?.cancel();
    state = VoiceComposerState.sending;
    notifyListeners();
    try {
      if (cancel) {
        await recorder.cancel();
      } else {
        final voice = await recorder.stop();
        if (voice.bytes.isNotEmpty &&
            voice.duration >= const Duration(milliseconds: 500)) {
          pending = voice;
        }
      }
      if (_disposed) return;
      if (pending != null) {
        await _sendPending();
      } else {
        state = VoiceComposerState.idle;
        notifyListeners();
      }
    } catch (_) {
      if (!_disposed) {
        state = VoiceComposerState.idle;
        error = 'Không thể hoàn tất ghi âm. Vui lòng thử lại.';
        notifyListeners();
      }
    }
  }

  Future<void> _sendPending() async {
    try {
      await onSend(pending!);
      if (_disposed) return;
      pending = null;
      error = null;
      state = VoiceComposerState.idle;
    } catch (_) {
      if (_disposed) return;
      error = 'Không thể gửi tin nhắn thoại. Bạn có thể gửi lại.';
      state = VoiceComposerState.failed;
    }
    notifyListeners();
  }

  Future<void> retry() async {
    if (_disposed || pending == null || state != VoiceComposerState.failed) {
      return;
    }
    state = VoiceComposerState.sending;
    error = null;
    notifyListeners();
    await _sendPending();
  }

  void discard() {
    if (state != VoiceComposerState.failed) return;
    pending = null;
    error = null;
    state = VoiceComposerState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(
      recorder.dispose().catchError((Object error) {
        debugPrint('Voice recorder disposal failed: $error');
      }),
    );
    super.dispose();
  }
}
