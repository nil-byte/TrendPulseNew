import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/features/feed/data/feed_model.dart';

class SourcePostCard extends StatelessWidget {
  final SourcePost post;

  const SourcePostCard({super.key, required this.post});

  static Color _platformColor(String source, TrendPulseColors colors) =>
      switch (source) {
        'reddit' => colors.reddit,
        'youtube' => colors.youtube,
        'x' => colors.xPlatform,
        _ => colors.neutral,
      };

  static IconData _platformIcon(String source) => switch (source) {
        'reddit' => Icons.forum_rounded,
        'youtube' => Icons.play_circle_fill_rounded,
        'x' => Icons.tag_rounded,
        _ => Icons.public_rounded,
      };

  static String _platformLabel(String source) => switch (source) {
        'reddit' => 'Reddit',
        'youtube' => 'YouTube',
        'x' => 'X',
        _ => source,
      };

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _openUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _platformColor(post.source, theme.trendPulseColors);

    return Card(
      child: InkWell(
        onTap: post.url != null ? () => _openUrl(post.url) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_platformIcon(post.source), color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _platformLabel(post.source),
                    style: theme.textTheme.labelMedium?.copyWith(color: color),
                  ),
                  if (post.author != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '·',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.author!,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (post.url != null)
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post.content,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatEngagement(post.engagement),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(post.publishedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
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

  String _formatEngagement(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
