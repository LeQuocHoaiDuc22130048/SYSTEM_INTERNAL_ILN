import 'package:flutter/widgets.dart';

/// A gentler page snap after a swipe, evaluated against elapsed time by Flutter.
class SmoothBannerPhysics extends PageScrollPhysics {
  const SmoothBannerPhysics({super.parent});
  @override
  SmoothBannerPhysics applyTo(ScrollPhysics? ancestor) =>
      SmoothBannerPhysics(parent: buildParent(ancestor));
  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 1, stiffness: 65, ratio: 1.1);
  @override
  double get maxFlingVelocity => 1800;
}
