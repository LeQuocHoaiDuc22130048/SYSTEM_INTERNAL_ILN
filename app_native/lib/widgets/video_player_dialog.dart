import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';
import '../services/video_download.dart';
import '../theme/app_colors.dart';
import '../utils/media_auth_headers.dart';

class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? senderName;
  const VideoPlayerDialog({
    super.key,
    required this.videoUrl,
    required this.title,
    this.senderName,
  });
  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late final VideoPlayerController _controller;
  Timer? _hideTimer;
  Timer? _seekTimer;
  bool _initialized = false;
  bool _showControls = true;
  bool _saving = false;
  bool _dragging = false;
  bool _closing = false;
  bool _resumeAfterScrub = false;
  double _dragOffset = 0;
  double? _scrubPosition;
  int? _seekDirection;
  String? _errorMessage;
  String? _saveMessage;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      httpHeaders: mediaAuthHeaders(context, widget.videoUrl),
    )..addListener(_onPlaybackChanged);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      await _controller.setLooping(true);
      if (!mounted) return;
      setState(() => _initialized = true);
      await _controller.play();
      if (mounted) _resetHideTimer();
    } catch (_) {
      if (mounted) _showPlaybackError();
    }
  }

  void _showPlaybackError() {
    _hideTimer?.cancel();
    setState(() {
      _showControls = true;
      _errorMessage =
          'Không thể phát video này. Vui lòng kiểm tra lại kết nối mạng.';
    });
  }

  void _onPlaybackChanged() {
    if (!mounted) return;
    if (_controller.value.hasError && _errorMessage == null) {
      _showPlaybackError();
    } else if (!_controller.value.isPlaying && !_showControls) {
      _hideTimer?.cancel();
      setState(() => _showControls = true);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekTimer?.cancel();
    _controller.removeListener(_onPlaybackChanged);
    _controller.dispose();
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (!_controller.value.isPlaying ||
        _scrubPosition != null ||
        _dragging ||
        _saving ||
        _errorMessage != null ||
        _closing) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    if (!_initialized || _errorMessage != null || _closing) return;
    setState(() {
      _showControls = !_showControls;
      _saveMessage = null;
    });
    if (_showControls) {
      _resetHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  Future<void> _togglePlay() async {
    try {
      if (_controller.value.isPlaying) {
        await _controller.pause();
      } else {
        await _controller.play();
      }
      if (!mounted) return;
      setState(() => _showControls = true);
      _resetHideTimer();
    } catch (_) {
      if (mounted) _showPlaybackError();
    }
  }

  Future<void> _toggleMute() async {
    try {
      await _controller.setVolume(_controller.value.volume == 0 ? 1 : 0);
      if (mounted) _resetHideTimer();
    } catch (_) {
      if (mounted) _showPlaybackError();
    }
  }

  Future<void> _seekBy(int seconds) async {
    if (!_initialized || _errorMessage != null || _scrubPosition != null) {
      return;
    }
    final value = _controller.value;
    final target = (value.position.inMilliseconds + seconds * 1000).clamp(
      0,
      value.duration.inMilliseconds,
    );
    try {
      await _controller.seekTo(Duration(milliseconds: target));
    } catch (_) {
      if (mounted) _showPlaybackError();
      return;
    }
    if (!mounted) return;
    _seekTimer?.cancel();
    setState(() {
      _showControls = true;
      _seekDirection = seconds;
    });
    _seekTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekDirection = null);
    });
    _resetHideTimer();
  }

  void _startScrub(double position) {
    _hideTimer?.cancel();
    _resumeAfterScrub = _controller.value.isPlaying;
    setState(() => _scrubPosition = position);
    _controller.pause();
  }

  Future<void> _endScrub(double position) async {
    try {
      await _controller.seekTo(Duration(milliseconds: position.round()));
      if (!mounted) return;
      if (_resumeAfterScrub) await _controller.play();
    } catch (_) {
      if (mounted) _showPlaybackError();
    } finally {
      if (mounted) {
        setState(() => _scrubPosition = null);
        _resetHideTimer();
      }
    }
  }

  void _resetDrag() {
    if (_closing) return;
    setState(() {
      _dragging = false;
      _dragOffset = 0;
    });
    _resetHideTimer();
  }

  Future<void> _close() async {
    if (_closing) return;
    _hideTimer?.cancel();
    setState(() {
      _closing = true;
      _dragging = false;
      _dragOffset = MediaQuery.sizeOf(context).height;
    });
    // Closing must remain possible even when the native player has failed.
    try {
      await _controller.pause();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveVideo() async {
    if (_saving) return;
    final headers = mediaAuthHeaders(context, widget.videoUrl);
    _hideTimer?.cancel();
    setState(() {
      _saving = true;
      _saveMessage = null;
    });
    String message;
    try {
      await saveVideoToGallery(widget.videoUrl, headers: headers);
      message = 'Đã lưu video vào thư viện ảnh.';
    } on GalException catch (error) {
      message = switch (error.type) {
        GalExceptionType.accessDenied =>
          'Vui lòng cho phép lưu video vào thư viện ảnh trong cài đặt.',
        GalExceptionType.notEnoughSpace =>
          'Thiết bị không còn đủ dung lượng để lưu video.',
        GalExceptionType.notSupportedFormat =>
          'Định dạng video này không được thư viện ảnh hỗ trợ.',
        GalExceptionType.unexpected => 'Không thể lưu video. Vui lòng thử lại.',
      };
    } catch (_) {
      message = 'Không thể tải video. Vui lòng kiểm tra kết nối và thử lại.';
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _showControls = true;
      _saveMessage = message;
    });
    _resetHideTimer();
  }

  String _formatTime(Duration duration) {
    final seconds = duration.inSeconds;
    final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return seconds >= 3600
        ? '${seconds ~/ 3600}:$minutes:$remainder'
        : '$minutes:$remainder';
  }

  Widget _fadeControls(Widget child) => IgnorePointer(
    ignoring: !_showControls || _closing,
    child: AnimatedOpacity(
      opacity: _showControls && !_closing ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) => Dialog.fullscreen(
    backgroundColor: Colors.transparent,
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: _dragOffset),
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, offset, _) {
        final progress = (offset / MediaQuery.sizeOf(context).height).clamp(
          0.0,
          1.0,
        );
        return ColoredBox(
          color: Colors.black.withValues(alpha: 1 - progress),
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller,
            builder: (context, value, _) => Listener(
              onPointerCancel: (_) => _resetDrag(),
              child: GestureDetector(
                onVerticalDragStart: (_) {
                  if (_closing) return;
                  _hideTimer?.cancel();
                  setState(() => _dragging = true);
                },
                onVerticalDragUpdate: (details) {
                  if (_closing) return;
                  setState(
                    () => _dragOffset = (_dragOffset + details.delta.dy).clamp(
                      0.0,
                      MediaQuery.sizeOf(context).height,
                    ),
                  );
                },
                onVerticalDragCancel: _resetDrag,
                onVerticalDragEnd: (_) =>
                    _dragOffset > 120 ? _close() : _resetDrag(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      onDoubleTapDown: (details) => _seekBy(
                        details.localPosition.dx <
                                MediaQuery.sizeOf(context).width / 2
                            ? -10
                            : 10,
                      ),
                      onDoubleTap: () {},
                      child: Transform.translate(
                        offset: Offset(0, offset),
                        child: Transform.scale(
                          scale: 1 - progress * 0.25,
                          child: SafeArea(
                            child: Center(child: _videoContent(value)),
                          ),
                        ),
                      ),
                    ),
                    if (_initialized && _errorMessage == null)
                      Center(
                        child: _fadeControls(
                          IconButton.filled(
                            tooltip: value.isPlaying ? 'Tạm dừng' : 'Phát',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.all(16),
                            ),
                            onPressed: _togglePlay,
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Icon(
                                value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                key: ValueKey(value.isPlaying),
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_seekDirection != null)
                      IgnorePointer(
                        child: Align(
                          alignment: _seekDirection! < 0
                              ? const Alignment(-0.65, 0)
                              : const Alignment(0.65, 0),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _seekDirection! < 0
                                      ? Icons.fast_rewind
                                      : Icons.fast_forward,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                const Text(
                                  '10 giây',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _fadeControls(_topBar(value)),
                    ),
                    if (_saveMessage != null &&
                        (!_initialized || _errorMessage != null))
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _saveMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    if (_initialized && _errorMessage == null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _fadeControls(_bottomBar(value)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _videoContent(VideoPlayerValue value) {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    if (!_initialized) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 12),
          Text('Đang tải video...', style: TextStyle(color: Colors.white70)),
        ],
      );
    }
    return AspectRatio(
      aspectRatio: value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }

  Widget _topBar(VideoPlayerValue value) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black87, Colors.transparent],
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Đóng',
              onPressed: _close,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.senderName?.trim().isNotEmpty == true)
                    Text(
                      'Video từ ${widget.senderName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: value.volume == 0 ? 'Bật tiếng' : 'Tắt tiếng',
              onPressed: _initialized && _errorMessage == null
                  ? _toggleMute
                  : null,
              icon: Icon(
                value.volume == 0 ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
              ),
            ),
            IconButton(
              tooltip: _saving ? 'Đang lưu video' : 'Lưu video',
              onPressed: _saving ? null : _saveVideo,
              icon: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_outlined, color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _bottomBar(VideoPlayerValue value) {
    final maximum = value.duration.inMilliseconds.toDouble();
    final position =
        (_scrubPosition ?? value.position.inMilliseconds.toDouble()).clamp(
          0.0,
          maximum,
        );
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_saveMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _saveMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              Row(
                children: [
                  Text(
                    _formatTime(Duration(milliseconds: position.round())),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 20,
                        ),
                      ),
                      child: Slider(
                        value: position,
                        max: maximum > 0 ? maximum : 1,
                        activeColor: AppColors.primary,
                        inactiveColor: Colors.white30,
                        semanticFormatterCallback: (value) =>
                            _formatTime(Duration(milliseconds: value.round())),
                        onChangeStart: maximum > 0 ? _startScrub : null,
                        onChanged: maximum > 0
                            ? (value) => setState(() => _scrubPosition = value)
                            : null,
                        onChangeEnd: maximum > 0 ? _endScrub : null,
                      ),
                    ),
                  ),
                  Text(
                    _formatTime(value.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
