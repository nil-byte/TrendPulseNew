import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_borders.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/widgets/empty_widget.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class SubscriptionTasksEmptyView extends StatelessWidget {
  final AppLocalizations l10n;

  const SubscriptionTasksEmptyView({
    super.key,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyWidget(
      title: l10n.noExecutions,
      message: l10n.noRecordsFoundMessage,
    );
  }
}

class SubscriptionPinnedAlert {
  final String taskId;
  final double score;

  const SubscriptionPinnedAlert({
    required this.taskId,
    required this.score,
  });
}

class SubscriptionAlertBanner extends StatelessWidget {
  final SubscriptionPinnedAlert alert;
  final VoidCallback? onTap;

  const SubscriptionAlertBanner({
    super.key,
    required this.alert,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('subscription-alert-banner'),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              border: Border.all(
                color: colorScheme.error,
                width: AppBorders.medium,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.subscriptionNegativeAlertTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.subscriptionNegativeAlertMessage(
                          _formatAlertScore(alert.score),
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: colorScheme.onErrorContainer,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatAlertScore(double score) {
    final truncatedScore = (score * 100).truncateToDouble() / 100;
    return truncatedScore
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
