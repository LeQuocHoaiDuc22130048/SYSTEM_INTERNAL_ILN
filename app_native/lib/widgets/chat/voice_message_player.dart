import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../utils/media_auth_headers.dart';

bool isVoiceAttachment(String? mediaUrl) {
  final path = Uri.tryParse(mediaUrl ?? '')?.path.toLowerCase() ?? '';
  return path.endsWith('.m4a') ||
      path.endsWith('.aac') ||
      path.endsWith('.mp3') ||
      path.endsWith('.wav') ||
      path.endsWith('.ogg');
}

class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({super.key, required this.url, required this.color});
  final String url;
  final Color color;
  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _player;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _player?.pause();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) _player?.pause();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_player == null) {
        final player = VideoPlayerController.networkUrl(
          Uri.parse(widget.url),
          httpHeaders: mediaAuthHeaders(context, widget.url),
        );
        _player = player;
        player.addListener(_changed);
        await player.initialize();
      }
      if (!mounted) return;
      final player = _player!;
      if (player.value.hasError) throw StateError('Audio unavailable');
      if (player.value.isPlaying) {
        await player.pause();
      } else {
        if (player.value.position >= player.value.duration) {
          await player.seekTo(Duration.zero);
        }
        await player.play();
      }
    } catch (_) {
      final player = _player;
      _player = null;
      player?.removeListener(_changed);
      await player?.dispose();
      if (mounted) setState(() => _error = 'Không thể phát. Bấm để thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player?.removeListener(_changed);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    String time(Duration value) =>
        '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
    return SizedBox(
      width: 230,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _loading ? null : _toggle,
                tooltip: player?.value.isPlaying == true
                    ? 'Tạm dừng'
                    : 'Phát tin nhắn thoại',
                icon: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.color,
                        ),
                      )
                    : Icon(
                        player?.value.isPlaying == true
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: widget.color,
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tin nhắn thoại',
                      style: TextStyle(color: widget.color, fontSize: 13),
                    ),
                    if (player?.value.isInitialized == true)
                      Text(
                        '${time(player!.value.position)} / ${time(player.value.duration)}',
                        style: TextStyle(color: widget.color, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (player?.value.isInitialized == true)
            Slider(
              value: player!.value.position.inMilliseconds
                  .clamp(0, player.value.duration.inMilliseconds)
                  .toDouble(),
              max: player.value.duration.inMilliseconds.toDouble().clamp(
                1,
                double.infinity,
              ),
              onChanged: (value) =>
                  player.seekTo(Duration(milliseconds: value.round())),
            ),
          if (_error != null)
            Text(_error!, style: TextStyle(fontSize: 11, color: widget.color)),
        ],
      ),
    );
  }
}
