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
      language: 'en',
      sources: ['reddit', 'youtube', 'x', 'news', 'blogs'],
      createdAt: '2026-03-28T12:00:00Z',
      sentimentScore: 0.72,
    );

    await tester.pumpWidget(_wrap(HistoryCard(item: item, onTap: _noop)));

    expect(find.text('+2'), findsOneWidget);

    final overflowBadge = tester.widget<Text>(find.text('+2'));
    final completedLabel = tester.widget<Text>(find.text('COMPLETED'));

    expect(overflowBadge.style?.fontSize, 12.5);
    expect(completedLabel.style?.fontSize, 12.5);
  });
}

void _noop() {}
