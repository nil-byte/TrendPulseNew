import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class AnalysisMastheadSection extends StatelessWidget {
  const AnalysisMastheadSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Text(
          l10n.analysisMastheadTop.toUpperCase(),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            letterSpacing: 4.0,
            fontWeight: FontWeight.w700,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            l10n.appTitle.toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -2.0,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.analysisMastheadSubtitle.toUpperCase(),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 2.0,
          ),
        ),
        EditorialDivider.doubleLine(
          topSpace: AppSpacing.xl,
          bottomSpace: AppSpacing.xl,
        ),
        Text(
          l10n.analysisIntro,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurface.withValues(
              alpha: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

class AnalysisTrendingTopicsSection extends StatelessWidget {
  final ValueChanged<String> onTopicTap;

  const AnalysisTrendingTopicsSection({
    super.key,
    required this.onTopicTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final topics = [
      l10n.analysisStarterTopicAi,
      l10n.analysisStarterTopicCrypto,
      l10n.analysisStarterTopicEv,
      l10n.analysisStarterTopicMarkets,
      l10n.analysisStarterTopicLayoffs,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.analysisStarterTopicsTitle.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const EditorialDivider(topSpace: AppSpacing.xs, bottomSpace: AppSpacing.md),
        Text(
          l10n.analysisStarterTopicsDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(
              alpha: AppOpacity.secondaryStrong,
            ),
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...List.generate(topics.length, (index) {
          final topic = topics[index];
          return InkWell(
            onTap: () => onTopicTap(topic),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      topic,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: theme.textTheme.displayLarge?.fontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          );
        }),
        const EditorialDivider(topSpace: AppSpacing.sm, bottomSpace: 0),
      ],
    );
  }
}

class AnalysisPoweredByFooter extends StatelessWidget {
  const AnalysisPoweredByFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final style = theme.textTheme.labelSmall?.copyWith(
      letterSpacing: 1.0,
      fontWeight: FontWeight.w700,
    );

    return Column(
      children: [
        Text(l10n.analysisDataSourcesTitle.toUpperCase(), style: style),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.analysisDataSourcesList.toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }
}
