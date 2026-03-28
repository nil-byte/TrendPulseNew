import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/widgets/empty_widget.dart';
import 'package:trendpulse/core/widgets/error_widget.dart';
import 'package:trendpulse/core/widgets/loading_widget.dart';
import 'package:trendpulse/features/history/presentation/providers/history_provider.dart';
import 'package:trendpulse/features/history/presentation/widgets/history_list_item.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: historyAsync.when(
        loading: () => const LoadingWidget(
          itemCount: 5,
          itemHeight: 72,
        ),
        error: (error, _) => AppErrorWidget(
          message: error.toString(),
          onRetry: () => ref.invalidate(historyListProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyWidget(
              message: 'No analysis history yet.\nStart a new analysis to see it here.',
              icon: Icons.history_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(historyListProvider);
              await ref.read(historyListProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (context, _) => Divider(
                indent: 68,
                endIndent: 24,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return HistoryListItem(
                  item: item,
                  onTap: () => context.push('/analysis?taskId=${item.id}'),
                  onDelete: () => _deleteItem(context, ref, item.id),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _deleteItem(BuildContext context, WidgetRef ref, String taskId) async {
    try {
      final repository = ref.read(historyRepositoryProvider);
      await repository.deleteTask(taskId);
      ref.invalidate(historyListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.invalidate(historyListProvider);
      }
    }
  }
}
