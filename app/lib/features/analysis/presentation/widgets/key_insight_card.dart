import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class KeyInsightCard extends StatelessWidget {
  final KeyInsight insight;

  const KeyInsightCard({super.key, required this.insight});

  Color _sentimentColor(TrendPulseColors colors) {
    switch (insight.sentiment) {
      case 'positive':
        return colors.positive;
      case 'negative':
        return colors.negative;
      default:
        return colors.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentimentColor = _sentimentColor(theme.trendPulseColors);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.onSurface, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: sentimentColor,
                    border: Border.all(color: colorScheme.onSurface, width: 1),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  insight.sentiment.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: sentimentColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.onSurface, width: 1),
                  ),
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.sourceCountLabel(insight.sourceCount).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              insight.text,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: theme.textTheme.displayLarge?.fontFamily,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
