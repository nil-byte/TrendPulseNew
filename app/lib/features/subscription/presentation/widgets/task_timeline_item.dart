import 'package:flutter/material.dart';

import 'package:trendpulse/core/animations/press_feedback.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/features/subscription/data/subscription_model.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class TaskTimelineItem extends StatelessWidget {
  final SubscriptionTask task;
  final bool isLast;
  final VoidCallback onTap;

  const TaskTimelineItem({
    super.key,
    required this.task,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tpColors = theme.trendPulseColors;
    final l10n = AppLocalizations.of(context)!;

    final dotColor = _statusColor(task.status, tpColors, colorScheme);

    return PressFeedback(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusMd,
                  ),
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
                          Expanded(
                            child: Text(
                              _formatDateTime(task.createdAt),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          _StatusChip(
                            status: task.status,
                            theme: theme,
                            tpColors: tpColors,
                            l10n: l10n,
                          ),
                        ],
                      ),
                      if (task.isCompleted) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            if (task.sentimentScore != null) ...[
                              _MetricLabel(
                                icon: Icons.sentiment_satisfied_rounded,
                                value: (task.sentimentScore! * 100)
                                    .toStringAsFixed(1),
                                color: _sentimentColor(
                                  task.sentimentScore!,
                                  tpColors,
                                ),
                                theme: theme,
                              ),
                              const SizedBox(width: AppSpacing.md),
                            ],
                            if (task.postCount != null)
                              _MetricLabel(
                                icon: Icons.article_outlined,
                                value: '${task.postCount}',
                                color: colorScheme.onSurfaceVariant,
                                theme: theme,
                                suffix: ' posts',
                              ),
                          ],
                        ),
                      ],
                      if (task.isRunning) ...[
                        const SizedBox(height: AppSpacing.sm),
                        LinearProgressIndicator(
                          borderRadius: BorderRadius.circular(2),
                          minHeight: 3,
                          color: colorScheme.primary,
                          backgroundColor: colorScheme.primaryContainer
                              .withValues(alpha: 0.3),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(
    String status,
    TrendPulseColors tpColors,
    ColorScheme colorScheme,
  ) {
    return switch (status) {
      'completed' => tpColors.positive,
      'failed' => tpColors.negative,
      'running' || 'collecting' => colorScheme.primary,
      _ => tpColors.neutral,
    };
  }

  static Color _sentimentColor(double score, TrendPulseColors tpColors) {
    if (score > 0.6) return tpColors.positive;
    if (score < 0.4) return tpColors.negative;
    return tpColors.neutral;
  }

  static String _formatDateTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}-$month-$day $hour:$minute';
    } catch (_) {
      return dateStr;
    }
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

class _MetricLabel extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final ThemeData theme;
  final String? suffix;

  const _MetricLabel({
    required this.icon,
    required this.value,
    required this.color,
    required this.theme,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          '$value${suffix ?? ''}',
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
