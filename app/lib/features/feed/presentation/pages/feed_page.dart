import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/widgets/empty_widget.dart';
import 'package:trendpulse/core/widgets/error_widget.dart';
import 'package:trendpulse/core/widgets/loading_widget.dart';
import 'package:trendpulse/features/feed/presentation/providers/feed_provider.dart';
import 'package:trendpulse/features/feed/presentation/widgets/source_post_card.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  static const _tabs = [
    _TabItem(label: 'All', filter: null, icon: Icons.grid_view_rounded),
    _TabItem(
      label: 'Reddit',
      filter: 'reddit',
      icon: Icons.forum_rounded,
      color: AppColors.reddit,
    ),
    _TabItem(
      label: 'YouTube',
      filter: 'youtube',
      icon: Icons.play_circle_fill_rounded,
      color: AppColors.youtube,
    ),
    _TabItem(
      label: 'X',
      filter: 'x',
      icon: Icons.tag_rounded,
      color: AppColors.x,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskId = ref.watch(selectedTaskIdProvider);
    final currentFilter = ref.watch(sourceFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: taskId == null
          ? const EmptyWidget(
              message: 'Run an analysis first to see source data',
              icon: Icons.rss_feed_rounded,
            )
          : Column(
              children: [
                _FilterBar(
                  tabs: _tabs,
                  currentFilter: currentFilter,
                  onFilterChanged: (filter) {
                    ref.read(sourceFilterProvider.notifier).state = filter;
                  },
                ),
                const Expanded(child: _PostList()),
              ],
            ),
    );
  }
}

class _TabItem {
  final String label;
  final String? filter;
  final IconData icon;
  final Color? color;

  const _TabItem({
    required this.label,
    required this.filter,
    required this.icon,
    this.color,
  });
}

class _FilterBar extends StatelessWidget {
  final List<_TabItem> tabs;
  final String? currentFilter;
  final ValueChanged<String?> onFilterChanged;

  const _FilterBar({
    required this.tabs,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = tab.filter == currentFilter;
          final chipColor =
              tab.color ?? theme.colorScheme.primary;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(tab.label),
              avatar: Icon(
                tab.icon,
                size: 18,
                color: isSelected
                    ? chipColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
              selectedColor: chipColor.withValues(alpha: 0.12),
              checkmarkColor: chipColor,
              side: BorderSide(
                color: isSelected
                    ? chipColor.withValues(alpha: 0.4)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? chipColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
              onSelected: (_) => onFilterChanged(tab.filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PostList extends ConsumerWidget {
  const _PostList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(feedPostsProvider);

    return postsAsync.when(
      loading: () => const LoadingWidget(),
      error: (error, _) => AppErrorWidget(
        message: error.toString(),
        onRetry: () => ref.invalidate(feedPostsProvider),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return const EmptyWidget(
            message: 'No posts found for this source',
            icon: Icons.article_outlined,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) => SourcePostCard(post: posts[index]),
        );
      },
    );
  }
}
