import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_colors.dart';

class HeatIndexCard extends StatelessWidget {
  final double heatIndex;

  const HeatIndexCard({super.key, required this.heatIndex});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.trendPulseColors;
    final normalizedHeat = heatIndex.clamp(0.0, 100.0) / 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              heatIndex.round().toString(),
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Heat Index',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: normalizedHeat,
                minHeight: 6,
                backgroundColor:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.lerp(
                    colors.neutral,
                    colors.negative,
                    normalizedHeat,
                  )!,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
