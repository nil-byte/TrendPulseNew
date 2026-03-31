import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/animations/staggered_list.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/core/widgets/empty_widget.dart';
import 'package:trendpulse/core/widgets/error_widget.dart';
import 'package:trendpulse/app_providers.dart';
import 'package:trendpulse/features/history/data/history_item.dart';
import 'package:trendpulse/features/history/presentation/providers/history_provider.dart';
import 'package:trendpulse/features/history/presentation/widgets/history_card.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HistoryItem> _filterItems(List<HistoryItem> items) {
    if (_searchQuery.isEmpty) return items;
    final query = _searchQuery.toLowerCase();
    return items
        .where((item) => item.keyword.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyListProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.archiveTitle.toUpperCase(),
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
      ),
      body: historyAsync.when(
        loading: () => const ShimmerLoading(
          cardSkeleton: true,
          itemCount: 5,
          itemHeight: 110,
          borderRadius: 0,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.pageHorizontal,
            vertical: AppSpacing.sm,
          ),
        ),
        error: (error, _) => AppErrorWidget(
          message: l10n.errorGeneric,
          retryLabel: l10n.retry,
          onRetry: _retryHistory,
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyHistoryView(l10n: l10n);
          }

          final filteredItems = _filterItems(items);

          return Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colorScheme.onSurface, width: 2.0)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: theme.textTheme.displayLarge?.fontFamily,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.searchArchivesHint,
                    hintStyle: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: theme.textTheme.displayLarge?.fontFamily,
                      color: colorScheme.onSurface.withValues(
                        alpha: AppOpacity.divider,
                      ),
                      fontStyle: FontStyle.italic,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: colorScheme.onSurface,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: colorScheme.onSurface),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  ),
                ),
              ),
              Expanded(
                child: filteredItems.isEmpty
                    ? _SearchEmptyView(
                        title: l10n.archiveSearchEmptyTitle,
                        message: l10n.archiveSearchEmptyMessage,
                      )
                    : RefreshIndicator(
                        color: theme.colorScheme.onSurface,
                        backgroundColor: theme.colorScheme.surface,
                        onRefresh: _refreshHistory,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.lg,
                          ),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) => const EditorialDivider(topSpace: AppSpacing.md, bottomSpace: AppSpacing.md),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return StaggeredListItem(
                              index: index,
                              child: _DismissibleCard(
                                item: item,
                                onTap: () => context.push(
                                  '/history/detail/${item.id}',
                                ),
                                onDelete: () =>
                                    _confirmDelete(context, item.id),
                                index: index,
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _retryHistory() {
    _refreshHistory();
  }

  Future<void> _refreshHistory() {
    return ref.read(historyListProvider.notifier).refresh();
  }

  Future<void> _confirmDelete(BuildContext context, String taskId) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.historyDeleteDialogTitle.toUpperCase(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: theme.textTheme.displayLarge?.fontFamily,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          l10n.historyDeleteDialogMessage,
          style: theme.textTheme.bodyMedium,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: theme.colorScheme.onSurface, width: 2.0),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel.toUpperCase()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text(l10n.delete.toUpperCase()),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      _executeDelete(taskId);
    }
  }

  Future<void> _executeDelete(String taskId) async {
    try {
      final repository = ref.read(historyRepositoryProvider);
      await repository.deleteTask(taskId);
      if (!mounted) {
        return;
      }
      ref.read(taskMutationSignalProvider.notifier).state++;
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.historyDeleteError),
        ),
      );
      await _refreshHistory();
    }
  }
}

class _DismissibleCard extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final int index;

  const _DismissibleCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: colorScheme.primary,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: colorScheme.onPrimary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${l10n.confirm.toUpperCase()} ${l10n.delete.toUpperCase()}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
      child: HistoryCard(item: item, onTap: onTap, index: index),
    );
  }
}

class _EmptyHistoryView extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyHistoryView({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return EmptyWidget(
      title: l10n.archiveEmptyTitle,
      message: l10n.startFirstAnalysis,
      action: OutlinedButton(
        onPressed: () => context.go('/analysis'),
        child: Text(l10n.newAnalysis.toUpperCase()),
      ),
    );
  }
}

class _SearchEmptyView extends StatelessWidget {
  final String title;
  final String message;

  const _SearchEmptyView({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return EmptyWidget(title: title, message: message);
  }
}
