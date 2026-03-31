import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/data/analysis_repository.dart';
import 'package:trendpulse/features/analysis/presentation/providers/analysis_provider.dart';
import 'package:trendpulse/features/detail/presentation/pages/detail_page.dart';
import 'package:trendpulse/features/feed/data/feed_model.dart';
import 'package:trendpulse/features/feed/data/feed_repository.dart';
import 'package:trendpulse/features/feed/data/feed_repository_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class _FakeAnalysisRepository extends AnalysisRepository {
  _FakeAnalysisRepository({required this.task, required this.report});

  final AnalysisTask task;
  final AnalysisReport report;

  @override
  Future<AnalysisTask> getTaskStatus(String taskId) async => task;

  @override
  Future<AnalysisReport> getReport(String taskId) async => report;
}

class _FakeFeedRepository extends FeedRepository {
  _FakeFeedRepository({required this.posts});

  final List<SourcePost> posts;

  @override
  Future<List<SourcePost>> getPosts(
    String taskId, {
    String? sourceFilter,
  }) async {
    if (sourceFilter == null) {
      return posts;
    }
    return posts.where((post) => post.source == sourceFilter).toList();
  }
}

Widget _wrap({
  required AnalysisRepository analysisRepository,
  required FeedRepository feedRepository,
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      analysisRepositoryProvider.overrideWithValue(analysisRepository),
      feedRepositoryProvider.overrideWithValue(feedRepository),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: const DetailPage(taskId: 'task-1'),
      ),
    ),
  );
}

void main() {
  const task = AnalysisTask(
    id: 'task-1',
    keyword: 'Macro AI Sentiment Outlook',
    contentLanguage: 'en',
    reportLanguage: 'en',
    maxItems: 50,
    status: 'completed',
    sources: ['reddit', 'youtube', 'x'],
    createdAt: '2026-03-28T12:00:00Z',
    updatedAt: '2026-03-28T12:05:00Z',
    sentimentScore: 62,
    postCount: 37,
  );
  const report = AnalysisReport(
    id: 'report-1',
    taskId: 'task-1',
    sentimentScore: 48,
    positiveRatio: 0.42,
    negativeRatio: 0.18,
    neutralRatio: 0.40,
    heatIndex: 78,
    keyInsights: [
      KeyInsight(
        text: 'Discussion is broadening across creator and finance circles.',
        sentiment: 'positive',
        sourceCount: 12,
      ),
    ],
    summary: 'Momentum is steady and mostly constructive.',
    createdAt: '2026-03-28T12:05:00Z',
  );
  const zhTask = AnalysisTask(
    id: 'task-1',
    keyword: '人工智能舆情长期趋势观察',
    contentLanguage: 'zh',
    reportLanguage: 'zh',
    maxItems: 50,
    status: 'completed',
    sources: ['reddit', 'youtube', 'x'],
    createdAt: '2026-03-28T12:00:00Z',
    updatedAt: '2026-03-28T12:05:00Z',
    sentimentScore: 62,
    postCount: 37,
  );
  const partialTask = AnalysisTask(
    id: 'task-1',
    keyword: 'Macro AI Sentiment Outlook',
    contentLanguage: 'en',
    reportLanguage: 'en',
    maxItems: 50,
    status: 'partial',
    sources: ['reddit', 'youtube', 'x'],
    createdAt: '2026-03-28T12:00:00Z',
    updatedAt: '2026-03-28T12:05:00Z',
    errorMessage: 'Completed with source failures: youtube (API down).',
    sentimentScore: 62,
    postCount: 37,
  );
  const partialReport = AnalysisReport(
    id: 'report-2',
    taskId: 'task-1',
    sentimentScore: 62,
    positiveRatio: 0.42,
    negativeRatio: 0.18,
    neutralRatio: 0.40,
    heatIndex: 78,
    keyInsights: [
      KeyInsight(
        text: 'Discussion is broadening across creator and finance circles.',
        sentiment: 'positive',
        sourceCount: 12,
      ),
    ],
    summary: 'Momentum is steady and mostly constructive.',
    createdAt: '2026-03-28T12:05:00Z',
  );

  testWidgets('header title stack stays clear of the back button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        analysisRepository: _FakeAnalysisRepository(task: task, report: report),
        feedRepository: _FakeFeedRepository(posts: const []),
      ),
    );
    await tester.pumpAndSettle();

    final backButtonRect = tester.getRect(find.byIcon(Icons.arrow_back));
    final eyebrowRect = tester.getRect(find.text('REPORT ON'));
    final keywordRect = tester.getRect(find.text('MACRO AI SENTIMENT OUTLOOK'));

    expect(eyebrowRect.left, greaterThan(backButtonRect.right + 8));
    expect(keywordRect.left, greaterThan(backButtonRect.right + 8));
  });

  testWidgets('header title stack stays clear in Chinese locale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        analysisRepository: _FakeAnalysisRepository(
          task: zhTask,
          report: report,
        ),
        feedRepository: _FakeFeedRepository(posts: const []),
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    final backButtonRect = tester.getRect(find.byIcon(Icons.arrow_back));
    final eyebrowRect = tester.getRect(find.text('报告主题'));
    final keywordRect = tester.getRect(find.text('人工智能舆情长期趋势观察'));

    expect(eyebrowRect.left, greaterThan(backButtonRect.right + 8));
    expect(keywordRect.left, greaterThan(backButtonRect.right + 8));
  });

  testWidgets('header still clears the back button under larger text scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        analysisRepository: _FakeAnalysisRepository(task: task, report: report),
        feedRepository: _FakeFeedRepository(posts: const []),
        textScaler: const TextScaler.linear(1.25),
      ),
    );
    await tester.pumpAndSettle();

    final backButtonRect = tester.getRect(find.byIcon(Icons.arrow_back));
    final eyebrowRect = tester.getRect(find.text('REPORT ON'));
    final keywordRect = tester.getRect(find.text('MACRO AI SENTIMENT OUTLOOK'));

    expect(eyebrowRect.left, greaterThan(backButtonRect.right + 8));
    expect(keywordRect.left, greaterThan(backButtonRect.right + 8));
  });

  testWidgets('partial task still loads and renders the report content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        analysisRepository: _FakeAnalysisRepository(
          task: partialTask,
          report: partialReport,
        ),
        feedRepository: _FakeFeedRepository(posts: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PARTIAL'), findsOneWidget);
    expect(find.text('EXECUTIVE SUMMARY'), findsOneWidget);
    expect(find.text('62'), findsOneWidget);
  });

  testWidgets(
    'detail page prefers canonical task post count over insight sum',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          analysisRepository: _FakeAnalysisRepository(
            task: task,
            report: report,
          ),
          feedRepository: _FakeFeedRepository(posts: const []),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('37'), findsOneWidget);
      expect(find.text('12'), findsNothing);
      expect(find.text('62'), findsOneWidget);
      expect(find.text('48'), findsNothing);
    },
  );
}
