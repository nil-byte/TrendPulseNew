import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/animations/staggered_list.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/core/widgets/empty_widget.dart';
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

    final title =
        detailAsync.whenOrNull(data: (s) => s.keyword.toUpperCase()) ??
        l10n.executionHistory.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: theme.textTheme.displayLarge?.fontFamily,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: EditorialDivider.thick(topSpace: 0, bottomSpace: 0),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: OutlinedButton.icon(
              onPressed: () => _runNow(ref, context, l10n),
              icon: Icon(
                Icons.play_arrow_rounded,
                size: 20,
                color: colorScheme.onSurface,
              ),
              label: Text(l10n.runNow.toUpperCase()),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
            ),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const ShimmerLoading(
          cardSkeleton: true,
          itemCount: 5,
          itemHeight: 80,
          borderRadius: 0,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.sm,
          ),
        ),
        error: (error, _) => AppErrorWidget(
          message: l10n.errorGeneric,
          retryLabel: l10n.retry,
          onRetry: () => ref.invalidate(subscriptionTasksProvider(subId)),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return _EmptyTasksView(l10n: l10n);
          }

          return RefreshIndicator(
            color: theme.colorScheme.onSurface,
            backgroundColor: theme.colorScheme.surface,
            onRefresh: () async {
              ref.invalidate(subscriptionTasksProvider(subId));
              await ref.read(subscriptionTasksProvider(subId).future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
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
      await repo.runSubscriptionNow(subId);
      ref.invalidate(subscriptionTasksProvider(subId));
      ref.invalidate(subscriptionDetailProvider(subId));
      ref.invalidate(subscriptionListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.statusCollecting.toUpperCase())),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.subscriptionRunNowError)),
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
    return EmptyWidget(
      title: l10n.noExecutions,
      message: l10n.noRecordsFoundMessage,
    );
  }
}
