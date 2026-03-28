import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:trendpulse/core/animations/number_ticker.dart';
import 'package:trendpulse/core/theme/app_colors.dart';

class SentimentGauge extends StatelessWidget {
  final double score;

  const SentimentGauge({super.key, required this.score});

  Color _gaugeColor(TrendPulseColors colors) {
    if (score > 60) return colors.positive;
    if (score < 40) return colors.negative;
    return colors.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.trendPulseColors;
    final color = _gaugeColor(colors);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: _GaugeRingPainter(
                  progress: score / 100,
                  color: color,
                  trackColor:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
                child: Center(
                  child: NumberTicker(
                    targetValue: score,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sentiment Score',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugeRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _GaugeRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const strokeWidth = 6.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugeRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
