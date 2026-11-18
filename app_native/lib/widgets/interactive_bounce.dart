import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_motion.dart';

/// A touch-optimized widget providing calm press-scale feedback
/// (`scale = 0.97` by default, `100–150ms`) and tactile haptic response on press.
///
/// Performance & Accessibility:
/// - Uses `ScaleTransition` directly to update the transform matrix at the RenderObject level
/// - Uses `RepaintBoundary` to isolate repainting from sibling/parent widgets
/// - Respects `MediaQuery.disableAnimationsOf(context)` by skipping scale animation
/// - Syncs with gesture arena (`onTapCancel`) to return smoothly when user scrolls
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
    this.scaleDown = AppMotion.scalePressed,
    this.duration = AppMotion.instant,
    this.reverseDuration = AppMotion.fast,
    this.curve = AppMotion.easeStandard,
    this.reverseCurve = AppMotion.easeEnter,
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
    if (!AppMotion.isReduced(context)) {
      _controller.forward();
    }
    if (widget.enableHaptic) {
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_isPressed) return;
    _isPressed = false;
    if (_controller.value > 0) {
      _controller.reverse();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (!_isPressed) return;
    _isPressed = false;
    if (_controller.value > 0) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (!_isPressed) return;
    _isPressed = false;
    if (_controller.value > 0) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isInteractive =
        widget.onTap != null || widget.onLongPress != null;
    if (!isInteractive) {
      return widget.child;
    }

    final bool reduceMotion = AppMotion.isReduced(context);

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
        child: reduceMotion
            ? widget.child
            : ScaleTransition(
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
