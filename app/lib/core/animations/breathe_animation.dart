import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_motion.dart';

class BreatheAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double maxScale;

  const BreatheAnimation({
    super.key,
    required this.child,
    this.duration = AppMotion.breathe,
    this.maxScale = 1.03,
  });

  @override
  State<BreatheAnimation> createState() => _BreatheAnimationState();
}

class _BreatheAnimationState extends State<BreatheAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 1.0,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.gentle));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
