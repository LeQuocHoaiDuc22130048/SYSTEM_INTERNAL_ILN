import 'package:flutter/material.dart';
import '../theme/app_motion.dart';

/// A widget that switches between child views with a horizontal slide transition.
///
/// When [isForward] is true (moving forward / navigating to a new page):
/// - The incoming view slides in from right to center (Offset(0.18, 0) -> Offset.zero).
/// - The outgoing view slides out from center to left (Offset.zero -> Offset(-0.18, 0)).
///
/// When [isForward] is false (going back / returning to previous page):
/// - The previous view appears immediately without animating.
class DirectionalSlideSwitcher extends StatelessWidget {
  final Widget child;
  final bool isForward;
  final Duration duration;
  final Curve curve;

  const DirectionalSlideSwitcher({
    super.key,
    required this.child,
    this.isForward = true,
    this.duration = AppMotion.page,
    this.curve = AppMotion.curve,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: isForward ? duration : Duration.zero,
        reverseDuration: isForward ? duration : Duration.zero,
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (isForward && previousChildren.isNotEmpty)
                IgnorePointer(
                  child: ExcludeSemantics(child: previousChildren.last),
                ),
              ?currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          if (!isForward) return child;
          final bool isIncoming = child.key == this.child.key;
          final Offset inOffset = isForward
              ? const Offset(.18, 0.0)
              : const Offset(-.18, 0.0);
          final Offset outOffset = isForward
              ? const Offset(-.18, 0.0)
              : const Offset(.18, 0.0);

          final progress = CurvedAnimation(parent: animation, curve: curve);
          final Animation<Offset> slide = Tween<Offset>(
            begin: isIncoming ? inOffset : outOffset,
            end: Offset.zero,
          ).animate(progress);

          return SlideTransition(
            position: slide,
            child: RepaintBoundary(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: FadeTransition(
                  opacity: progress.drive(Tween(begin: .92, end: 1.0)),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: child,
      ),
    );
  }
}
