import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/l10n/source_platform_labels.dart';
import 'package:trendpulse/core/animations/staggered_list.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/features/detail/presentation/providers/detail_provider.dart';
import 'package:trendpulse/features/detail/presentation/widgets/post_card.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class RawDataTab extends ConsumerWidget {
  final String taskId;

  const RawDataTab({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(taskPostsProvider(taskId));
    final currentFilter = ref.watch(detailSourceFilterProvider(taskId));
    final theme = Theme.of(context);
    final tpColors = theme.trendPulseColors;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _FilterChip(
                label: l10n.filterAll,
                selected: currentFilter == null,
                onSelected: () => ref
                    .read(detailSourceFilterProvider(taskId).notifier)
                    .state = null,
              ),
              const SizedBox(width: AppSpacing.sm),
              _FilterChip(
                label: sourcePlatformLabel('reddit', l10n),
                selected: currentFilter == 'reddit',
                color: tpColors.reddit,
                onSelected: () => ref
                    .read(detailSourceFilterProvider(taskId).notifier)
                    .state = 'reddit',
              ),
              const SizedBox(width: AppSpacing.sm),
              _FilterChip(
                label: sourcePlatformLabel('youtube', l10n),
                selected: currentFilter == 'youtube',
                color: tpColors.youtube,
                onSelected: () => ref
                    .read(detailSourceFilterProvider(taskId).notifier)
                    .state = 'youtube',
              ),
              const SizedBox(width: AppSpacing.sm),
              _FilterChip(
                label: sourcePlatformLabel('x', l10n),
                selected: currentFilter == 'x',
                color: tpColors.xPlatform,
                onSelected: () => ref
                    .read(detailSourceFilterProvider(taskId).notifier)
                    .state = 'x',
              ),
            ],
          ),
        ),
        Expanded(
          child: postsAsync.when(
            loading: () => const ShimmerLoading(
              itemCount: 5,
              itemHeight: 100,
            ),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: tpColors.negative,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.errorGeneric,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.tonal(
                    onPressed: () =>
                        ref.invalidate(taskPostsProvider(taskId)),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
            data: (posts) {
              if (posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inbox_rounded,
                        size: 56,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.rawData,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                itemCount: posts.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, index) => StaggeredListItem(
                  index: index,
                  child: PostCard(post: posts[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.colorScheme.primary;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: chipColor.withValues(alpha: 0.15),
      checkmarkColor: chipColor,
      labelStyle: TextStyle(
        color: selected ? chipColor : theme.colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      side: BorderSide(
        color: selected ? chipColor : theme.colorScheme.outlineVariant,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
      ),
    );
  }
}
