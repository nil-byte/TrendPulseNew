import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/network/api_exception.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';
import 'package:trendpulse/features/subscription/data/subscription_model.dart';
import 'package:trendpulse/features/subscription/data/subscription_repository.dart';
import 'package:trendpulse/features/subscription/presentation/pages/subscription_tasks_page.dart';
import 'package:trendpulse/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class _FakeSubscriptionRepository extends SubscriptionRepository {
  _FakeSubscriptionRepository({
    required this.tasks,
    Subscription? detail,
    this.detailError,
    this.tasksError,
    this.markAlertsReadFailuresRemaining = 0,
    this.markAlertsReadCompleter,
    this.runNowError,
    this.runNowCompleter,
    this.runNowTask = const SubscriptionTask(
      id: 'task-run-now',
      keyword: 'AI Watch',
      status: 'pending',
      createdAt: '2026-03-28T12:10:00Z',
    ),
  }) : _currentDetail = detail ?? _defaultSubscription;

  static const _defaultSubscription = Subscription(
    id: 'sub-1',
    keyword: 'AI Watch',
    contentLanguage: 'en',
    interval: 'daily',
    maxItems: 50,
    sources: ['reddit', 'youtube', 'x'],
    isActive: true,
    notify: true,
    createdAt: '2026-03-28T12:00:00Z',
    updatedAt: '2026-03-28T12:00:00Z',
  );

  final List<SubscriptionTask> tasks;
  Subscription _currentDetail;
  final Object? detailError;
  final Object? tasksError;
  int markAlertsReadFailuresRemaining;
  final Completer<void>? markAlertsReadCompleter;
  final Object? runNowError;
  final Completer<SubscriptionTask>? runNowCompleter;
  final SubscriptionTask runNowTask;
  int detailCalls = 0;
  int markAlertsReadCalls = 0;
  int runNowCalls = 0;

  @override
  Future<Subscription> getSubscription(String id) async {
    detailCalls++;
    if (detailError != null) {
      throw detailError!;
    }
    return _currentDetail;
  }

  @override
  Future<List<SubscriptionTask>> getSubscriptionTasks(String id) async {
    if (tasksError != null) {
      throw tasksError!;
    }
    return tasks;
  }

  void replaceDetail(Subscription detail) {
    _currentDetail = detail;
  }

  @override
  Future<List<Subscription>> getSubscriptions() async => [_currentDetail];

  @override
  Future<void> markAlertsRead(String id) async {
    markAlertsReadCalls++;
    if (markAlertsReadFailuresRemaining > 0) {
      markAlertsReadFailuresRemaining--;
      throw Exception('mark alerts read failed');
    }
    final completer = markAlertsReadCompleter;
    if (completer != null) {
      await completer.future;
    }
    _currentDetail = Subscription(
      id: _currentDetail.id,
      keyword: _currentDetail.keyword,
      contentLanguage: _currentDetail.contentLanguage,
      interval: _currentDetail.interval,
      maxItems: _currentDetail.maxItems,
      sources: _currentDetail.sources,
      isActive: _currentDetail.isActive,
      notify: _currentDetail.notify,
      createdAt: _currentDetail.createdAt,
      updatedAt: _currentDetail.updatedAt,
      lastRunAt: _currentDetail.lastRunAt,
      nextRunAt: _currentDetail.nextRunAt,
      unreadAlertCount: 0,
      latestUnreadAlertTaskId: null,
      latestUnreadAlertScore: null,
    );
  }

  @override
  Future<SubscriptionTask> runSubscriptionNow(String id) async {
    runNowCalls++;
    if (runNowError != null) {
      throw runNowError!;
    }
    final completer = runNowCompleter;
    if (completer != null) {
      return completer.future;
    }
    return runNowTask;
  }
}

class _PendingTasksRepository extends SubscriptionRepository {
  final Completer<List<SubscriptionTask>> _never =
      Completer<List<SubscriptionTask>>();

  @override
  Future<Subscription> getSubscription(String id) async {
    return _FakeSubscriptionRepository._defaultSubscription;
  }

  @override
  Future<List<SubscriptionTask>> getSubscriptionTasks(String id) =>
      _never.future;
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository({bool inAppNotify = true})
    : _inAppNotify = inAppNotify;

  bool _inAppNotify;

  @override
  Future<bool> getInAppNotify() async => _inAppNotify;

  @override
  Future<void> setInAppNotify(bool value) async {
    _inAppNotify = value;
  }
}

Widget _wrap(
  SubscriptionRepository repository, {
  Locale locale = const Locale('en'),
  SettingsRepository? settingsRepository,
  bool initialInAppNotify = true,
}) {
  return ProviderScope(
    overrides: [
      subscriptionRepositoryProvider.overrideWithValue(repository),
      settingsRepositoryProvider.overrideWithValue(
        settingsRepository ?? _FakeSettingsRepository(),
      ),
      initialInAppNotifyProvider.overrideWithValue(initialInAppNotify),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.light,
      home: const SubscriptionTasksPage(subId: 'sub-1'),
    ),
  );
}

Widget _wrapWithContainer(
  ProviderContainer container, {
  Locale locale = const Locale('en'),
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.light,
      home: const SubscriptionTasksPage(subId: 'sub-1'),
    ),
  );
}

Widget _wrapWithRouter(
  SubscriptionRepository repository, {
  Locale locale = const Locale('en'),
  SettingsRepository? settingsRepository,
  bool initialInAppNotify = true,
}) {
  final router = GoRouter(
    initialLocation: '/subscription/sub-1/tasks',
    routes: [
      GoRoute(
        path: '/subscription/:subId/tasks',
        builder: (context, state) =>
            SubscriptionTasksPage(subId: state.pathParameters['subId']!),
        routes: [
          GoRoute(
            path: 'detail/:taskId',
            builder: (context, state) => Scaffold(
              body: Text('DETAIL:${state.pathParameters['taskId']}'),
            ),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      subscriptionRepositoryProvider.overrideWithValue(repository),
      settingsRepositoryProvider.overrideWithValue(
        settingsRepository ?? _FakeSettingsRepository(),
      ),
      initialInAppNotifyProvider.overrideWithValue(initialInAppNotify),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('subscription tasks loading uses editorial card skeletons', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_PendingTasksRepository()));
    await tester.pump();

    final shimmer = tester.widget<ShimmerLoading>(find.byType(ShimmerLoading));

    expect(shimmer.cardSkeleton, isTrue);
    expect(
      shimmer.padding,
      const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.sm,
      ),
    );
  });

  testWidgets(
    'subscription tasks page localizes fallback title and empty state in Chinese',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FakeSubscriptionRepository(
            tasks: const [],
            detailError: Exception('detail unavailable'),
          ),
          locale: const Locale('zh'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('执行历史'), findsOneWidget);
      expect(find.text('暂无执行记录'), findsOneWidget);
      expect(find.text('HISTORY'), findsNothing);
      expect(find.text('NO EXECUTIONS'), findsNothing);
    },
  );

  testWidgets(
    'subscription tasks page localizes post count metrics in Chinese',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FakeSubscriptionRepository(
            tasks: const [
              SubscriptionTask(
                id: 'task-1',
                keyword: 'AI Watch',
                status: 'completed',
                createdAt: '2026-03-28T12:00:00Z',
                sentimentScore: 72,
                postCount: 12,
              ),
            ],
          ),
          locale: const Locale('zh'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('12 条内容'), findsOneWidget);
      expect(find.text('12 POSTS'), findsNothing);
    },
  );

  testWidgets(
    'subscription tasks page shows completed status plus degraded quality badge',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FakeSubscriptionRepository(
            tasks: const [
              SubscriptionTask(
                id: 'task-1',
                keyword: 'AI Watch',
                status: 'completed',
                quality: 'degraded',
                createdAt: '2026-03-28T12:00:00Z',
                sentimentScore: 72,
                postCount: 12,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('SOURCE ISSUES'), findsOneWidget);
      expect(find.text('72'), findsOneWidget);
      expect(find.text('7200'), findsNothing);
      expect(find.text('12 POSTS'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'subscription tasks page does not show degraded badge for failed tasks',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FakeSubscriptionRepository(
            tasks: const [
              SubscriptionTask(
                id: 'task-failed',
                keyword: 'AI Watch',
                status: 'failed',
                quality: 'degraded',
                createdAt: '2026-03-28T12:00:00Z',
                errorMessage: 'Collection failed.',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FAILED'), findsOneWidget);
      expect(find.text('SOURCE ISSUES'), findsNothing);
    },
  );

  testWidgets(
    'subscription tasks page handles preloaded detail on first frame',
    (tester) async {
      final repository = _FakeSubscriptionRepository(
        detail: const Subscription(
          id: 'sub-1',
          keyword: 'AI Watch',
          contentLanguage: 'en',
          interval: 'daily',
          maxItems: 50,
          sources: ['reddit', 'youtube', 'x'],
          isActive: true,
          notify: true,
          createdAt: '2026-03-28T12:00:00Z',
          updatedAt: '2026-03-28T12:00:00Z',
          unreadAlertCount: 1,
          latestUnreadAlertTaskId: 'task-alert',
          latestUnreadAlertScore: 18,
        ),
        tasks: const [
          SubscriptionTask(
            id: 'task-alert',
            keyword: 'AI Watch',
            status: 'completed',
            createdAt: '2026-03-28T12:00:00Z',
            sentimentScore: 18,
            postCount: 12,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(subscriptionDetailProvider('sub-1').future);

      await tester.pumpWidget(_wrapWithContainer(container));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('subscription-alert-banner')),
        findsOneWidget,
      );
      expect(repository.markAlertsReadCalls, 1);
    },
  );

  testWidgets(
    'subscription tasks page alert banner navigates to the alerted task detail page',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter(
          _FakeSubscriptionRepository(
            detail: const Subscription(
              id: 'sub-1',
              keyword: 'AI Watch',
              contentLanguage: 'en',
              interval: 'daily',
              maxItems: 50,
              sources: ['reddit', 'youtube', 'x'],
              isActive: true,
              notify: true,
              createdAt: '2026-03-28T12:00:00Z',
              updatedAt: '2026-03-28T12:00:00Z',
              unreadAlertCount: 1,
              latestUnreadAlertTaskId: 'task-alert',
              latestUnreadAlertScore: 18,
            ),
            tasks: const [
              SubscriptionTask(
                id: 'task-alert',
                keyword: 'AI Watch',
                status: 'completed',
                createdAt: '2026-03-28T12:00:00Z',
                sentimentScore: 18,
                postCount: 12,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('subscription-alert-banner')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('subscription-alert-banner')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('DETAIL:task-alert'), findsOneWidget);
    },
  );

  testWidgets(
    'subscription tasks page still shows alert banner and marks alerts read when in-app notifications are disabled',
    (tester) async {
      final repository = _FakeSubscriptionRepository(
        detail: const Subscription(
          id: 'sub-1',
          keyword: 'AI Watch',
          contentLanguage: 'en',
          interval: 'daily',
          maxItems: 50,
          sources: ['reddit', 'youtube', 'x'],
          isActive: true,
          notify: true,
          createdAt: '2026-03-28T12:00:00Z',
          updatedAt: '2026-03-28T12:00:00Z',
          unreadAlertCount: 1,
          latestUnreadAlertTaskId: 'task-alert',
          latestUnreadAlertScore: 18,
        ),
        tasks: const [
          SubscriptionTask(
            id: 'task-alert',
            keyword: 'AI Watch',
            status: 'completed',
            createdAt: '2026-03-28T12:00:00Z',
            sentimentScore: 18,
            postCount: 12,
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          repository,
          settingsRepository: _FakeSettingsRepository(inAppNotify: false),
          initialInAppNotify: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('subscription-alert-banner')),
        findsOneWidget,
      );
      expect(repository.markAlertsReadCalls, 1);
    },
  );

  testWidgets(
    'subscription tasks page keeps alert banner visible when in-app notifications are toggled off',
    (tester) async {
      final repository = _FakeSubscriptionRepository(
        detail: const Subscription(
          id: 'sub-1',
          keyword: 'AI Watch',
          contentLanguage: 'en',
          interval: 'daily',
          maxItems: 50,
          sources: ['reddit', 'youtube', 'x'],
          isActive: true,
          notify: true,
          createdAt: '2026-03-28T12:00:00Z',
          updatedAt: '2026-03-28T12:00:00Z',
          unreadAlertCount: 1,
          latestUnreadAlertTaskId: 'task-alert',
          latestUnreadAlertScore: 18,
        ),
        tasks: const [
          SubscriptionTask(
            id: 'task-alert',
            keyword: 'AI Watch',
            status: 'completed',
            createdAt: '2026-03-28T12:00:00Z',
            sentimentScore: 18,
            postCount: 12,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(repository),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(inAppNotify: true),
          ),
          initialInAppNotifyProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrapWithContainer(container));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('subscription-alert-banner')),
        findsOneWidget,
      );
      expect(repository.markAlertsReadCalls, 1);

      await container.read(inAppNotifyProvider.notifier).toggle();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('subscription-alert-banner')),
        findsOneWidget,
      );
      expect(repository.markAlertsReadCalls, 1);
    },
  );

  testWidgets(
    'subscription tasks page shows alert banner and keeps it after mark-read refresh',
    (tester) async {
      final repository = _FakeSubscriptionRepository(
        detail: const Subscription(
          id: 'sub-1',
          keyword: 'AI Watch',
          contentLanguage: 'en',
          interval: 'daily',
          maxItems: 50,
          sources: ['reddit', 'youtube', 'x'],
          isActive: true,
          notify: true,
          createdAt: '2026-03-28T12:00:00Z',
          updatedAt: '2026-03-28T12:00:00Z',
          unreadAlertCount: 2,
          latestUnreadAlertTaskId: 'task-alert',
          latestUnreadAlertScore: 18,
        ),
        tasks: const [
          SubscriptionTask(
            id: 'task-alert',
            keyword: 'AI Watch',
            status: 'completed',
            createdAt: '2026-03-28T12:00:00Z',
            sentimentScore: 18,
            postCount: 12,
          ),
        ],
      );

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('subscription-alert-banner')),
        findsOneWidget,
      );
      expect(repository.markAlertsReadCalls, 1);
      expect(repository.detailCalls, greaterThanOrEqualTo(2));

      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('subscription-alert-banner')),
        findsOneWidget,
      );
      expect(repository.markAlertsReadCalls, 1);
    },
  );

  testWidgets(
    'subscription tasks page updates banner and re-reads alerts when a new unread alert arrives',
    (tester) async {
      final repository = _FakeSubscriptionRepository(
        detail: const Subscription(
          id: 'sub-1',
          keyword: 'AI Watch',
          contentLanguage: 'en',
          interval: 'daily',
          maxItems: 50,
          sources: ['reddit', 'youtube', 'x'],
          isActive: true,
          notify: true,
          createdAt: '2026-03-28T12:00:00Z',
          updatedAt: '2026-03-28T12:00:00Z',
          unreadAlertCount: 1,
          latestUnreadAlertTaskId: 'task-alert-1',
          latestUnreadAlertScore: 18,
        ),
        tasks: const [
          SubscriptionTask(
            id: 'task-alert-1',
            keyword: 'AI Watch',
            status: 'completed',
            createdAt: '2026-03-28T12:00:00Z',
            sentimentScore: 18,
            postCount: 5,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrapWithContainer(container));
      await tester.pumpAndSettle();

      expect(repository.markAlertsReadCalls, 1);
      expect(
        find.text(
          'Latest unread run scored 18. Review the execution history now.',
        ),
        findsOneWidget,
      );

      repository.replaceDetail(
        const Subscription(
          id: 'sub-1',
          keyword: 'AI Watch',
          contentLanguage: 'en',
          interval: 'daily',
          maxItems: 50,
          sources: ['reddit', 'youtube', 'x'],
          isActive: true,
          notify: true,
          createdAt: '2026-03-28T12:00:00Z',
          updatedAt: '2026-03-28T12:00:00Z',
          unreadAlertCount: 1,
          latestUnreadAlertTaskId: 'task-alert-2',
          latestUnreadAlertScore: 12,
        ),
      );
      container.invalidate(subscriptionDetailProvider('sub-1'));
      await tester.pumpAndSettle();

      expect(repository.markAlertsReadCalls, 2);
      expect(
        find.text(
          'Latest unread run scored 12. Review the execution history now.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Latest unread run scored 18. Review the execution history now.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'subscription tasks page retries mark-read after detail refresh following initial failure',
    (tester) async {
      final repository = _FakeSubscriptionRepository(
        detail: const Subscription(
          id: 'sub-1',
          keyword: 'AI Watch',
          contentLanguage: 'en',
          interval: 'daily',
          maxItems: 50,
          sources: ['reddit', 'youtube', 'x'],
          isActive: true,
          notify: true,
          createdAt: '2026-03-28T12:00:00Z',
          updatedAt: '2026-03-28T12:00:00Z',
          unreadAlertCount: 1,
          latestUnreadAlertTaskId: 'task-alert',
          latestUnreadAlertScore: 18,
        ),
        tasks: const [
          SubscriptionTask(
            id: 'task-alert',
            keyword: 'AI Watch',
            status: 'completed',
            createdAt: '2026-03-28T12:00:00Z',
            sentimentScore: 18,
            postCount: 12,
          ),
        ],
        markAlertsReadFailuresRemaining: 1,
      );
      final container = ProviderContainer(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrapWithContainer(container));
      await tester.pumpAndSettle();

      expect(repository.markAlertsReadCalls, 1);
      container.invalidate(subscriptionDetailProvider('sub-1'));
      await tester.pumpAndSettle();

      expect(repository.markAlertsReadCalls, 2);
      expect(
        find.byKey(const ValueKey('subscription-alert-banner')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'subscription tasks page keeps decimal precision for low alert scores',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FakeSubscriptionRepository(
            detail: const Subscription(
              id: 'sub-1',
              keyword: 'AI Watch',
              contentLanguage: 'en',
              interval: 'daily',
              maxItems: 50,
              sources: ['reddit', 'youtube', 'x'],
              isActive: true,
              notify: true,
              createdAt: '2026-03-28T12:00:00Z',
              updatedAt: '2026-03-28T12:00:00Z',
              unreadAlertCount: 1,
              latestUnreadAlertTaskId: 'task-alert',
              latestUnreadAlertScore: 29.5,
            ),
            tasks: const [
              SubscriptionTask(
                id: 'task-alert',
                keyword: 'AI Watch',
                status: 'completed',
                createdAt: '2026-03-28T12:00:00Z',
                sentimentScore: 29.5,
                postCount: 12,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('29.5'), findsOneWidget);
      expect(find.textContaining('scored 30'), findsNothing);
    },
  );

  testWidgets(
    'subscription tasks page does not render 29.99 as 30 in alert banner',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FakeSubscriptionRepository(
            detail: const Subscription(
              id: 'sub-1',
              keyword: 'AI Watch',
              contentLanguage: 'en',
              interval: 'daily',
              maxItems: 50,
              sources: ['reddit', 'youtube', 'x'],
              isActive: true,
              notify: true,
              createdAt: '2026-03-28T12:00:00Z',
              updatedAt: '2026-03-28T12:00:00Z',
              unreadAlertCount: 1,
              latestUnreadAlertTaskId: 'task-alert',
              latestUnreadAlertScore: 29.99,
            ),
            tasks: const [
              SubscriptionTask(
                id: 'task-alert',
                keyword: 'AI Watch',
                status: 'completed',
                createdAt: '2026-03-28T12:00:00Z',
                sentimentScore: 29.99,
                postCount: 5,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('29.99'), findsOneWidget);
      expect(find.textContaining('scored 30'), findsNothing);
    },
  );

  testWidgets(
    'subscription tasks page still refreshes list provider after mark-read succeeds post-dispose',
    (tester) async {
      final markReadCompleter = Completer<void>();
      final repository = _FakeSubscriptionRepository(
        detail: const Subscription(
          id: 'sub-1',
          keyword: 'AI Watch',
          contentLanguage: 'en',
          interval: 'daily',
          maxItems: 50,
          sources: ['reddit', 'youtube', 'x'],
          isActive: true,
          notify: true,
          createdAt: '2026-03-28T12:00:00Z',
          updatedAt: '2026-03-28T12:00:00Z',
          unreadAlertCount: 1,
          latestUnreadAlertTaskId: 'task-alert',
          latestUnreadAlertScore: 18,
        ),
        tasks: const [
          SubscriptionTask(
            id: 'task-alert',
            keyword: 'AI Watch',
            status: 'completed',
            createdAt: '2026-03-28T12:00:00Z',
            sentimentScore: 18,
            postCount: 12,
          ),
        ],
        markAlertsReadCompleter: markReadCompleter,
      );
      final container = ProviderContainer(
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      var latestUnreadCount = -1;
      final listSubscription = container.listen<AsyncValue<List<Subscription>>>(
        subscriptionListProvider,
        (_, next) {
          final subscriptions = next.valueOrNull;
          if (subscriptions != null && subscriptions.isNotEmpty) {
            latestUnreadCount = subscriptions.single.unreadAlertCount;
          }
        },
        fireImmediately: true,
      );
      addTearDown(listSubscription.close);
      await container.read(subscriptionListProvider.future);
      expect(latestUnreadCount, 1);

      await tester.pumpWidget(_wrapWithContainer(container));
      await tester.pump();

      expect(repository.markAlertsReadCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());

      markReadCompleter.complete();
      await tester.pumpAndSettle();

      expect(latestUnreadCount, 0);
    },
  );

  testWidgets(
    'subscription tasks page run now navigates to the created task detail page',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithRouter(
          _FakeSubscriptionRepository(
            tasks: const [],
            runNowTask: const SubscriptionTask(
              id: 'task-99',
              keyword: 'AI Watch',
              status: 'pending',
              createdAt: '2026-03-28T12:10:00Z',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('RUN NOW'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('DETAIL:task-99'), findsOneWidget);
    },
  );

  testWidgets(
    'subscription tasks page disables run now while request is in flight',
    (tester) async {
      final completer = Completer<SubscriptionTask>();
      final repository = _FakeSubscriptionRepository(
        tasks: const [],
        runNowCompleter: completer,
      );

      await tester.pumpWidget(_wrapWithRouter(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('RUN NOW'));
      await tester.pump();

      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNull);
      expect(repository.runNowCalls, 1);

      await tester.tap(find.text('RUN NOW'), warnIfMissed: false);
      await tester.pump();

      expect(repository.runNowCalls, 1);

      completer.complete(
        const SubscriptionTask(
          id: 'task-guarded',
          keyword: 'AI Watch',
          status: 'pending',
          createdAt: '2026-03-28T12:10:00Z',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DETAIL:task-guarded'), findsOneWidget);
    },
  );

  testWidgets('subscription tasks page localizes load failures in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _FakeSubscriptionRepository(
          tasks: const [],
          tasksError: Exception('network timeout'),
        ),
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('系统错误'), findsOneWidget);
    expect(find.text('出了点问题'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('Exception: network timeout'), findsNothing);
  });

  testWidgets('subscription tasks page localizes run now failures in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _FakeSubscriptionRepository(
          tasks: const [],
          runNowError: Exception('network timeout'),
        ),
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('立即运行'));
    await tester.pump();

    expect(find.text('暂时无法启动这次执行。'), findsOneWidget);
    expect(find.text('Exception: network timeout'), findsNothing);
  });

  testWidgets(
    'subscription tasks page shows no-available-sources guidance for run now 422 errors',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FakeSubscriptionRepository(
            tasks: const [],
            runNowError: const ApiException(
              message: '请求参数无效，请检查输入或稍后重试。',
              statusCode: 422,
              errorCode: 'no_available_sources',
              debugMessage: 'No requested sources are currently available.',
            ),
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('RUN NOW'));
      await tester.pump();

      expect(
        find.text(
          'No data sources are currently available. Check source configuration or try again later.',
        ),
        findsOneWidget,
      );
      expect(find.text('Unable to start this run right now.'), findsNothing);
    },
  );
}
