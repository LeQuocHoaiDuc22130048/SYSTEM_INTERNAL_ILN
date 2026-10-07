import 'package:flutter/material.dart';
import '../theme/app_motion.dart';

/// Shared horizontal axis transition; all tab subtrees retain their state.
class SmoothTabStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final bool? isForward;
  const SmoothTabStack({
    super.key,
    required this.index,
    required this.children,
    this.isForward,
  });
  @override
  State<SmoothTabStack> createState() => _SmoothTabStackState();
}

class _SmoothTabStackState extends State<SmoothTabStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.page,
    value: 1,
  )..addStatusListener(_onStatus);
  late final Animation<double> _incoming = _controller.drive(
    CurveTween(curve: const Interval(.3, 1, curve: AppMotion.curve)),
  );
  late final Animation<double> _leaving = _controller.drive(
    CurveTween(curve: const Interval(0, .3, curve: AppMotion.curve)),
  );
  int? _outgoing;
  bool _forward = true;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && _outgoing != null) {
      setState(() => _outgoing = null);
    }
  }

  @override
  void didUpdateWidget(SmoothTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _outgoing = oldWidget.index;
      _forward = widget.isForward ?? widget.index > oldWidget.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final direction = _forward ? 1.0 : -1.0;
    // Stable keys let us put the incoming page on top without recreating tabs.
    final indices = [
      for (var i = 0; i < widget.children.length; i++)
        if (i != widget.index) i,
      widget.index,
    ];
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final i in indices)
            Offstage(
              key: ValueKey('shared-axis-tab-$i'),
              offstage: i != widget.index && (reduced || i != _outgoing),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Offstage(
                  offstage:
                      !reduced &&
                      _outgoing != null &&
                      (i == widget.index
                          ? _controller.value < .3
                          : _controller.value >= .3),
                  child: child,
                ),
                child: TickerMode(
                  enabled: i == widget.index,
                  child: ExcludeFocus(
                    excluding: i != widget.index,
                    child: IgnorePointer(
                      ignoring: i != widget.index,
                      child: ExcludeSemantics(
                        excluding: i != widget.index,
                        child: SlideTransition(
                          position: reduced
                              ? const AlwaysStoppedAnimation(Offset.zero)
                              : (i == widget.index ? _incoming : _leaving)
                                    .drive(
                                      Tween(
                                        begin: i == widget.index
                                            ? Offset(.12 * direction, 0)
                                            : Offset.zero,
                                        end: i == _outgoing
                                            ? Offset(-.12 * direction, 0)
                                            : Offset.zero,
                                      ),
                                    ),
                          child: RepaintBoundary(
                            child: ColoredBox(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: FadeTransition(
                                opacity: reduced
                                    ? const AlwaysStoppedAnimation(1.0)
                                    : (i == widget.index ? _incoming : _leaving)
                                          .drive(
                                            Tween(
                                              begin: i == widget.index
                                                  ? 0.0
                                                  : 1.0,
                                              end: i == _outgoing ? 0.0 : 1.0,
                                            ),
                                          ),
                                child: widget.children[i],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
