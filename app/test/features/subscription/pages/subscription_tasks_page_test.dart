import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/subscription/data/subscription_model.dart';
import 'package:trendpulse/features/subscription/data/subscription_repository.dart';
import 'package:trendpulse/features/subscription/presentation/pages/subscription_tasks_page.dart';
import 'package:trendpulse/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class _FakeSubscriptionRepository extends SubscriptionRepository {
  _FakeSubscriptionRepository({
    required this.tasks,
    this.detailError,
    this.tasksError,
    this.runNowError,
  });

  static const _defaultSubscription = Subscription(
    id: 'sub-1',
    keyword: 'AI Watch',
    language: 'en',
    interval: 'daily',
    maxItems: 50,
    sources: ['reddit', 'youtube', 'x'],
    isActive: true,
    notify: true,
    createdAt: '2026-03-28T12:00:00Z',
    updatedAt: '2026-03-28T12:00:00Z',
  );

  final List<SubscriptionTask> tasks;
  final Object? detailError;
  final Object? tasksError;
  final Object? runNowError;

  @override
  Future<Subscription> getSubscription(String id) async {
    if (detailError != null) {
      throw detailError!;
    }
    return _defaultSubscription;
  }

  @override
  Future<List<SubscriptionTask>> getSubscriptionTasks(String id) async {
    if (tasksError != null) {
      throw tasksError!;
    }
    return tasks;
  }

  @override
  Future<void> runSubscriptionNow(String id) async {
    if (runNowError != null) {
      throw runNowError!;
    }
  }
}

Widget _wrap(
  SubscriptionRepository repository, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [subscriptionRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.light,
      home: const SubscriptionTasksPage(subId: 'sub-1'),
    ),
  );
}

void main() {
  testWidgets('subscription tasks page localizes fallback title and empty state in Chinese', (
    tester,
  ) async {
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
  });

  testWidgets('subscription tasks page localizes post count metrics in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _FakeSubscriptionRepository(
          tasks: const [
            SubscriptionTask(
              id: 'task-1',
              keyword: 'AI Watch',
              status: 'completed',
              createdAt: '2026-03-28T12:00:00Z',
              sentimentScore: 0.72,
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
  });

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
}
