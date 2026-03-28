import 'package:flutter/material.dart';

import 'package:trendpulse/core/animations/breathe_animation.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class EmptyWidget extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData icon;
  final String? title;

  const EmptyWidget({
    super.key,
    required this.message,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BreatheAnimation(
              child: Icon(
                icon,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              (title ?? l10n.noContentTitle).toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: theme.textTheme.displayLarge?.fontFamily,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const EditorialDivider(topSpace: AppSpacing.sm, bottomSpace: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
