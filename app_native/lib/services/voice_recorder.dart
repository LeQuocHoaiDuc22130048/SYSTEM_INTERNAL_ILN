import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordedVoice {
  const RecordedVoice({
    required this.bytes,
    required this.filename,
    required this.duration,
  });
  final Uint8List bytes;
  final String filename;
  final Duration duration;
}

abstract interface class VoiceRecorder {
  Future<void> start();
  Future<RecordedVoice> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class DeviceVoiceRecorder implements VoiceRecorder {
  AudioRecorder? _device;
  AudioRecorder get _recorder => _device ??= AudioRecorder();
  final _elapsed = Stopwatch();
  String? _path;
  bool _disposed = false;

  @override
  Future<void> start() async {
    if (_disposed) return;
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission denied');
    }
    final directory = await getTemporaryDirectory();
    if (_disposed) return;
    _path =
        '${directory.path}/chat-voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: _path!,
    );
    if (_disposed) {
      await cancel();
      return;
    }
    _elapsed
      ..reset()
      ..start();
  }

  Future<void> _deleteFile() async {
    final path = _path;
    _path = null;
    if (path != null && await File(path).exists()) await File(path).delete();
  }

  @override
  Future<RecordedVoice> stop() async {
    _elapsed.stop();
    final path = _path;
    try {
      await _recorder.stop();
      if (path == null) throw StateError('Recording unavailable');
      final bytes = await File(path).readAsBytes();
      return RecordedVoice(
        bytes: bytes,
        filename: path.split(RegExp(r'[/\\]')).last,
        duration: _elapsed.elapsed,
      );
    } finally {
      await _deleteFile();
    }
  }

  @override
  Future<void> cancel() async {
    _elapsed.stop();
    try {
      await _device?.cancel();
    } finally {
      await _deleteFile();
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    try {
      await _device?.dispose();
    } finally {
      await _deleteFile();
    }
  }
}
