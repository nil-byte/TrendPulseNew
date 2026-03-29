import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class EmptyWidget extends StatelessWidget {
  final String message;
  final String? subtitle;
  @Deprecated(
    'Ignored by the editorial layout. Use title, message, subtitle, or action instead.',
  )
  final IconData icon;
  final Widget? action;
  final String? title;

  const EmptyWidget({
    super.key,
    required this.message,
    this.subtitle,
    @Deprecated(
      'Ignored by the editorial layout. Use title, message, subtitle, or action instead.',
    )
    this.icon = Icons.inbox_outlined,
    this.action,
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
            Text(
              '\u2022  \u2022  \u2022',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: AppOpacity.hint),
                letterSpacing: 12.0,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              (title ?? l10n.noContentTitle).toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: theme.textTheme.displayLarge?.fontFamily,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const EditorialDivider(topSpace: AppSpacing.sm, bottomSpace: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: AppOpacity.primary),
                fontStyle: FontStyle.italic,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: AppOpacity.muted),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              '\u2014\u2014\u2014  \u00B7  \u2014\u2014\u2014',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                letterSpacing: 4.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
