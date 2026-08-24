import 'package:flutter/material.dart';

class AppDurations {
  AppDurations._();
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const pageTransition = Duration(milliseconds: 300);
}

class AppCurves {
  AppCurves._();
  static const standard = Curves.easeInOut;
  static const enter = Curves.easeOut;
  static const exit = Curves.easeIn;
  static const emphasis = Curves.easeInOutCubic;
}

class AppTransitions {
  AppTransitions._();

  static PageRouteBuilder fadeThrough({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
  }) =>
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: AppCurves.enter,
            reverseCurve: AppCurves.exit,
          );
          return FadeTransition(opacity: fade, child: child);
        },
      );

  static PageRouteBuilder slideFromRight({
    required Widget page,
    Duration duration = const Duration(milliseconds: 300),
  }) =>
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: AppCurves.enter));
          final fade = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.5, curve: AppCurves.enter),
          );
          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(opacity: fade, child: child),
          );
        },
      );

  static Widget slideUp({
    required Animation<double> animation,
    required Widget child,
    double offset = 24,
  }) {
    final curved = CurvedAnimation(parent: animation, curve: AppCurves.enter);
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, offset / 100),
        end: Offset.zero,
      ).animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}

class FadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double yOffset;

  const FadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.yOffset = 20,
  });

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.yOffset / 100),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
        position: _slide,
        child: FadeTransition(opacity: _opacity, child: widget.child),
      );
}
