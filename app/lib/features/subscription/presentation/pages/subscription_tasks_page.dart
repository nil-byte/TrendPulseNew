import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/network/api_exception.dart';
import 'package:trendpulse/core/animations/staggered_list.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/core/widgets/error_widget.dart';
import 'package:trendpulse/features/subscription/data/subscription_model.dart';
import 'package:trendpulse/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:trendpulse/features/subscription/presentation/widgets/subscription_tasks_page_sections.dart';
import 'package:trendpulse/features/subscription/presentation/widgets/task_timeline_item.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class SubscriptionTasksPage extends ConsumerStatefulWidget {
  final String subId;

  const SubscriptionTasksPage({super.key, required this.subId});

  @override
  ConsumerState<SubscriptionTasksPage> createState() =>
      _SubscriptionTasksPageState();
}

class _SubscriptionTasksPageState extends ConsumerState<SubscriptionTasksPage> {
  static const _noAvailableSourcesCode = 'no_available_sources';
  bool _isRunningNow = false;
  SubscriptionPinnedAlert? _pinnedAlert;
  String? _lastRequestedAlertTaskId;
  late final ProviderSubscription<AsyncValue<Subscription>>
  _subscriptionDetailSubscription;

  @override
  void initState() {
    super.initState();
    final subId = widget.subId;

    _subscriptionDetailSubscription = ref
        .listenManual<AsyncValue<Subscription>>(
          subscriptionDetailProvider(subId),
          (_, next) {
            next.whenData(_handleSubscriptionDetailLoaded);
          },
          fireImmediately: true,
        );
  }

  @override
  void dispose() {
    _subscriptionDetailSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subId = widget.subId;
    final tasksAsync = ref.watch(subscriptionTasksProvider(subId));
    final detailAsync = ref.watch(subscriptionDetailProvider(subId));
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title =
        detailAsync.whenOrNull(data: (s) => s.keyword.toUpperCase()) ??
        l10n.executionHistory.toUpperCase();
    final alertBanner = _pinnedAlert;
    final alertBannerRoute = alertBanner == null
        ? null
        : '/subscription/$subId/tasks/detail/${alertBanner.taskId}';

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
              onPressed: _isRunningNow ? null : _runNow,
              icon: Icon(
                Icons.play_arrow_rounded,
                size: 20,
                color: colorScheme.onSurface,
              ),
              label: Text(l10n.runNow.toUpperCase()),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (alertBanner != null)
            SubscriptionAlertBanner(
              alert: alertBanner,
              onTap: alertBannerRoute == null
                  ? null
                  : () => context.push(alertBannerRoute),
            ),
          Expanded(
            child: tasksAsync.when(
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
                onRetry: () => unawaited(_refreshPageData(subId)),
              ),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return SubscriptionTasksEmptyView(l10n: l10n);
                }

                return RefreshIndicator(
                  color: theme.colorScheme.onSurface,
                  backgroundColor: theme.colorScheme.surface,
                  onRefresh: () => _refreshPageData(subId),
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
          ),
        ],
      ),
    );
  }

  void _handleSubscriptionDetailLoaded(
    Subscription subscription,
  ) {
    final latestAlertTaskId = subscription.latestUnreadAlertTaskId;
    final latestAlertScore = subscription.latestUnreadAlertScore;

    if (subscription.hasUnreadAlertSummary &&
        latestAlertTaskId != null &&
        latestAlertScore != null &&
        _pinnedAlert?.taskId != latestAlertTaskId) {
      setState(() {
        _pinnedAlert = SubscriptionPinnedAlert(
          taskId: latestAlertTaskId,
          score: latestAlertScore,
        );
      });
    }

    if (!subscription.hasUnreadAlertSummary || latestAlertTaskId == null) {
      return;
    }

    if (_lastRequestedAlertTaskId == latestAlertTaskId) {
      return;
    }

    _lastRequestedAlertTaskId = latestAlertTaskId;
    unawaited(_markAlertsRead(latestAlertTaskId));
  }

  Future<void> _runNow() async {
    if (_isRunningNow) {
      return;
    }

    setState(() {
      _isRunningNow = true;
    });

    final context = this.context;
    final l10n = AppLocalizations.of(context)!;

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final task = await repo.runSubscriptionNow(widget.subId);
      ref.invalidate(subscriptionTasksProvider(widget.subId));
      ref.invalidate(subscriptionDetailProvider(widget.subId));
      ref.invalidate(subscriptionListProvider);
      if (context.mounted) {
        context.push('/subscription/${widget.subId}/tasks/detail/${task.id}');
      }
    } catch (e) {
      if (context.mounted) {
        final message = switch (e) {
          ApiException(
            statusCode: 422,
            errorCode: _noAvailableSourcesCode,
          ) =>
            l10n.analysisNoAvailableSourcesMessage,
          _ => l10n.subscriptionRunNowError,
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunningNow = false;
        });
      }
    }
  }

  Future<void> _markAlertsRead(String alertTaskId) async {
    final subId = widget.subId;
    final repo = ref.read(subscriptionRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);

    try {
      await repo.markAlertsRead(subId);
      container.invalidate(subscriptionListProvider);
      unawaited(container.read(subscriptionListProvider.future));
      container.invalidate(subscriptionDetailProvider(subId));
    } catch (_) {
      if (_lastRequestedAlertTaskId == alertTaskId) {
        _lastRequestedAlertTaskId = null;
      }
    }
  }

  Future<void> _refreshPageData(String subId) async {
    ref.invalidate(subscriptionTasksProvider(subId));
    ref.invalidate(subscriptionDetailProvider(subId));
    await Future.wait([
      ref.read(subscriptionTasksProvider(subId).future),
      ref.read(subscriptionDetailProvider(subId).future),
    ]);
  }
}
