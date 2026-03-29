import 'package:flutter/material.dart';

import 'package:trendpulse/core/animations/press_feedback.dart';
import 'package:trendpulse/core/l10n/source_platform_labels.dart';
import 'package:trendpulse/core/theme/app_borders.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_typography.dart';
import 'package:trendpulse/features/history/data/history_item.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class HistoryCard extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback onTap;
  final int index;

  const HistoryCard({
    super.key,
    required this.item,
    required this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tpColors = theme.trendPulseColors;
    final l10n = AppLocalizations.of(context)!;

    return PressFeedback(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline, width: AppBorders.thin),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SourceIcons(sources: item.sources, colors: tpColors),
                  const Spacer(),
                  _StatusChip(
                    status: item.status,
                    theme: theme,
                    tpColors: tpColors,
                    l10n: l10n,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Hero(
                tag: 'task-keyword-${item.id}',
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(
                    item.keyword.toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: theme.textTheme.displayLarge?.fontFamily,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: AppOpacity.body),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _formatRelativeTime(context, item.createdAt).toUpperCase(),
                    style: AppTypography.caption(theme.textTheme).copyWith(
                      color: colorScheme.onSurface.withValues(alpha: AppOpacity.body),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  if (item.isCompleted && item.sentimentScore != null)
                    _SentimentIndicator(
                      score: item.sentimentScore!,
                      tpColors: tpColors,
                      theme: theme,
                      l10n: l10n,
                    ),
                  if (item.isRunning)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSurface,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(BuildContext context, String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) {
        return AppLocalizations.of(context)!.relativeMinutesAgo(diff.inMinutes);
      }
      if (diff.inHours < 24) {
        return AppLocalizations.of(context)!.relativeHoursAgo(diff.inHours);
      }
      if (diff.inDays < 7) {
        return AppLocalizations.of(context)!.relativeDaysAgo(diff.inDays);
      }
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _SourceIcons extends StatelessWidget {
  final List<String> sources;
  final TrendPulseColors colors;

  const _SourceIcons({required this.sources, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < sources.length && i < 3; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          _SourceDot(source: sources[i], colors: colors),
        ],
        if (sources.length > 3) ...[
          const SizedBox(width: AppSpacing.xs),
          _OverflowBadge(count: sources.length - 3),
        ],
      ],
    );
  }
}

class _SourceDot extends StatelessWidget {
  final String source;
  final TrendPulseColors colors;

  const _SourceDot({required this.source, required this.colors});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (icon, color) = switch (source.toLowerCase()) {
      'reddit' => (Icons.forum_rounded, colors.reddit),
      'youtube' => (Icons.play_circle_rounded, colors.youtube),
      'x' || 'twitter' => (Icons.tag_rounded, colors.xPlatform),
      _ => (Icons.public_rounded, colors.neutral),
    };

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border.all(color: color),
      ),
      child: Tooltip(
        message: sourcePlatformLabel(source, l10n),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

class _OverflowBadge extends StatelessWidget {
  final int count;

  const _OverflowBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: theme.colorScheme.outline,
          width: AppBorders.thin,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        '+$count',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final ThemeData theme;
  final TrendPulseColors tpColors;
  final AppLocalizations l10n;

  const _StatusChip({
    required this.status,
    required this.theme,
    required this.tpColors,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'completed' => (l10n.statusCompleted, tpColors.positive),
      'running' => (l10n.statusAnalyzing, theme.colorScheme.primary),
      'collecting' => (l10n.statusCollecting, theme.colorScheme.primary),
      'failed' => (l10n.statusFailed, tpColors.negative),
      _ => (l10n.statusPending, tpColors.neutral),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _SentimentIndicator extends StatelessWidget {
  final double score;
  final TrendPulseColors tpColors;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _SentimentIndicator({
    required this.score,
    required this.tpColors,
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final (color, toneLabel) = score > 0.6
        ? (tpColors.positive, l10n.positive)
        : score < 0.4
        ? (tpColors.negative, l10n.negative)
        : (tpColors.neutral, l10n.neutral);

    return Semantics(
      label:
          '${l10n.sentimentScore}: ${(score * 100).toStringAsFixed(0)}, $toneLabel',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: theme.colorScheme.onSurface, width: 1),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            (score * 100).toStringAsFixed(0),
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              fontFamily: theme.textTheme.displayLarge?.fontFamily,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            toneLabel.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(
                alpha: AppOpacity.emphasis,
              ),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
