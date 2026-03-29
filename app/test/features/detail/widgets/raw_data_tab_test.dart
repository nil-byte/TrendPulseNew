import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/data/analysis_repository.dart';
import 'package:trendpulse/features/analysis/presentation/providers/analysis_provider.dart';
import 'package:trendpulse/features/detail/presentation/providers/detail_provider.dart';
import 'package:trendpulse/features/detail/presentation/widgets/raw_data_tab.dart';
import 'package:trendpulse/features/feed/data/feed_model.dart';
import 'package:trendpulse/features/feed/data/feed_repository.dart';
import 'package:trendpulse/features/feed/data/feed_repository_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

AnalysisTask _taskWithStatus(String status) {
  return AnalysisTask(
    id: 'task-1',
    keyword: 'Macro AI Sentiment Outlook',
    language: 'en',
    maxItems: 50,
    status: status,
    sources: const ['reddit', 'youtube', 'x'],
    createdAt: '2026-03-28T12:00:00Z',
    updatedAt: '2026-03-28T12:05:00Z',
  );
}

class _FakeAnalysisRepository extends AnalysisRepository {
  _FakeAnalysisRepository({required List<AnalysisTask> tasks}) : _tasks = tasks;

  final List<AnalysisTask> _tasks;
  int statusCalls = 0;

  @override
  Future<AnalysisTask> getTaskStatus(String taskId) async {
    final index = statusCalls < _tasks.length ? statusCalls : _tasks.length - 1;
    statusCalls++;
    return _tasks[index];
  }
}

class _FakeFeedRepository extends FeedRepository {
  _FakeFeedRepository({
    required this.posts,
    this.unfilteredFailuresRemaining = 0,
    this.unfilteredResponses,
  });

  final List<SourcePost> posts;
  int unfilteredFailuresRemaining;
  int unfilteredCalls = 0;
  final Map<String, int> filteredCalls = {};
  final List<List<SourcePost>>? unfilteredResponses;
  int _unfilteredResponseIndex = 0;

  @override
  Future<List<SourcePost>> getPosts(
    String taskId, {
    String? sourceFilter,
  }) async {
    if (sourceFilter == null) {
      unfilteredCalls++;
      if (unfilteredFailuresRemaining > 0) {
        unfilteredFailuresRemaining--;
        throw Exception('temporary failure');
      }
      final responses = unfilteredResponses;
      if (responses != null && responses.isNotEmpty) {
        final index = _unfilteredResponseIndex < responses.length
            ? _unfilteredResponseIndex
            : responses.length - 1;
        _unfilteredResponseIndex++;
        return responses[index];
      }
      return posts;
    }
    filteredCalls[sourceFilter] = (filteredCalls[sourceFilter] ?? 0) + 1;
    return posts.where((post) => post.source == sourceFilter).toList();
  }
}

class _TaskDetailThenRawDataHost extends StatefulWidget {
  const _TaskDetailThenRawDataHost();

  @override
  State<_TaskDetailThenRawDataHost> createState() =>
      _TaskDetailThenRawDataHostState();
}

class _TaskDetailThenRawDataHostState
    extends State<_TaskDetailThenRawDataHost> {
  bool _showRawData = false;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        ref.watch(taskDetailProvider('task-1'));
        return Column(
          children: [
            TextButton(
              onPressed: () => setState(() => _showRawData = true),
              child: const Text('SHOW RAW DATA'),
            ),
            Expanded(
              child: _showRawData
                  ? const RawDataTab(taskId: 'task-1')
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

Widget _wrap(
  Widget child, {
  FeedRepository? feedRepository,
  AnalysisRepository? analysisRepository,
}) {
  return ProviderScope(
    overrides: [
      analysisRepositoryProvider.overrideWithValue(
        analysisRepository ??
            _FakeAnalysisRepository(tasks: [_taskWithStatus('completed')]),
      ),
      feedRepositoryProvider.overrideWithValue(
        feedRepository ??
            _FakeFeedRepository(
              posts: const [
                SourcePost(
                  id: 'post-1',
                  taskId: 'task-1',
                  source: 'reddit',
                  author: 'trendpulse',
                  content: 'A single record keeps the filter rail visible.',
                  url: 'https://example.com/post-1',
                  engagement: 42,
                  publishedAt: '2026-03-28T12:00:00Z',
                  collectedAt: '2026-03-28T12:10:00Z',
                ),
              ],
            ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets(
    'raw data tab reuses the unfiltered fetch when no filter is active',
    (tester) async {
      final repo = _FakeFeedRepository(
        posts: const [
          SourcePost(
            id: 'post-1',
            taskId: 'task-1',
            source: 'reddit',
            author: 'trendpulse',
            content: 'A single record keeps the filter rail visible.',
            url: 'https://example.com/post-1',
            engagement: 42,
            publishedAt: '2026-03-28T12:00:00Z',
            collectedAt: '2026-03-28T12:10:00Z',
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(const RawDataTab(taskId: 'task-1'), feedRepository: repo),
      );
      await tester.pumpAndSettle();

      expect(repo.unfilteredCalls, 1);
    },
  );

  testWidgets(
    'raw data tab retry re-fetches the unfiltered source after failure',
    (tester) async {
      final repo = _FakeFeedRepository(
        posts: const [
          SourcePost(
            id: 'post-1',
            taskId: 'task-1',
            source: 'reddit',
            author: 'trendpulse',
            content: 'Recovered after retry.',
            url: 'https://example.com/post-1',
            engagement: 42,
            publishedAt: '2026-03-28T12:00:00Z',
            collectedAt: '2026-03-28T12:10:00Z',
          ),
        ],
        unfilteredFailuresRemaining: 1,
      );

      await tester.pumpWidget(
        _wrap(const RawDataTab(taskId: 'task-1'), feedRepository: repo),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);

      await tester.tap(find.text('RETRY'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Recovered after retry.'), findsOneWidget);
      expect(repo.unfilteredCalls, 2);
    },
  );

  testWidgets(
    'raw data tab refreshes posts while task polling is in progress',
    (tester) async {
      final analysisRepository = _FakeAnalysisRepository(
        tasks: [
          _taskWithStatus('pending'),
          _taskWithStatus('collecting'),
          _taskWithStatus('completed'),
        ],
      );
      final feedRepository = _FakeFeedRepository(
        posts: const [],
        unfilteredResponses: const [
          [
            SourcePost(
              id: 'post-1',
              taskId: 'task-1',
              source: 'reddit',
              author: 'trendpulse',
              content: 'Initial record.',
              url: 'https://example.com/post-1',
              engagement: 42,
              publishedAt: '2026-03-28T12:00:00Z',
              collectedAt: '2026-03-28T12:10:00Z',
            ),
          ],
          [
            SourcePost(
              id: 'post-1',
              taskId: 'task-1',
              source: 'reddit',
              author: 'trendpulse',
              content: 'Initial record.',
              url: 'https://example.com/post-1',
              engagement: 42,
              publishedAt: '2026-03-28T12:00:00Z',
              collectedAt: '2026-03-28T12:10:00Z',
            ),
            SourcePost(
              id: 'post-2',
              taskId: 'task-1',
              source: 'reddit',
              author: 'trendpulse',
              content: 'Newly collected post.',
              url: 'https://example.com/post-2',
              engagement: 64,
              publishedAt: '2026-03-28T12:01:00Z',
              collectedAt: '2026-03-28T12:11:00Z',
            ),
          ],
          [
            SourcePost(
              id: 'post-1',
              taskId: 'task-1',
              source: 'reddit',
              author: 'trendpulse',
              content: 'Initial record.',
              url: 'https://example.com/post-1',
              engagement: 42,
              publishedAt: '2026-03-28T12:00:00Z',
              collectedAt: '2026-03-28T12:10:00Z',
            ),
            SourcePost(
              id: 'post-2',
              taskId: 'task-1',
              source: 'reddit',
              author: 'trendpulse',
              content: 'Newly collected post.',
              url: 'https://example.com/post-2',
              engagement: 64,
              publishedAt: '2026-03-28T12:01:00Z',
              collectedAt: '2026-03-28T12:11:00Z',
            ),
          ],
        ],
      );

      await tester.pumpWidget(
        _wrap(
          const RawDataTab(taskId: 'task-1'),
          feedRepository: feedRepository,
          analysisRepository: analysisRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Initial record.'), findsOneWidget);
      expect(find.text('Newly collected post.'), findsNothing);
      expect(feedRepository.unfilteredCalls, 1);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Newly collected post.'), findsOneWidget);
      expect(feedRepository.unfilteredCalls, 2);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'raw data does not miss the first refresh when task detail was already being watched',
    (tester) async {
      final analysisRepository = _FakeAnalysisRepository(
        tasks: [
          _taskWithStatus('pending'),
          _taskWithStatus('collecting'),
          _taskWithStatus('completed'),
        ],
      );
      final feedRepository = _FakeFeedRepository(
        posts: const [],
        unfilteredResponses: const [
          [
            SourcePost(
              id: 'post-1',
              taskId: 'task-1',
              source: 'reddit',
              author: 'trendpulse',
              content: 'Initial record.',
              url: 'https://example.com/post-1',
              engagement: 42,
              publishedAt: '2026-03-28T12:00:00Z',
              collectedAt: '2026-03-28T12:10:00Z',
            ),
          ],
          [
            SourcePost(
              id: 'post-1',
              taskId: 'task-1',
              source: 'reddit',
              author: 'trendpulse',
              content: 'Initial record.',
              url: 'https://example.com/post-1',
              engagement: 42,
              publishedAt: '2026-03-28T12:00:00Z',
              collectedAt: '2026-03-28T12:10:00Z',
            ),
            SourcePost(
              id: 'post-2',
              taskId: 'task-1',
              source: 'reddit',
              author: 'trendpulse',
              content: 'First real refresh after tab mount.',
              url: 'https://example.com/post-2',
              engagement: 64,
              publishedAt: '2026-03-28T12:01:00Z',
              collectedAt: '2026-03-28T12:11:00Z',
            ),
          ],
        ],
      );

      await tester.pumpWidget(
        _wrap(
          const _TaskDetailThenRawDataHost(),
          feedRepository: feedRepository,
          analysisRepository: analysisRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(analysisRepository.statusCalls, 1);
      expect(feedRepository.unfilteredCalls, 0);

      await tester.tap(find.text('SHOW RAW DATA'));
      await tester.pumpAndSettle();

      expect(find.text('Initial record.'), findsOneWidget);
      expect(find.text('First real refresh after tab mount.'), findsNothing);
      expect(feedRepository.unfilteredCalls, 1);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('First real refresh after tab mount.'), findsOneWidget);
      expect(feedRepository.unfilteredCalls, 2);
    },
  );

  testWidgets('raw data filters avoid harsh onSurface fills and tiny labels', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const RawDataTab(taskId: 'task-1')));
    await tester.pumpAndSettle();

    final pageContext = tester.element(find.byType(RawDataTab));
    final theme = Theme.of(pageContext);
    final chip = tester.widget<FilterChip>(find.byType(FilterChip).first);
    final shape = chip.shape as RoundedRectangleBorder;

    expect(chip.selectedColor, isNot(theme.colorScheme.onSurface));
    expect(chip.labelStyle?.fontSize, 13);
    expect(shape.borderRadius, isNot(BorderRadius.zero));
  });
}
