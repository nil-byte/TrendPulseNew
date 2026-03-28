import 'dart:math' as math;

import 'package:flutter/material.dart';

class StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration staggerDelay;
  final int maxDelaySteps;

  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.maxDelaySteps = 6,
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(curve);

    final effectiveIndex = math.min(widget.index, widget.maxDelaySteps);
    Future.delayed(widget.staggerDelay * effectiveIndex, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
