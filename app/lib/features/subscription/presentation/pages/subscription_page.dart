import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/animations/breathe_animation.dart';
import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/animations/staggered_list.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.subscriptionTab)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/subscription/new'),
        icon: const Icon(Icons.add_rounded),
        label: AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
          sizeCurve: Curves.easeOutCubic,
          crossFadeState: _isFabExtended
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Text(l10n.newLabel),
          secondChild: const SizedBox.shrink(),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        ),
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
            borderRadius: AppSpacing.borderRadiusLg,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          error: (error, _) => AppErrorWidget(
            message: error.toString(),
            retryLabel: l10n.retry,
            onRetry: () => ref.invalidate(subscriptionListProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _EmptyView(l10n: l10n);
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(subscriptionListProvider);
                await ref.read(subscriptionListProvider.future);
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final sub = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: StaggeredListItem(
                      index: index,
                      child: SubscriptionCard(
                        item: sub,
                        onTap: () =>
                            context.push('/subscription/${sub.id}/tasks'),
                        onToggleActive: (value) =>
                            _toggleActive(context, sub, value),
                        onEdit: () =>
                            context.push('/subscription/${sub.id}/edit'),
                        onDelete: () =>
                            _confirmDelete(context, sub, l10n),
                      ),
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

  Future<void> _confirmDelete(
    BuildContext context,
    Subscription sub,
    AppLocalizations l10n,
  ) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSubscriptionConfirmTitle),
        content: Text(l10n.deleteSubscriptionConfirmMessage),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repo = ref.read(subscriptionRepositoryProvider);
        await repo.deleteSubscription(sub.id);
        ref.invalidate(subscriptionListProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$e'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppSpacing.borderRadiusSm),
              ),
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
                Icons.subscriptions_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.noSubscriptions,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.addFirstSubscription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(
              onPressed: () => context.push('/subscription/new'),
              child: Text(l10n.addFirstSubscription),
            ),
          ],
        ),
      ),
    );
  }
}
