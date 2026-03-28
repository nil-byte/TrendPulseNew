import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/detail/presentation/widgets/raw_data_tab.dart';
import 'package:trendpulse/features/feed/data/feed_model.dart';
import 'package:trendpulse/features/feed/data/feed_repository.dart';
import 'package:trendpulse/features/feed/data/feed_repository_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class _FakeFeedRepository extends FeedRepository {
  _FakeFeedRepository({
    required this.posts,
    this.unfilteredFailuresRemaining = 0,
  });

  final List<SourcePost> posts;
  int unfilteredFailuresRemaining;
  int unfilteredCalls = 0;
  final Map<String, int> filteredCalls = {};

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
      return posts;
    }
    filteredCalls[sourceFilter] = (filteredCalls[sourceFilter] ?? 0) + 1;
    return posts.where((post) => post.source == sourceFilter).toList();
  }
}

Widget _wrap(Widget child, {FeedRepository? feedRepository}) {
  return ProviderScope(
    overrides: [
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
  testWidgets('raw data tab reuses the unfiltered fetch when no filter is active', (
    tester,
  ) async {
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
  });

  testWidgets('raw data tab retry re-fetches the unfiltered source after failure', (
    tester,
  ) async {
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
  });

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
