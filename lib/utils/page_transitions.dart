import 'package:flutter/material.dart';

/// Route transitions stay under 300 ms and use a strong ease-out, so a page change feels
/// immediate (docs/PERFORMANCE.md).
const Duration kPageTransitionDuration = Duration(milliseconds: 250);
const Curve kPageTransitionCurve = Cubic(0.23, 1, 0.32, 1);

/// Page de transition avec fondu et zoom
class FadeZoomPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;
  final Curve curve;

  FadeZoomPageRoute({
    required this.page,
    this.duration = kPageTransitionDuration,
    this.curve = kPageTransitionCurve,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: curve,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}

/// Page de transition avec glissement
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;
  final Curve curve;
  final SlideDirection direction;

  SlidePageRoute({
    required this.page,
    this.duration = kPageTransitionDuration,
    this.curve = kPageTransitionCurve,
    this.direction = SlideDirection.right,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: curve,
            );

            // Déterminer l'offset en fonction de la direction
            Offset begin;
            switch (direction) {
              case SlideDirection.right:
                begin = const Offset(-1.0, 0.0);
                break;
              case SlideDirection.left:
                begin = const Offset(1.0, 0.0);
                break;
              case SlideDirection.up:
                begin = const Offset(0.0, 1.0);
                break;
              case SlideDirection.down:
                begin = const Offset(0.0, -1.0);
                break;
            }

            // Slide only: a fade on top would composite the whole incoming page in an
            // offscreen layer on every frame of the transition.
            return SlideTransition(
              position: Tween<Offset>(
                begin: begin,
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );
          },
        );
}

/// Direction du glissement pour SlidePageRoute
enum SlideDirection {
  right,
  left,
  up,
  down,
}

/// Page de transition avec un effet de rebond
class BouncePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  BouncePageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 500),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final bounceAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.elasticOut,
            );

            return ScaleTransition(
              scale: Tween<double>(begin: 0.6, end: 1.0).animate(bounceAnimation),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                  ),
                ),
                child: child,
              ),
            );
          },
        );
}

/// Wrapper pour animer les transitions entre widgets sans navigation
class AnimatedPageSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final PageTransitionType transitionType;

  const AnimatedPageSwitcher({
    super.key,
    required this.child,
    this.duration = kPageTransitionDuration,
    this.transitionType = PageTransitionType.fade,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (Widget child, Animation<double> animation) {
        switch (transitionType) {
          case PageTransitionType.fade:
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          case PageTransitionType.scale:
            return ScaleTransition(
              scale: animation,
              child: child,
            );
          case PageTransitionType.slideRight:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1.0, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          case PageTransitionType.slideLeft:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          case PageTransitionType.slideUp:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          case PageTransitionType.slideDown:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, -1.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
        }
      },
      child: child,
    );
  }
}

enum PageTransitionType {
  fade,
  scale,
  slideRight,
  slideLeft,
  slideUp,
  slideDown,
}