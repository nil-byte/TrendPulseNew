import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/animations/staggered_list.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/widgets/error_widget.dart';
import 'package:trendpulse/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:trendpulse/features/subscription/presentation/widgets/task_timeline_item.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class SubscriptionTasksPage extends ConsumerWidget {
  final String subId;

  const SubscriptionTasksPage({super.key, required this.subId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(subscriptionTasksProvider(subId));
    final detailAsync = ref.watch(subscriptionDetailProvider(subId));
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = detailAsync.whenOrNull(data: (s) => s.keyword) ??
        l10n.executionHistory;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton.icon(
            onPressed: () => _runNow(ref, context, l10n),
            icon: Icon(
              Icons.play_arrow_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
            label: Text(l10n.runNow),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const ShimmerLoading(
          itemCount: 5,
          itemHeight: 80,
          borderRadius: AppSpacing.borderRadiusMd,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          retryLabel: l10n.retry,
          onRetry: () => ref.invalidate(subscriptionTasksProvider(subId)),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return _EmptyTasksView(l10n: l10n);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(subscriptionTasksProvider(subId));
              await ref.read(subscriptionTasksProvider(subId).future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return StaggeredListItem(
                  index: index,
                  child: TaskTimelineItem(
                    task: task,
                    isLast: index == tasks.length - 1,
                    onTap: () => context.push(
                      '/subscription/$subId/tasks/detail/${task.id}',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _runNow(
    WidgetRef ref,
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.createSubscription({'subscription_id': subId});
      ref.invalidate(subscriptionTasksProvider(subId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.statusCollecting),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
            ),
          ),
        );
      }
    }
  }
}

class _EmptyTasksView extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyTasksView({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timeline_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.noExecutions,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
