import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/history/data/history_item.dart';
import 'package:trendpulse/features/history/presentation/widgets/history_card.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('shows overflow badge when more than three sources exist', (
    tester,
  ) async {
    const item = HistoryItem(
      id: 'task-1',
      keyword: 'AI',
      status: 'completed',
      contentLanguage: 'en',
      reportLanguage: 'en',
      sources: ['reddit', 'youtube', 'x', 'news', 'blogs'],
      createdAt: '2026-03-28T12:00:00Z',
      sentimentScore: 72,
      postCount: 18,
    );

    await tester.pumpWidget(_wrap(HistoryCard(item: item, onTap: _noop)));
    final pageContext = tester.element(find.byType(HistoryCard));
    final theme = Theme.of(pageContext);

    expect(find.text('+2'), findsOneWidget);

    final overflowBadge = tester.widget<Text>(find.text('+2'));
    final completedLabel = tester.widget<Text>(find.text('COMPLETED'));

    expect(overflowBadge.style?.fontSize, theme.textTheme.labelSmall?.fontSize);
    expect(completedLabel.style?.fontSize, 10);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('POSTS'), findsOneWidget);
  });

  testWidgets('shows completed status plus degraded quality badge with 0-100 sentiment score', (
    tester,
  ) async {
    const item = HistoryItem(
      id: 'task-2',
      keyword: 'AI Outlook',
      status: 'completed',
      quality: 'degraded',
      contentLanguage: 'en',
      reportLanguage: 'en',
      sources: ['reddit'],
      createdAt: '2026-03-28T12:00:00Z',
      sentimentScore: 72,
      postCount: 12,
    );

    await tester.pumpWidget(_wrap(HistoryCard(item: item, onTap: _noop)));

    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('SOURCE ISSUES'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);
    expect(find.text('7200'), findsNothing);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('POSTS'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('does not show degraded badge for failed tasks', (tester) async {
    const item = HistoryItem(
      id: 'task-3',
      keyword: 'AI Failure',
      status: 'failed',
      quality: 'degraded',
      contentLanguage: 'en',
      reportLanguage: 'en',
      sources: ['reddit'],
      createdAt: '2026-03-28T12:00:00Z',
      errorMessage: 'Collection failed.',
    );

    await tester.pumpWidget(_wrap(HistoryCard(item: item, onTap: _noop)));

    expect(find.text('FAILED'), findsOneWidget);
    expect(find.text('SOURCE ISSUES'), findsNothing);
  });
}

void _noop() {}
