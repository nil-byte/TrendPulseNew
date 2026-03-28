import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/features/history/data/history_item.dart';

class HistoryListItem extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const HistoryListItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: colorScheme.error.withValues(alpha: 0.08),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colorScheme.error,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              _SourceIndicators(sources: item.sources),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.keyword,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _formatDate(item.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusBadge(status: item.status),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _TrailingIndicator(item: item),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

class _SourceIndicators extends StatelessWidget {
  final List<String> sources;

  const _SourceIndicators({required this.sources});

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return const SizedBox(width: 28);
    }

    return SizedBox(
      width: 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: sources.take(3).map((source) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _colorForSource(source),
                shape: BoxShape.circle,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _colorForSource(String source) {
    return switch (source.toLowerCase()) {
      'reddit' => AppColors.reddit,
      'youtube' => AppColors.youtube,
      'x' || 'twitter' => AppColors.x,
      _ => AppColors.neutral,
    };
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      'completed' => ('Done', AppColors.positive),
      'running' => ('Running', AppColors.seed),
      'failed' => ('Failed', AppColors.negative),
      _ => ('Pending', AppColors.neutral),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _TrailingIndicator extends StatelessWidget {
  final HistoryItem item;

  const _TrailingIndicator({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (item.isCompleted && item.sentimentScore != null) {
      final score = item.sentimentScore!;
      final color = score > 0.6
          ? AppColors.positive
          : score < 0.4
              ? AppColors.negative
              : AppColors.neutral;

      return Text(
        score.toStringAsFixed(2),
        style: theme.textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    if (item.isRunning) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.primary,
        ),
      );
    }

    return Icon(
      Icons.chevron_right_rounded,
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      size: 20,
    );
  }
}
