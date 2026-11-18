import 'package:flutter/material.dart';
import '../theme/app_motion.dart';

/// Displays a formatted KPI string (e.g. "42", "12/20", "8.5") and animates
/// its leading numeric value once when data first appears (`600–900ms`),
/// jumping straight to the target on subsequent updates or when reduced motion
/// is enabled (CRM Motion Design System Section 5.9).
class AnimatedKpiValue extends StatefulWidget {
  final String value;
  final TextStyle? style;
  final Duration duration;

  const AnimatedKpiValue({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 750),
  });

  @override
  State<AnimatedKpiValue> createState() => _AnimatedKpiValueState();
}

class _AnimatedKpiValueState extends State<AnimatedKpiValue>
    with SingleTickerProviderStateMixin {
  static final RegExp _leadingNumberRegex = RegExp(r'^(\d+(?:\.\d+)?)(.*)$');

  late final AnimationController _controller;
  bool _hasAnimatedInitial = false;
  double? _targetNumber;
  int _decimals = 0;
  String _suffix = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _parseValue(widget.value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeStartInitialAnimation();
  }

  @override
  void didUpdateWidget(AnimatedKpiValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _parseValue(widget.value);
      _maybeStartInitialAnimation();
    }
  }

  void _parseValue(String raw) {
    final match = _leadingNumberRegex.firstMatch(raw.trim());
    if (match == null) {
      _targetNumber = null;
      _decimals = 0;
      _suffix = '';
      return;
    }
    final numPart = match.group(1)!;
    _targetNumber = double.tryParse(numPart);
    final dotIndex = numPart.indexOf('.');
    _decimals = dotIndex >= 0 ? (numPart.length - dotIndex - 1) : 0;
    _suffix = match.group(2) ?? '';
  }

  void _maybeStartInitialAnimation() {
    if (_hasAnimatedInitial) {
      _controller.value = 1.0;
      return;
    }
    final target = _targetNumber;
    if (target == null || target <= 0 || AppMotion.isReduced(context)) {
      _controller.value = 1.0;
      return;
    }
    _hasAnimatedInitial = true;
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatAnimated(double t) {
    final target = _targetNumber;
    if (target == null) return widget.value;
    final eased = AppMotion.easeEnter.transform(t.clamp(0.0, 1.0));
    final current = target * eased;
    final formatted = _decimals > 0
        ? current.toStringAsFixed(_decimals)
        : current.round().toString();
    return '$formatted$_suffix';
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.isReduced(context);
    if (reduced || _targetNumber == null || _targetNumber! <= 0) {
      return Semantics(
        label: widget.value,
        child: Text(widget.value, style: widget.style),
      );
    }

    return Semantics(
      label: widget.value,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final text = _controller.isCompleted
              ? widget.value
              : _formatAnimated(_controller.value);
          return Text(text, style: widget.style);
        },
      ),
    );
  }
}

