import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:trendpulse/core/animations/press_feedback.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
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
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        color: colorScheme.surfaceContainer,
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
              const SizedBox(height: AppSpacing.sm),
              Hero(
                tag: 'task-keyword-${item.id}',
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(
                    item.keyword,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _formatRelativeTime(item.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  if (item.isCompleted && item.sentimentScore != null)
                    _SentimentIndicator(
                      score: item.sentimentScore!,
                      tpColors: tpColors,
                      theme: theme,
                    ),
                  if (item.isRunning)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
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

  String _formatRelativeTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return timeago.format(date);
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
      ),
      child: Icon(icon, size: 14, color: color),
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
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SentimentIndicator extends StatelessWidget {
  final double score;
  final TrendPulseColors tpColors;
  final ThemeData theme;

  const _SentimentIndicator({
    required this.score,
    required this.tpColors,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = score > 0.6
        ? tpColors.positive
        : score < 0.4
            ? tpColors.negative
            : tpColors.neutral;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          (score * 100).toStringAsFixed(0),
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
