import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:trendpulse/core/l10n/source_platform_labels.dart';
import 'package:trendpulse/core/animations/press_feedback.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/features/subscription/data/subscription_model.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class SubscriptionCard extends StatelessWidget {
  final Subscription item;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SubscriptionCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
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
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
          onLongPress: () => _showMenu(context, l10n, colorScheme),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme, colorScheme, l10n),
                const SizedBox(height: AppSpacing.sm),
                _buildMetaRow(theme, colorScheme, tpColors, l10n),
                const SizedBox(height: AppSpacing.sm),
                _buildTimestamps(theme, colorScheme, l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            item.keyword,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          height: 32,
          child: FittedBox(
            child: Switch.adaptive(
              value: item.isActive,
              onChanged: onToggleActive,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(
    ThemeData theme,
    ColorScheme colorScheme,
    TrendPulseColors tpColors,
    AppLocalizations l10n,
  ) {
    final intervalLabel = _intervalLabel(item.interval, l10n);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
          ),
          child: Text(
            intervalLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SourceChips(
            sources: item.sources,
            tpColors: tpColors,
            l10n: l10n,
          ),
        ),
        if (item.notify)
          Icon(
            Icons.notifications_active_rounded,
            size: 16,
            color: colorScheme.primary.withValues(alpha: 0.7),
          ),
      ],
    );
  }

  Widget _buildTimestamps(
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Row(
      children: [
        if (item.lastRunAt != null) ...[
          Icon(
            Icons.schedule_rounded,
            size: 13,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 3),
          Text(
            '${l10n.lastRun}: ${_relativeTime(item.lastRunAt!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        if (item.lastRunAt != null && item.nextRunAt != null)
          const SizedBox(width: AppSpacing.md),
        if (item.nextRunAt != null) ...[
          Icon(
            Icons.update_rounded,
            size: 13,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 3),
          Text(
            '${l10n.nextRun}: ${_relativeTime(item.nextRunAt!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }

  void _showMenu(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.borderRadiusLg),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: Text(l10n.subscriptionKeyword),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onEdit();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: colorScheme.error,
                ),
                title: Text(
                  l10n.delete,
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _intervalLabel(String interval, AppLocalizations l10n) {
    return switch (interval) {
      'hourly' => l10n.intervalHourly,
      '6hours' => l10n.intervalSixHours,
      'daily' => l10n.intervalDaily,
      'weekly' => l10n.intervalWeekly,
      _ => interval,
    };
  }

  static String _relativeTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return timeago.format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

class _SourceChips extends StatelessWidget {
  final List<String> sources;
  final TrendPulseColors tpColors;
  final AppLocalizations l10n;

  const _SourceChips({
    required this.sources,
    required this.tpColors,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.xs,
      children: sources.map((s) {
        final lower = s.toLowerCase();
        final (icon, color, label) = switch (lower) {
          'reddit' => (
              Icons.forum_rounded,
              tpColors.reddit,
              sourcePlatformLabel('reddit', l10n),
            ),
          'youtube' => (
              Icons.play_circle_rounded,
              tpColors.youtube,
              sourcePlatformLabel('youtube', l10n),
            ),
          'x' || 'twitter' => (
              Icons.tag_rounded,
              tpColors.xPlatform,
              sourcePlatformLabel('x', l10n),
            ),
          _ => (Icons.public_rounded, tpColors.neutral, s),
        };

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
