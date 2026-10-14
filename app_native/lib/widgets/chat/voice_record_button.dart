import 'package:flutter/material.dart';
import '../../services/voice_recorder.dart';
import '../../utils/voice_composer_controller.dart';

class VoiceRecordButton extends StatefulWidget {
  const VoiceRecordButton({
    super.key,
    required this.onSend,
    this.recorder,
    this.enabled = true,
    this.onBusyChanged,
  });
  final Future<void> Function(RecordedVoice) onSend;
  final VoiceRecorder? recorder;
  final bool enabled;
  final ValueChanged<bool>? onBusyChanged;
  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton>
    with WidgetsBindingObserver {
  late final VoiceComposerController _voice;
  bool _cancel = false;
  Offset? _origin;
  String? _lastError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice = VoiceComposerController(
      recorder: widget.recorder ?? DeviceVoiceRecorder(),
      onSend: (voice) => widget.onSend(voice),
    )..addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    widget.onBusyChanged?.call(_voice.state != VoiceComposerState.idle);
    if (_voice.error != null && _voice.error != _lastError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_voice.error!)));
    }
    _lastError = _voice.error;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _voice.finish(cancel: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voice.removeListener(_changed);
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active =
        _voice.state == VoiceComposerState.starting ||
        _voice.state == VoiceComposerState.recording;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_voice.state == VoiceComposerState.failed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _voice.retry,
                tooltip: 'Gửi lại ghi âm',
                icon: const Icon(Icons.send),
              ),
              IconButton(
                onPressed: _voice.discard,
                tooltip: 'Bỏ ghi âm',
                icon: const Icon(Icons.close),
              ),
            ],
          )
        else if (_voice.state == VoiceComposerState.sending)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          Tooltip(
            message: 'Giữ để ghi âm, thả để gửi; kéo trái để hủy',
            child: Listener(
              onPointerCancel: (_) => _voice.finish(cancel: true),
              child: GestureDetector(
                onLongPressStart: !widget.enabled
                    ? null
                    : (details) {
                        _origin = details.globalPosition;
                        _cancel = false;
                        _voice.start();
                      },
                onLongPressMoveUpdate: (details) {
                  if (_origin != null) {
                    setState(
                      () => _cancel =
                          details.globalPosition.dx < _origin!.dx - 60,
                    );
                  }
                },
                onLongPressEnd: (_) => _voice.finish(cancel: _cancel),
                onLongPressCancel: () => _voice.finish(cancel: true),
                child: Semantics(
                  label: 'Giữ để ghi âm tin nhắn thoại',
                  button: true,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      active ? Icons.mic : Icons.mic_none,
                      color: active
                          ? Colors.red
                          : widget.enabled
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (active)
          SizedBox(
            width: 90,
            child: Text(
              _cancel ? 'Thả để hủy' : '${_voice.seconds}s · Kéo trái để hủy',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10),
            ),
          ),
      ],
    );
  }
}
