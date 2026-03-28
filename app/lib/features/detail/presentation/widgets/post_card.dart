import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:trendpulse/core/l10n/source_platform_labels.dart';
import 'package:trendpulse/core/animations/press_feedback.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/features/feed/data/feed_model.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class PostCard extends StatelessWidget {
  final SourcePost post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tpColors = theme.trendPulseColors;
    final l10n = AppLocalizations.of(context)!;

    return PressFeedback(
      onTap: post.url != null ? () => _openUrl(post.url!) : null,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _sourceIcon(post.source),
                    size: 18,
                    color: _sourceColor(post.source, tpColors),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    sourcePlatformLabel(post.source, l10n),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _sourceColor(post.source, tpColors),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (post.author != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        post.author!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadiusSm,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          size: 14,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${post.engagement}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                post.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (post.publishedAt != null)
                    Text(
                      _formatDate(post.publishedAt!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  if (post.url != null)
                    Text(
                      l10n.openOriginal,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return isoDate;
    }
  }
}
