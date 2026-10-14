import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

class ChatMessageGestures extends StatefulWidget {
  const ChatMessageGestures({
    super.key,
    required this.child,
    required this.onReply,
    required this.onLongPress,
    required this.onDoubleTap,
    this.onTap,
    this.enabled = true,
  });
  final Widget child;
  final VoidCallback onReply;
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;
  final VoidCallback? onTap;
  final bool enabled;
  @override
  State<ChatMessageGestures> createState() => _ChatMessageGesturesState();
}

class _ChatMessageGesturesState extends State<ChatMessageGestures>
    with TickerProviderStateMixin {
  late final AnimationController _returnController;
  late final AnimationController _pulseController;
  double _dragOffset = 0;
  double _returnFrom = 0;
  bool _dragging = false;
  bool _hapticSent = false;
  bool _pointerCancelled = false;

  @override
  void initState() {
    super.initState();
    _returnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() => setState(() {}));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() => setState(() {}));
  }

  void _startDrag(DragStartDetails details) {
    _returnController.stop();
    setState(() {
      _dragging = true;
      _dragOffset = 0;
      _hapticSent = false;
      _pointerCancelled = false;
    });
  }

  void _updateDrag(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta.dx);
    if (!_hapticSent && _dragOffset.abs() >= 50) {
      _hapticSent = true;
      HapticFeedback.lightImpact();
    }
  }

  void _returnToRest() {
    _returnFrom = _visualOffset;
    _dragging = false;
    _dragOffset = 0;
    _returnController.forward(from: 0);
  }

  double get _visualOffset => _dragging
      ? _dragOffset.sign *
            (math.min(_dragOffset.abs(), 50) +
                math.max(0, _dragOffset.abs() - 50) * 0.25)
      : _returnFrom *
            (1 - Curves.easeOutBack.transform(_returnController.value));

  @override
  void dispose() {
    _returnController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      // Accepted Flutter drags report dragEnd even for pointer cancellation.
      onPointerCancel: (_) => _pointerCancelled = true,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: _startDrag,
        onHorizontalDragUpdate: _updateDrag,
        onHorizontalDragEnd: (_) {
          final reply = !_pointerCancelled && _dragOffset.abs() >= 50;
          _returnToRest();
          if (reply) widget.onReply();
        },
        onHorizontalDragCancel: _returnToRest,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onDoubleTap: () {
          _pulseController.forward(from: 0);
          widget.onDoubleTap();
        },
        child: Transform.translate(
          offset: Offset(_visualOffset, 0),
          child: Transform.scale(
            scale: 1 + 0.04 * math.sin(math.pi * _pulseController.value),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
