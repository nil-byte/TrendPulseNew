import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_motion.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';

class PressFeedback extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const PressFeedback({super.key, required this.child, this.onTap});

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) {
      return widget.child;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.gentle,
        child: AnimatedOpacity(
          opacity: _pressed ? AppOpacity.pressedContent : AppOpacity.full,
          duration: AppMotion.fast,
          child: widget.child,
        ),
      ),
    );
  }
}
