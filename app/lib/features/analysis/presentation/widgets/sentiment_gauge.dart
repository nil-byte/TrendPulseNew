import 'package:flutter/material.dart';

import 'package:trendpulse/core/animations/number_ticker.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class SentimentGauge extends StatelessWidget {
  final double score;

  const SentimentGauge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sentimentScore.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            NumberTicker(
              targetValue: score,
              style: theme.textTheme.displayLarge?.copyWith(
                fontFamily: theme.textTheme.displayLarge?.fontFamily,
                fontWeight: FontWeight.w900,
                letterSpacing: -2.0,
              ),
            ),
            Text(
              '/100',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(
                  alpha: AppOpacity.mutedSoft,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
