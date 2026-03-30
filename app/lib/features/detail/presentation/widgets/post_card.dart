import 'package:flutter/material.dart';

import 'package:trendpulse/core/animations/press_feedback.dart';
import 'package:trendpulse/core/l10n/source_platform_labels.dart';
import 'package:trendpulse/core/theme/app_borders.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_typography.dart';
import 'package:trendpulse/features/feed/data/feed_model.dart';
import 'package:trendpulse/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class PostCard extends StatelessWidget {
  final SourcePost post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tpColors = theme.trendPulseColors;
    final l10n = AppLocalizations.of(context)!;
    final sourceUri = _parseLaunchableUrl(post.url);
    final hasSourceUrl = sourceUri != null;

    return Semantics(
      link: hasSourceUrl,
      child: PressFeedback(
        onTap: hasSourceUrl ? () => _openUrl(context, l10n, sourceUri) : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline,
              width: AppBorders.thin,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _sourceColor(
                          post.source,
                          tpColors,
                        ).withValues(alpha: AppOpacity.soft),
                        border: Border.all(
                          color: _sourceColor(post.source, tpColors).withValues(
                            alpha: AppOpacity.strokeStrong,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: Icon(
                        _sourceIcon(post.source),
                        size: 14,
                        color: _sourceColor(post.source, tpColors),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      sourcePlatformLabel(post.source, l10n).toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _sourceColor(post.source, tpColors),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (post.author != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          post.author!.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: AppOpacity.body,
                            ),
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusPill,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            size: 12,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${post.engagement}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppTypography.editorialSansFamily,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  post.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.6,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    if (post.publishedAt != null)
                      Text(
                        _formatDate(context, post.publishedAt!).toUpperCase(),
                        style: AppTypography.caption(theme.textTheme).copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: AppOpacity.mutedSoft,
                          ),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      hasSourceUrl
                          ? l10n.openOriginal.toUpperCase()
                          : l10n.sourceUnavailable.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: hasSourceUrl
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: AppOpacity.hint,
                              ),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.45,
                      ),
                    ),
                    if (hasSourceUrl) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(
    BuildContext context,
    AppLocalizations l10n,
    Uri uri,
  ) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        _showOpenLinkFailed(context, l10n);
      }
    } catch (_) {
      if (context.mounted) {
        _showOpenLinkFailed(context, l10n);
      }
    }
  }

  Uri? _parseLaunchableUrl(String? rawUrl) {
    final normalized = rawUrl?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme) {
      return null;
    }
    return uri.scheme == 'http' || uri.scheme == 'https' ? uri : null;
  }

  void _showOpenLinkFailed(BuildContext context, AppLocalizations l10n) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(l10n.openLinkFailed)));
  }

  IconData _sourceIcon(String source) {
    switch (source.toLowerCase()) {
      case 'reddit':
        return Icons.forum_rounded;
      case 'youtube':
        return Icons.play_circle_rounded;
      case 'x':
        return Icons.tag_rounded;
      default:
        return Icons.language_rounded;
    }
  }

  Color _sourceColor(String source, TrendPulseColors colors) {
    switch (source.toLowerCase()) {
      case 'reddit':
        return colors.reddit;
      case 'youtube':
        return colors.youtube;
      case 'x':
        return colors.xPlatform;
      default:
        return colors.neutral;
    }
  }

  String _formatDate(BuildContext context, String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) {
        return AppLocalizations.of(context)!.relativeMinutesAgo(diff.inMinutes);
      }
      if (diff.inHours < 24) {
        return AppLocalizations.of(context)!.relativeHoursAgo(diff.inHours);
      }
      if (diff.inDays < 7) {
        return AppLocalizations.of(context)!.relativeDaysAgo(diff.inDays);
      }
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
