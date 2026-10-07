import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

/// Durations are wall-clock time; Flutter's ticker samples at the display vsync.
class AppMotion {
  const AppMotion._();
  static const page = Duration(milliseconds: 900);
  static const banner = Duration(milliseconds: 1200);
  static const bannerHold = Duration(seconds: 6);
  static const curve = Curves.easeInOutSine;

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
  Duration get reverseTransitionDuration => AppMotion.page;
}

class _CupertinoTransitions extends CupertinoPageTransitionsBuilder {
  const _CupertinoTransitions();
  @override
  Duration get transitionDuration => AppMotion.page;
  @override
  Duration get reverseTransitionDuration => AppMotion.page;
}
