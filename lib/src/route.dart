// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// Modified to support full-screen back gesture detection.

/// @docImport 'dart:ui';
///
/// @docImport 'package:flutter/material.dart';
/// @docImport 'package:flutter/services.dart';
///

library;

import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

const double _kBackGestureWidth = 20.0;
const double _kMinFlingVelocity = 1.0;

const Duration _kDroppedSwipePageAnimationDuration = Duration(milliseconds: 350);

const Color _kCupertinoPageTransitionBarrierColor = Color(0x18000000);

/// Barrier color for a Cupertino modal barrier.
const Color kCupertinoModalBarrierColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x33000000),
  darkColor: Color(0x7A000000),
);

const Duration _kModalPopupTransitionDuration = Duration(milliseconds: 335);

final Animatable<Offset> _kRightMiddleTween = Tween<Offset>(
  begin: const Offset(1.0, 0.0),
  end: Offset.zero,
);

final Animatable<Offset> _kMiddleLeftTween = Tween<Offset>(
  begin: Offset.zero,
  end: const Offset(-1.0 / 3.0, 0.0),
);

final Animatable<Offset> _kBottomUpTween = Tween<Offset>(
  begin: const Offset(0.0, 1.0),
  end: Offset.zero,
);

/// A mixin that replaces the entire screen with an iOS transition for a
/// [PageRoute] with full-screen back gesture support.
///
/// The page slides in from the right and exits in reverse. The page also shifts
/// to the left in parallax when another page enters to cover it.
mixin CupertinoRouteTransitionMixin<T> on PageRoute<T> {
  /// Builds the primary contents of the route.
  @protected
  Widget buildContent(BuildContext context);

  /// A title string for this route.
  String? get title;

  ValueNotifier<String?>? _previousTitle;

  /// The title string of the previous [CupertinoPageRoute].
  ValueListenable<String?> get previousTitle {
    assert(
      _previousTitle != null,
      'Cannot read the previousTitle for a route that has not yet been installed',
    );
    return _previousTitle!;
  }

  @override
  void dispose() {
    _previousTitle?.dispose();
    super.dispose();
  }

  @override
  void didChangePrevious(Route<dynamic>? previousRoute) {
    final String? previousTitleString =
        previousRoute is CupertinoRouteTransitionMixin ? previousRoute.title : null;
    if (_previousTitle == null) {
      _previousTitle = ValueNotifier<String?>(previousTitleString);
    } else {
      _previousTitle!.value = previousTitleString;
    }
    super.didChangePrevious(previousRoute);
  }

  /// The duration of the page transition.
  static const Duration kTransitionDuration = Duration(milliseconds: 500);

  @override
  Duration get transitionDuration => kTransitionDuration;

  @override
  Color? get barrierColor => fullscreenDialog ? null : _kCupertinoPageTransitionBarrierColor;

  @override
  String? get barrierLabel => null;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    final bool nextRouteIsNotFullscreen =
        (nextRoute is! PageRoute<T>) || !nextRoute.fullscreenDialog;

    final bool nextRouteHasDelegatedTransition =
        nextRoute is ModalRoute<T> && nextRoute.delegatedTransition != null;

    return nextRouteIsNotFullscreen &&
        ((nextRoute is CupertinoRouteTransitionMixin) || nextRouteHasDelegatedTransition);
  }

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) {
    return previousRoute is PageRoute && !fullscreenDialog;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget child = buildContent(context);
    return Semantics(scopesRoute: true, explicitChildNodes: true, child: child);
  }

  static _CupertinoBackGestureController<T> _startPopGesture<T>(PageRoute<T> route) {
    assert(route.popGestureEnabled);

    return _CupertinoBackGestureController<T>(
      navigator: route.navigator!,
      getIsCurrent: () => route.isCurrent,
      getIsActive: () => route.isActive,
      controller: route.controller!,
    );
  }

  /// Builds page transitions with full-screen back gesture support.
  static Widget buildPageTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final bool linearTransition = route.popGestureInProgress;
    if (route.fullscreenDialog) {
      return CupertinoFullscreenDialogTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: linearTransition,
        child: child,
      );
    } else {
      return CupertinoPageTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: linearTransition,
        child: _CupertinoBackGestureDetector<T>(
          enabledCallback: () => route.popGestureEnabled,
          onStartPopGesture: () => _startPopGesture<T>(route),
          child: child,
        ),
      );
    }
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildPageTransitions<T>(this, context, animation, secondaryAnimation, child);
  }
}

/// A modal route that replaces the entire screen with an iOS transition.
class CupertinoPageRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin<T> {
  /// Creates a page route for use in an iOS designed app.
  CupertinoPageRoute({
    required this.builder,
    this.title,
    super.settings,
    super.requestFocus,
    this.maintainState = true,
    super.fullscreenDialog,
    super.allowSnapshotting = true,
    super.barrierDismissible = false,
  }) {
    assert(opaque);
  }

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      CupertinoPageTransition.delegatedTransition;

  /// Builds the primary contents of the route.
  final WidgetBuilder builder;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  final String? title;

  @override
  final bool maintainState;

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';
}

class _PageBasedCupertinoPageRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin<T> {
  _PageBasedCupertinoPageRoute({required CupertinoPage<T> page, super.allowSnapshotting = true})
      : super(settings: page) {
    assert(opaque);
  }

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      fullscreenDialog ? null : CupertinoPageTransition.delegatedTransition;

  CupertinoPage<T> get _page => settings as CupertinoPage<T>;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  String? get title => _page.title;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}

/// A page that creates a cupertino style [PageRoute].
class CupertinoPage<T> extends Page<T> {
  /// Creates a cupertino page.
  const CupertinoPage({
    required this.child,
    this.maintainState = true,
    this.title,
    this.fullscreenDialog = false,
    this.allowSnapshotting = true,
    super.canPop,
    super.onPopInvoked,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  /// The content to be shown in the [Route] created by this page.
  final Widget child;

  /// A title string for this route.
  final String? title;

  /// Whether this route is maintained in memory.
  final bool maintainState;

  /// Whether this route replaces the whole screen with a fullscreen dialog.
  final bool fullscreenDialog;

  /// Whether this route allows snapshotting.
  final bool allowSnapshotting;

  @override
  Route<T> createRoute(BuildContext context) {
    return _PageBasedCupertinoPageRoute<T>(page: this, allowSnapshotting: allowSnapshotting);
  }
}

/// Provides an iOS-style page transition animation.
class CupertinoPageTransition extends StatefulWidget {
  /// Creates an iOS-style page transition.
  const CupertinoPageTransition({
    super.key,
    required this.primaryRouteAnimation,
    required this.secondaryRouteAnimation,
    required this.child,
    required this.linearTransition,
  });

  /// The widget below this widget in the tree.
  final Widget child;

  /// Primary route animation (0.0 to 1.0 when being pushed).
  final Animation<double> primaryRouteAnimation;

  /// Secondary route animation (0.0 to 1.0 when covered by another page).
  final Animation<double> secondaryRouteAnimation;

  /// Whether to perform transitions linearly (for gesture tracking).
  final bool linearTransition;

  /// The Cupertino styled [DelegatedTransitionBuilder].
  static Widget? delegatedTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    final CurvedAnimation animation = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.linearToEaseOut,
      reverseCurve: Curves.easeInToLinear,
    );
    final Animation<Offset> delegatedPositionAnimation = animation.drive(_kMiddleLeftTween);
    animation.dispose();

    assert(debugCheckHasDirectionality(context));
    final TextDirection textDirection = Directionality.of(context);
    return SlideTransition(
      position: delegatedPositionAnimation,
      textDirection: textDirection,
      transformHitTests: false,
      child: child,
    );
  }

  @override
  State<CupertinoPageTransition> createState() => _CupertinoPageTransitionState();
}

class _CupertinoPageTransitionState extends State<CupertinoPageTransition> {
  late Animation<Offset> _primaryPositionAnimation;
  late Animation<Offset> _secondaryPositionAnimation;
  late Animation<Decoration> _primaryShadowAnimation;
  CurvedAnimation? _primaryPositionCurve;
  CurvedAnimation? _secondaryPositionCurve;
  CurvedAnimation? _primaryShadowCurve;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(covariant CupertinoPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryRouteAnimation != widget.primaryRouteAnimation ||
        oldWidget.secondaryRouteAnimation != widget.secondaryRouteAnimation ||
        oldWidget.linearTransition != widget.linearTransition) {
      _disposeCurve();
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _disposeCurve();
    super.dispose();
  }

  void _disposeCurve() {
    _primaryPositionCurve?.dispose();
    _secondaryPositionCurve?.dispose();
    _primaryShadowCurve?.dispose();
    _primaryPositionCurve = null;
    _secondaryPositionCurve = null;
    _primaryShadowCurve = null;
  }

  void _setupAnimation() {
    if (!widget.linearTransition) {
      _primaryPositionCurve = CurvedAnimation(
        parent: widget.primaryRouteAnimation,
        curve: Curves.fastEaseInToSlowEaseOut,
        reverseCurve: Curves.fastEaseInToSlowEaseOut.flipped,
      );
      _secondaryPositionCurve = CurvedAnimation(
        parent: widget.secondaryRouteAnimation,
        curve: Curves.linearToEaseOut,
        reverseCurve: Curves.easeInToLinear,
      );
      _primaryShadowCurve = CurvedAnimation(
        parent: widget.primaryRouteAnimation,
        curve: Curves.linearToEaseOut,
      );
    }
    _primaryPositionAnimation = (_primaryPositionCurve ?? widget.primaryRouteAnimation).drive(
      _kRightMiddleTween,
    );
    _secondaryPositionAnimation = (_secondaryPositionCurve ?? widget.secondaryRouteAnimation).drive(
      _kMiddleLeftTween,
    );
    _primaryShadowAnimation = (_primaryShadowCurve ?? widget.primaryRouteAnimation).drive(
      _CupertinoEdgeShadowDecoration.kTween,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    final TextDirection textDirection = Directionality.of(context);
    return SlideTransition(
      position: _secondaryPositionAnimation,
      textDirection: textDirection,
      transformHitTests: false,
      child: SlideTransition(
        position: _primaryPositionAnimation,
        textDirection: textDirection,
        child: DecoratedBoxTransition(decoration: _primaryShadowAnimation, child: widget.child),
      ),
    );
  }
}

/// An iOS-style transition used for summoning fullscreen dialogs.
class CupertinoFullscreenDialogTransition extends StatefulWidget {
  /// Creates an iOS-style transition for fullscreen dialogs.
  const CupertinoFullscreenDialogTransition({
    super.key,
    required this.primaryRouteAnimation,
    required this.secondaryRouteAnimation,
    required this.child,
    required this.linearTransition,
  });

  final Animation<double> primaryRouteAnimation;
  final Animation<double> secondaryRouteAnimation;
  final bool linearTransition;
  final Widget child;

  @override
  State<CupertinoFullscreenDialogTransition> createState() =>
      _CupertinoFullscreenDialogTransitionState();
}

class _CupertinoFullscreenDialogTransitionState extends State<CupertinoFullscreenDialogTransition> {
  late Animation<Offset> _primaryPositionAnimation;
  late Animation<Offset> _secondaryPositionAnimation;
  CurvedAnimation? _primaryPositionCurve;
  CurvedAnimation? _secondaryPositionCurve;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(covariant CupertinoFullscreenDialogTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryRouteAnimation != widget.primaryRouteAnimation ||
        oldWidget.secondaryRouteAnimation != widget.secondaryRouteAnimation ||
        oldWidget.linearTransition != widget.linearTransition) {
      _disposeCurve();
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _disposeCurve();
    super.dispose();
  }

  void _disposeCurve() {
    _primaryPositionCurve?.dispose();
    _secondaryPositionCurve?.dispose();
    _primaryPositionCurve = null;
    _secondaryPositionCurve = null;
  }

  void _setupAnimation() {
    _primaryPositionAnimation = (_primaryPositionCurve = CurvedAnimation(
      parent: widget.primaryRouteAnimation,
      curve: Curves.linearToEaseOut,
      reverseCurve: Curves.linearToEaseOut.flipped,
    ))
        .drive(_kBottomUpTween);
    _secondaryPositionAnimation = (widget.linearTransition
            ? widget.secondaryRouteAnimation
            : _secondaryPositionCurve = CurvedAnimation(
                parent: widget.secondaryRouteAnimation,
                curve: Curves.linearToEaseOut,
                reverseCurve: Curves.easeInToLinear,
              ))
        .drive(_kMiddleLeftTween);
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    final TextDirection textDirection = Directionality.of(context);
    return SlideTransition(
      position: _secondaryPositionAnimation,
      textDirection: textDirection,
      transformHitTests: false,
      child: SlideTransition(position: _primaryPositionAnimation, child: widget.child),
    );
  }
}

// Full-screen back gesture detector
class _CupertinoBackGestureDetector<T> extends StatefulWidget {
  const _CupertinoBackGestureDetector({
    super.key,
    required this.enabledCallback,
    required this.onStartPopGesture,
    required this.child,
  });

  final Widget child;
  final ValueGetter<bool> enabledCallback;
  final ValueGetter<_CupertinoBackGestureController<T>> onStartPopGesture;

  @override
  _CupertinoBackGestureDetectorState<T> createState() => _CupertinoBackGestureDetectorState<T>();
}

class _CupertinoBackGestureDetectorState<T> extends State<_CupertinoBackGestureDetector<T>> {
  _CupertinoBackGestureController<T>? _backGestureController;

  late HorizontalDragGestureRecognizer _recognizer;

  final Set<int> _trackedPointers = <int>{};

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    _trackedPointers.clear();

    if (_backGestureController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_backGestureController?.navigator.mounted ?? false) {
          _backGestureController?.navigator.didStopUserGesture();
        }
        _backGestureController = null;
      });
    }
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    assert(mounted);
    assert(_backGestureController == null);
    _backGestureController = widget.onStartPopGesture();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    assert(mounted);
    assert(_backGestureController != null);
    _backGestureController!.dragUpdate(
      _convertToLogical(details.primaryDelta! / context.size!.width),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    assert(mounted);
    assert(_backGestureController != null);
    _backGestureController!.dragEnd(
      _convertToLogical(details.velocity.pixelsPerSecond.dx / context.size!.width),
    );
    _backGestureController = null;
    _trackedPointers.clear();
  }

  void _handleDragCancel() {
    assert(mounted);
    _backGestureController?.dragEnd(0.0);
    _backGestureController = null;
    _trackedPointers.clear();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_trackedPointers.contains(event.pointer)) {
      _trackedPointers.add(event.pointer);
      if (widget.enabledCallback()) {
        _recognizer.addPointer(event);
      } else {
        _trackedPointers.remove(event.pointer);
      }
    }
  }

  double _convertToLogical(double value) {
    return switch (Directionality.of(context)) {
      TextDirection.rtl => -value,
      TextDirection.ltr => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    final double dragAreaWidth = switch (Directionality.of(context)) {
      TextDirection.rtl => MediaQuery.paddingOf(context).right,
      TextDirection.ltr => MediaQuery.paddingOf(context).left,
    };
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        // Full screen gesture support - wrap child with Listener
        Listener(
          onPointerDown: _handlePointerDown,
          behavior: HitTestBehavior.translucent,
          child: widget.child,
        ),
        PositionedDirectional(
          start: 0.0,
          width: max(dragAreaWidth, _kBackGestureWidth),
          top: 0.0,
          bottom: 0.0,
          child: Listener(onPointerDown: _handlePointerDown, behavior: HitTestBehavior.translucent),
        ),
      ],
    );
  }
}

class _CupertinoBackGestureController<T> {
  _CupertinoBackGestureController({
    required this.navigator,
    required this.controller,
    required this.getIsActive,
    required this.getIsCurrent,
  }) {
    navigator.didStartUserGesture();
  }

  final AnimationController controller;
  final NavigatorState navigator;
  final ValueGetter<bool> getIsActive;
  final ValueGetter<bool> getIsCurrent;

  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  void dragEnd(double velocity) {
    const Curve animationCurve = Curves.fastEaseInToSlowEaseOut;
    final bool isCurrent = getIsCurrent();
    final bool animateForward;

    if (!isCurrent) {
      animateForward = getIsActive();
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    if (animateForward) {
      controller.animateTo(
        1.0,
        duration: _kDroppedSwipePageAnimationDuration,
        curve: animationCurve,
      );
    } else {
      if (isCurrent) {
        navigator.pop();
      }

      if (controller.isAnimating) {
        controller.animateBack(
          0.0,
          duration: _kDroppedSwipePageAnimationDuration,
          curve: animationCurve,
        );
      }
    }

    if (controller.isAnimating) {
      late AnimationStatusListener animationStatusCallback;
      animationStatusCallback = (AnimationStatus status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(animationStatusCallback);
      };
      controller.addStatusListener(animationStatusCallback);
    } else {
      navigator.didStopUserGesture();
    }
  }
}

class _CupertinoEdgeShadowDecoration extends Decoration {
  const _CupertinoEdgeShadowDecoration._([this._colors]);

  static DecorationTween kTween = DecorationTween(
    begin: const _CupertinoEdgeShadowDecoration._(),
    end: const _CupertinoEdgeShadowDecoration._(
      <Color>[Color(0x04000000), CupertinoColors.transparent],
    ),
  );

  final List<Color>? _colors;

  static _CupertinoEdgeShadowDecoration? lerp(
    _CupertinoEdgeShadowDecoration? a,
    _CupertinoEdgeShadowDecoration? b,
    double t,
  ) {
    if (identical(a, b)) {
      return a;
    }
    if (a == null) {
      return b!._colors == null
          ? b
          : _CupertinoEdgeShadowDecoration._(
              b._colors!.map<Color>((Color color) => Color.lerp(null, color, t)!).toList(),
            );
    }
    if (b == null) {
      return a._colors == null
          ? a
          : _CupertinoEdgeShadowDecoration._(
              a._colors!.map<Color>((Color color) => Color.lerp(null, color, 1.0 - t)!).toList(),
            );
    }
    assert(b._colors != null || a._colors != null);
    assert(b._colors == null || a._colors == null || a._colors!.length == b._colors!.length);
    return _CupertinoEdgeShadowDecoration._(<Color>[
      for (int i = 0; i < b._colors!.length; i += 1) Color.lerp(a._colors?[i], b._colors![i], t)!,
    ]);
  }

  @override
  _CupertinoEdgeShadowDecoration lerpFrom(Decoration? a, double t) {
    if (a is _CupertinoEdgeShadowDecoration) {
      return _CupertinoEdgeShadowDecoration.lerp(a, this, t)!;
    }
    return _CupertinoEdgeShadowDecoration.lerp(null, this, t)!;
  }

  @override
  _CupertinoEdgeShadowDecoration lerpTo(Decoration? b, double t) {
    if (b is _CupertinoEdgeShadowDecoration) {
      return _CupertinoEdgeShadowDecoration.lerp(this, b, t)!;
    }
    return _CupertinoEdgeShadowDecoration.lerp(this, null, t)!;
  }

  @override
  _CupertinoEdgeShadowPainter createBoxPainter([VoidCallback? onChanged]) {
    return _CupertinoEdgeShadowPainter(this, onChanged);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _CupertinoEdgeShadowDecoration && other._colors == _colors;
  }

  @override
  int get hashCode => _colors.hashCode;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<Color>('colors', _colors));
  }
}

class _CupertinoEdgeShadowPainter extends BoxPainter {
  _CupertinoEdgeShadowPainter(this._decoration, super.onChanged)
      : assert(_decoration._colors == null || _decoration._colors!.length > 1);

  final _CupertinoEdgeShadowDecoration _decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final List<Color>? colors = _decoration._colors;
    if (colors == null) {
      return;
    }

    final double shadowWidth = 0.05 * configuration.size!.width;
    final double shadowHeight = configuration.size!.height;
    final double bandWidth = shadowWidth / (colors.length - 1);

    final TextDirection? textDirection = configuration.textDirection;
    assert(textDirection != null);
    final (double shadowDirection, double start) = switch (textDirection!) {
      TextDirection.rtl => (1, offset.dx + configuration.size!.width),
      TextDirection.ltr => (-1, offset.dx),
    };

    int bandColorIndex = 0;
    for (int dx = 0; dx < shadowWidth; dx += 1) {
      if (dx ~/ bandWidth != bandColorIndex) {
        bandColorIndex += 1;
      }
      final Paint paint = Paint()
        ..color = Color.lerp(
          colors[bandColorIndex],
          colors[bandColorIndex + 1],
          (dx % bandWidth) / bandWidth,
        )!;
      final double x = start + shadowDirection * dx;
      canvas.drawRect(Rect.fromLTWH(x - 1.0, offset.dy, 1.0, shadowHeight), paint);
    }
  }
}

const double _kStandardStiffness = 522.35;
const double _kStandardDamping = 45.7099552;
const SpringDescription _kStandardSpring = SpringDescription(
  mass: 1,
  stiffness: _kStandardStiffness,
  damping: _kStandardDamping,
);
const Tolerance _kStandardTolerance = Tolerance(velocity: 0.03);

/// A route that shows a modal iOS-style popup.
class CupertinoModalPopupRoute<T> extends PopupRoute<T> {
  /// Creates a modal iOS-style popup route.
  CupertinoModalPopupRoute({
    required this.builder,
    this.barrierLabel = 'Dismiss',
    this.barrierColor = kCupertinoModalBarrierColor,
    bool barrierDismissible = true,
    bool semanticsDismissible = false,
    super.filter,
    super.settings,
    super.requestFocus,
    this.anchorPoint,
  })  : _barrierDismissible = barrierDismissible,
        _semanticsDismissible = semanticsDismissible;

  final WidgetBuilder builder;
  final bool _barrierDismissible;
  final bool _semanticsDismissible;

  @override
  final String barrierLabel;

  @override
  final Color? barrierColor;

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  bool get semanticsDismissible => _semanticsDismissible;

  @override
  Duration get transitionDuration => _kModalPopupTransitionDuration;

  final Offset? anchorPoint;

  @override
  Simulation createSimulation({required bool forward}) {
    assert(!debugTransitionCompleted(), 'Cannot reuse a $runtimeType after disposing it.');
    final double end = forward ? 1.0 : 0.0;
    return SpringSimulation(
      _kStandardSpring,
      controller!.value,
      end,
      0,
      tolerance: _kStandardTolerance,
      snapToEnd: true,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return CupertinoUserInterfaceLevel(
      data: CupertinoUserInterfaceLevelData.elevated,
      child: DisplayFeatureSubScreen(
        anchorPoint: anchorPoint,
        child: Builder(builder: builder),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionalTranslation(translation: _offsetTween.evaluate(animation), child: child),
    );
  }

  static final Tween<Offset> _offsetTween = Tween<Offset>(
    begin: const Offset(0.0, 1.0),
    end: Offset.zero,
  );
}

/// Shows a modal iOS-style popup.
Future<T?> showCupertinoModalPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  ImageFilter? filter,
  Color barrierColor = kCupertinoModalBarrierColor,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  bool semanticsDismissible = false,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  bool? requestFocus,
}) {
  return Navigator.of(context, rootNavigator: useRootNavigator).push(
    CupertinoModalPopupRoute<T>(
      builder: builder,
      filter: filter,
      barrierColor: CupertinoDynamicColor.resolve(barrierColor, context),
      barrierDismissible: barrierDismissible,
      semanticsDismissible: semanticsDismissible,
      settings: routeSettings,
      anchorPoint: anchorPoint,
      requestFocus: requestFocus,
    ),
  );
}

Widget _buildCupertinoDialogTransitions(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return child;
}

/// Shows an iOS-style dialog.
Future<T?> showCupertinoDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? barrierLabel,
  Color? barrierColor,
  bool useRootNavigator = true,
  bool barrierDismissible = false,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  bool? requestFocus,
}) {
  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    CupertinoDialogRoute<T>(
      builder: builder,
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: barrierColor,
      settings: routeSettings,
      anchorPoint: anchorPoint,
      requestFocus: requestFocus,
    ),
  );
}

/// A dialog route that shows an iOS-style dialog.
class CupertinoDialogRoute<T> extends RawDialogRoute<T> {
  /// Creates an iOS-style dialog route.
  CupertinoDialogRoute({
    required WidgetBuilder builder,
    required BuildContext context,
    super.barrierDismissible,
    Color? barrierColor,
    String? barrierLabel,
    super.transitionDuration = const Duration(milliseconds: 250),
    this.transitionBuilder,
    super.settings,
    super.requestFocus,
    super.anchorPoint,
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return builder(context);
          },
          transitionBuilder: transitionBuilder ?? _buildCupertinoDialogTransitions,
          barrierLabel: barrierLabel ?? CupertinoLocalizations.of(context).modalBarrierDismissLabel,
          barrierColor:
              barrierColor ?? CupertinoDynamicColor.resolve(kCupertinoModalBarrierColor, context),
        );

  RouteTransitionsBuilder? transitionBuilder;

  CurvedAnimation? _fadeAnimation;

  @override
  Simulation createSimulation({required bool forward}) {
    assert(!debugTransitionCompleted(), 'Cannot reuse a $runtimeType after disposing it.');
    final double end = forward ? 1.0 : 0.0;
    return SpringSimulation(
      _kStandardSpring,
      controller!.value,
      end,
      0,
      tolerance: _kStandardTolerance,
      snapToEnd: true,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (transitionBuilder != null) {
      return super.buildTransitions(context, animation, secondaryAnimation, child);
    }

    if (animation.status == AnimationStatus.reverse) {
      return FadeTransition(opacity: animation, child: child);
    }
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: animation.drive(_dialogScaleTween), child: child),
    );
  }

  @override
  void dispose() {
    _fadeAnimation?.dispose();
    super.dispose();
  }

  static final Tween<double> _dialogScaleTween = Tween<double>(begin: 1.3, end: 1.0);
}
