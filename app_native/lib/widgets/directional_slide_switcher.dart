import 'package:flutter/material.dart';

/// A widget that switches between child views with a horizontal slide transition.
///
/// When [isForward] is true (moving forward / navigating to a new page):
/// - The incoming view slides in from right to center (Offset(1.0, 0) -> Offset.zero).
/// - The outgoing view slides out from center to left (Offset.zero -> Offset(-1.0, 0)).
///
/// When [isForward] is false (going back / returning to previous page):
/// - The incoming view slides in from left to center (Offset(-1.0, 0) -> Offset.zero).
/// - The outgoing view slides out from center to right (Offset.zero -> Offset(1.0, 0)).
class DirectionalSlideSwitcher extends StatelessWidget {
  final Widget child;
  final bool isForward;
  final Duration duration;
  final Curve curve;

  const DirectionalSlideSwitcher({
    super.key,
    required this.child,
    this.isForward = true,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final bool isIncoming = child.key == this.child.key;
        final Offset inOffset =
            isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
        final Offset outOffset =
            isForward ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);

        final Animation<Offset> slide = Tween<Offset>(
          begin: isIncoming ? inOffset : outOffset,
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: curve,
        ));

        return SlideTransition(
          position: slide,
          child: child,
        );
      },
      child: child,
    );
  }
}
