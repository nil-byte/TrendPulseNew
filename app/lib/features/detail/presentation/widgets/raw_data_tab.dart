import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/animations/staggered_list.dart';
import 'package:trendpulse/core/l10n/source_platform_labels.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/features/detail/presentation/providers/detail_provider.dart';
import 'package:trendpulse/features/detail/presentation/widgets/post_card.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class RawDataTab extends ConsumerWidget {
  final String taskId;

  const RawDataTab({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(detailSourceFilterProvider(taskId));
    final postsAsync = ref.watch(taskPostsProvider(taskId));
    final allPostsAsync = currentFilter == null
        ? postsAsync
        : ref.watch(taskAllPostsProvider(taskId));
    final theme = Theme.of(context);
    final tpColors = theme.trendPulseColors;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline,
                width: 1.0,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      label: l10n.allSources.toUpperCase(),
                      selected: currentFilter == null,
                      onSelected: () =>
                          ref
                                  .read(
                                    detailSourceFilterProvider(taskId).notifier,
                                  )
                                  .state =
                              null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterChip(
                      label: sourcePlatformLabel('reddit', l10n).toUpperCase(),
                      selected: currentFilter == 'reddit',
                      color: tpColors.reddit,
                      onSelected: () =>
                          ref
                                  .read(
                                    detailSourceFilterProvider(taskId).notifier,
                                  )
                                  .state =
                              'reddit',
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterChip(
                      label: sourcePlatformLabel('youtube', l10n).toUpperCase(),
                      selected: currentFilter == 'youtube',
                      color: tpColors.youtube,
                      onSelected: () =>
                          ref
                                  .read(
                                    detailSourceFilterProvider(taskId).notifier,
                                  )
                                  .state =
                              'youtube',
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FilterChip(
                      label: sourcePlatformLabel('x', l10n).toUpperCase(),
                      selected: currentFilter == 'x',
                      color: tpColors.xPlatform,
                      onSelected: () =>
                          ref
                                  .read(
                                    detailSourceFilterProvider(taskId).notifier,
                                  )
                                  .state =
                              'x',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Text(
                  l10n.filterScrollHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: postsAsync.when(
            loading: () => const ShimmerLoading(itemCount: 5, itemHeight: 100),
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
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.invalidate(taskPostsProvider(taskId));
                      ref.invalidate(taskAllPostsProvider(taskId));
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry.toUpperCase()),
                  ),
                ],
              ),
            ),
            data: (posts) {
              if (currentFilter != null && posts.isEmpty && allPostsAsync.isLoading) {
                return const ShimmerLoading(itemCount: 2, itemHeight: 100);
              }
              final hasAnyPosts = allPostsAsync.valueOrNull?.isNotEmpty == true;
              if (posts.isEmpty) {
                final filteredEmpty = currentFilter != null && hasAnyPosts;
                return _EmptyPostsState(
                  title: filteredEmpty
                      ? l10n.noFilteredRecordsTitle
                      : l10n.noRecordsFoundTitle,
                  message: filteredEmpty
                      ? l10n.noFilteredRecordsMessage
                      : l10n.noRecordsFoundMessage,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg,
                ),
                itemCount: posts.length,
                separatorBuilder: (_, __) => const EditorialDivider(topSpace: AppSpacing.md, bottomSpace: AppSpacing.md),
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
    final chipColor = color ?? theme.colorScheme.onSurface;
    final selectedFill = color == null
        ? theme.colorScheme.primaryContainer
        : chipColor.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.26 : 0.16,
          );
    final selectedForeground = color == null
        ? theme.colorScheme.onPrimaryContainer
        : chipColor;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: selectedFill,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? selectedForeground : chipColor,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        fontSize: 13,
      ),
      side: BorderSide(
        color: selected
            ? (color == null
                ? theme.colorScheme.primary.withValues(alpha: 0.45)
                : chipColor.withValues(alpha: 0.72))
            : chipColor,
        width: selected ? 1.2 : 1.0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      ),
    );
  }
}

class _EmptyPostsState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyPostsState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 56,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: theme.textTheme.displayLarge?.fontFamily,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const EditorialDivider(
              topSpace: AppSpacing.sm,
              bottomSpace: AppSpacing.sm,
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
