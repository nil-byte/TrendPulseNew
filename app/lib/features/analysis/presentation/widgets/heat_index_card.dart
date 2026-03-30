import 'package:flutter/material.dart';

import 'package:trendpulse/core/animations/number_ticker.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class HeatIndexCard extends StatelessWidget {
  final double heatIndex;

  const HeatIndexCard({super.key, required this.heatIndex});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tpColors = theme.trendPulseColors;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.heatIndex.toUpperCase(),
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
              targetValue: heatIndex,
              style: theme.textTheme.displayLarge?.copyWith(
                fontFamily: theme.textTheme.displayLarge?.fontFamily,
                fontWeight: FontWeight.w900,
                letterSpacing: -2.0,
              ),
            ),
            Icon(
              Icons.local_fire_department_rounded,
              color: tpColors.reddit,
              size: 24,
            ),
          ],
        ),
      ],
    );
  }
}

