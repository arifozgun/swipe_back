import 'package:flutter/material.dart';
import 'route.dart';

/// A [PageTransitionsBuilder] that provides iOS-style page transitions
/// with **full screen** back gesture support.
///
/// Unlike Flutter's default Cupertino transitions which only detect
/// back gestures from the left edge (20px), this builder allows
/// swiping from anywhere on the screen to navigate back.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     pageTransitionsTheme: PageTransitionsTheme(
///       builders: {
///         TargetPlatform.iOS: SwipeBackPageTransitionsBuilder(),
///         TargetPlatform.android: SwipeBackPageTransitionsBuilder(),
///       },
///     ),
///   ),
/// )
/// ```
class SwipeBackPageTransitionsBuilder extends PageTransitionsBuilder {
  /// Constructs a page transition animation that matches the iOS transition
  /// with full-screen back gesture support.
  const SwipeBackPageTransitionsBuilder();

  @override
  Duration get transitionDuration => CupertinoRouteTransitionMixin.kTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      CupertinoPageTransition.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
