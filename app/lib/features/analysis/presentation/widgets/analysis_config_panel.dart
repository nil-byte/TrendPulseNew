import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_borders.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_motion.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_typography.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/analysis_source_chip.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class AnalysisConfigPanel extends StatelessWidget {
  final bool expanded;
  final String contentLanguage;
  final Set<String> sources;
  final List<AnalysisSourceAvailability> sourceAvailability;
  final double maxItems;
  final ValueChanged<String> onContentLanguageChanged;
  final ValueChanged<Set<String>> onSourcesChanged;
  final ValueChanged<double> onMaxItemsChanged;

  const AnalysisConfigPanel({
    super.key,
    required this.expanded,
    required this.contentLanguage,
    required this.sources,
    required this.sourceAvailability,
    required this.maxItems,
    required this.onContentLanguageChanged,
    required this.onSourcesChanged,
    required this.onMaxItemsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.slow,
      curve: AppMotion.emphasized,
      alignment: Alignment.topCenter,
      child: expanded ? _buildPanel(context) : const SizedBox.shrink(),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colors = theme.colorScheme;
    final availabilityBySource = {
      for (final item in sourceAvailability) item.source: item,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colors.onSurface, width: AppBorders.thick),
          right: BorderSide(color: colors.onSurface, width: AppBorders.thick),
          bottom: BorderSide(color: colors.onSurface, width: AppBorders.thick),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.analysisParametersTitle.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const EditorialDivider(topSpace: AppSpacing.xs, bottomSpace: AppSpacing.md),
          Text(
            l10n.contentLanguageLabel.toUpperCase(),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
              ButtonSegment(value: 'zh', label: Text(l10n.languageChinese)),
            ],
            selected: {contentLanguage},
            onSelectionChanged: (v) => onContentLanguageChanged(v.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.dataSources,
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Builder(
            builder: (context) {
              final tpColors = Theme.of(context).trendPulseColors;
              return Row(
                children: [
                  Expanded(
                    child: AnalysisSourceChip(
                      label: l10n.platformReddit,
                      color: tpColors.reddit,
                      selected: sources.contains('reddit'),
                      status: availabilityBySource['reddit']?.status ?? 'available',
                      reason: availabilityBySource['reddit']?.reason,
                      enabled: availabilityBySource['reddit']?.isAvailable ?? true,
                      onSelected: (v) => _toggleSource('reddit', v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AnalysisSourceChip(
                      label: l10n.platformYouTube,
                      color: tpColors.youtube,
                      selected: sources.contains('youtube'),
                      status: availabilityBySource['youtube']?.status ?? 'available',
                      reason: availabilityBySource['youtube']?.reason,
                      enabled: availabilityBySource['youtube']?.isAvailable ?? true,
                      onSelected: (v) => _toggleSource('youtube', v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AnalysisSourceChip(
                      label: l10n.platformX,
                      color: tpColors.xPlatform,
                      selected: sources.contains('x'),
                      status: availabilityBySource['x']?.status ?? 'available',
                      reason: availabilityBySource['x']?.reason,
                      enabled: availabilityBySource['x']?.isAvailable ?? true,
                      onSelected: (v) => _toggleSource('x', v),
                    ),
                  ),
                ],
              );
            },
          ),
          if (sourceAvailability.any((item) => item.reason?.trim().isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.analysisSourceStatusHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.72),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ...sourceAvailability
                      .where((item) => item.reason?.trim().isNotEmpty ?? false)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text(
                            '${_sourceLabel(item.source, l10n)} · ${_statusLabel(item, l10n)} · ${item.reason}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: item.isAvailable
                                  ? colors.onSurface.withValues(alpha: 0.72)
                                  : colors.error,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text(
                l10n.analysisMaxItemsPerSource.toUpperCase(),
                style: theme.textTheme.labelSmall,
              ),
              const Spacer(),
              Text(
                maxItems.round().toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: AppTypography.editorialSansFamily,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.analysisPerSourceLimitHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.72),
              fontStyle: FontStyle.italic,
            ),
          ),
          Slider(
            value: maxItems,
            min: 10,
            max: 100,
            divisions: 9,
            onChanged: onMaxItemsChanged,
          ),
        ],
      ),
    );
  }

  void _toggleSource(String source, bool selected) {
    final next = Set<String>.from(sources);
    if (selected) {
      next.add(source);
    } else if (next.length > 1) {
      next.remove(source);
    }
    onSourcesChanged(next);
  }

  String _sourceLabel(String source, AppLocalizations l10n) {
    switch (source) {
      case 'reddit':
        return l10n.platformReddit;
      case 'youtube':
        return l10n.platformYouTube;
      case 'x':
        return l10n.platformX;
      default:
        return source;
    }
  }

  String _statusLabel(
    AnalysisSourceAvailability availability,
    AppLocalizations l10n,
  ) {
    switch (availability.status) {
      case 'degraded':
        return l10n.analysisSourceDegradedLabel;
      case 'unconfigured':
        return l10n.analysisSourceUnavailableLabel;
      default:
        return availability.status;
    }
  }
}
