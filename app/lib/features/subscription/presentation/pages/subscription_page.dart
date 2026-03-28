import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/animations/breathe_animation.dart';
import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/animations/staggered_list.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/core/widgets/error_widget.dart';
import 'package:trendpulse/features/subscription/data/subscription_model.dart';
import 'package:trendpulse/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:trendpulse/features/subscription/presentation/widgets/subscription_card.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  bool _isFabExtended = true;

  @override
  Widget build(BuildContext context) {
    final subsAsync = ref.watch(subscriptionListProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.catalogTitle.toUpperCase(),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/subscription/new'),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: theme.colorScheme.onSurface,
        foregroundColor: theme.colorScheme.surface,
        label: AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
          sizeCurve: Curves.easeOutCubic,
          crossFadeState: _isFabExtended
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Text(
            l10n.newEntry.toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0),
          ),
          secondChild: const SizedBox.shrink(),
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse) {
            if (_isFabExtended) setState(() => _isFabExtended = false);
          } else if (notification.direction == ScrollDirection.forward) {
            if (!_isFabExtended) setState(() => _isFabExtended = true);
          }
          return false;
        },
        child: subsAsync.when(
          loading: () => const ShimmerLoading(
            itemCount: 4,
            itemHeight: 110,
            borderRadius: 0,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          error: (error, _) => AppErrorWidget(
            message: l10n.errorGeneric,
            retryLabel: l10n.retry,
            onRetry: () => ref.invalidate(subscriptionListProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _EmptyView(l10n: l10n);
            }

            return RefreshIndicator(
              color: theme.colorScheme.onSurface,
              backgroundColor: theme.colorScheme.surface,
              onRefresh: () async {
                ref.invalidate(subscriptionListProvider);
                await ref.read(subscriptionListProvider.future);
              },
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) => const EditorialDivider(topSpace: AppSpacing.md, bottomSpace: AppSpacing.md),
                itemBuilder: (context, index) {
                  final sub = items[index];
                  return StaggeredListItem(
                    index: index,
                    child: SubscriptionCard(
                      item: sub,
                      onTap: () =>
                          context.push('/subscription/${sub.id}/tasks'),
                      onToggleActive: (value) =>
                          _toggleActive(context, sub, value),
                      onEdit: () =>
                          context.push('/subscription/${sub.id}/edit'),
                      onDelete: () => _confirmDelete(context, sub, l10n),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggleActive(
    BuildContext context,
    Subscription sub,
    bool value,
  ) async {
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      await repo.toggleActive(sub.id, isActive: value);
      ref.invalidate(subscriptionListProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.subscriptionToggleError),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.onSurface,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Subscription sub,
    AppLocalizations l10n,
  ) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.subscriptionDeleteDialogTitle.toUpperCase(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: theme.textTheme.displayLarge?.fontFamily,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          l10n.deleteSubscriptionConfirmMessage,
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
      try {
        final repo = ref.read(subscriptionRepositoryProvider);
        await repo.deleteSubscription(sub.id);
        ref.invalidate(subscriptionListProvider);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.subscriptionDeleteError,
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.onSurface,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
          );
        }
      }
    }
  }
}

class _EmptyView extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyView({required this.l10n});

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
            BreatheAnimation(
              child: Icon(
                Icons.article_outlined,
                size: 64,
                color: colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.catalogEmptyTitle.toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: theme.textTheme.displayLarge?.fontFamily,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const EditorialDivider(topSpace: AppSpacing.sm, bottomSpace: AppSpacing.sm),
            Text(
              l10n.addFirstSubscription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: () => context.push('/subscription/new'),
              child: Text(l10n.createEntry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
