import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Shared motion and interaction tokens for the CRM Flutter app
/// aligned with docs/CRM_MOTION_DESIGN_SYSTEM.md.
///
/// Durations are wall-clock time; Flutter's ticker samples at the display vsync.
class AppMotion {
  const AppMotion._();

  // Duration tokens (Section 4.1)
  static const instant = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const medium = Duration(milliseconds: 350);
  static const slow = Duration(milliseconds: 500);
  static const data = Duration(milliseconds: 800);

  // Navigation & component defaults
  static const page = Duration(milliseconds: 200);
  static const sheet = Duration(milliseconds: 250);
  static const banner = Duration(milliseconds: 1200);
  static const bannerHold = Duration(seconds: 6);

  // Easing tokens (Section 4.2 Flutter approximations)
  static const Curve easeStandard = Curves.easeInOutCubic;
  static const Curve easeEnter = Curves.easeOutCubic;
  static const Curve easeExit = Curves.easeInCubic;
  static const Curve easeEmphasized = Curves.easeOutCubic;
  static const Curve curve = Curves.easeInOutSine;

  // Motion distances & scales (Section 4.3)
  static const double distanceXs = 4.0;
  static const double distanceSm = 8.0;
  static const double distanceMd = 16.0;
  static const double scalePressed = 0.97;
  static const double scaleEnter = 0.98;

  /// Returns true when the platform or accessibility settings request reduced motion.
  static bool isReduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Resolves [duration] to [Duration.zero] when reduced motion is enabled.
  static Duration resolveDuration(BuildContext context, Duration duration) =>
      isReduced(context) ? Duration.zero : duration;

  /// Resolves [normalCurve] to [Curves.linear] when reduced motion is enabled.
  static Curve resolveCurve(BuildContext context, Curve normalCurve) =>
      isReduced(context) ? Curves.linear : normalCurve;

  static const transitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _AndroidTransitions(),
      TargetPlatform.iOS: _CupertinoTransitions(),
      TargetPlatform.macOS: _CupertinoTransitions(),
      TargetPlatform.windows: _AndroidTransitions(),
      TargetPlatform.linux: _AndroidTransitions(),
      TargetPlatform.fuchsia: _AndroidTransitions(),
    },
  );
}

class _AndroidTransitions extends FadeForwardsPageTransitionsBuilder {
  const _AndroidTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context != null && MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    final progress = animation.drive(CurveTween(curve: AppMotion.curve));
    return SlideTransition(
      position: progress.drive(
        Tween(begin: const Offset(.12, 0), end: Offset.zero),
      ),
      child: SlideTransition(
        position: secondaryAnimation
            .drive(CurveTween(curve: AppMotion.curve))
            .drive(Tween(begin: Offset.zero, end: const Offset(-.12, 0))),
        child: RepaintBoundary(
          child: ColoredBox(
            color: context == null
                ? Colors.white
                : Theme.of(context).scaffoldBackgroundColor,
            child: FadeTransition(
              opacity: progress.drive(Tween(begin: .92, end: 1.0)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Duration get reverseTransitionDuration => Duration.zero;
}

class _CupertinoTransitions extends CupertinoPageTransitionsBuilder {
  const _CupertinoTransitions();

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Duration get reverseTransitionDuration => Duration.zero;
}
