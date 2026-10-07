import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A touch-optimized widget providing immediate spring-scale feedback
/// (<16ms zero-latency response via Listener) and tactile haptic response on press.
///
/// Performance optimizations:
/// - Uses `ScaleTransition` directly to update the transform matrix at the RenderObject level
/// - Uses `RepaintBoundary` to isolate the repainting layer from sibling/parent widgets
/// - Zero widget rebuilds during animation frames
/// - Syncs with gesture arena (`onTapCancel`) to instantly bounce back when user scrolls
class InteractiveBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final Duration duration;
  final Duration reverseDuration;
  final Curve curve;
  final Curve reverseCurve;
  final bool enableHaptic;
  final HitTestBehavior behavior;

  const InteractiveBounce({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.95,
    this.duration = const Duration(milliseconds: 100),
    this.reverseDuration = const Duration(milliseconds: 180),
    this.curve = Curves.easeInOutCubic,
    this.reverseCurve = Curves.easeOutBack,
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<InteractiveBounce> createState() => _InteractiveBounceState();
}

class _InteractiveBounceState extends State<InteractiveBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.reverseDuration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
        reverseCurve: widget.reverseCurve,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _isPressed = true;
    _controller.forward();
    if (widget.enableHaptic) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
  }

  void _handleTapCancel() {
    if (!_isPressed) return;
    _isPressed = false;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bool isInteractive = widget.onTap != null || widget.onLongPress != null;
    if (!isInteractive) {
      return widget.child;
    }

    return Listener(
      behavior: widget.behavior,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: Alignment.center,
          child: RepaintBoundary(
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
