import 'package:flutter/material.dart';

import 'package:trendpulse/core/animations/press_feedback.dart';
import 'package:trendpulse/core/l10n/source_platform_labels.dart';
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
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return PressFeedback(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colors.onSurface, width: 2.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.keyword.toUpperCase(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontFamily: theme.textTheme.displayLarge?.fontFamily,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: item.isActive
                                ? colors.onSurface
                                : colors.onSurface.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: colors.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _intervalLabel(item.interval, l10n).toUpperCase(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: item.isActive ? l10n.active : l10n.paused,
                    child: Switch(
                      value: item.isActive,
                      onChanged: onToggleActive,
                      activeThumbColor: colors.surface,
                      activeTrackColor: colors.onSurface,
                      inactiveThumbColor: colors.onSurface,
                      inactiveTrackColor: colors.surface,
                      trackOutlineColor: WidgetStateProperty.all(
                        colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: item.sources.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.onSurface),
                          ),
                          child: Text(
                            sourcePlatformLabel(s, l10n).toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                              letterSpacing: 0.8,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: onEdit,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: theme.trendPulseColors.negative,
                        ),
                        onPressed: onDelete,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _intervalLabel(String interval, AppLocalizations l10n) {
    switch (interval) {
      case 'hourly':
        return l10n.intervalHourly;
      case '6hours':
        return l10n.intervalSixHours;
      case 'weekly':
        return l10n.intervalWeekly;
      case 'daily':
      default:
        return l10n.intervalDaily;
    }
  }
}
