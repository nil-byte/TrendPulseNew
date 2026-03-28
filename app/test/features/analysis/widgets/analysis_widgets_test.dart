import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/animations/number_ticker.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/l10n/app_localizations.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/sentiment_gauge.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/heat_index_card.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/key_insight_card.dart';

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
  group('SentimentGauge', () {
    testWidgets('displays score via NumberTicker', (tester) async {
      await tester.pumpWidget(_wrap(const SentimentGauge(score: 75)));
      expect(find.byType(NumberTicker), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('75'), findsOneWidget);
    });

    testWidgets('renders CustomPaint', (tester) async {
      await tester.pumpWidget(_wrap(const SentimentGauge(score: 50)));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('displays Sentiment Score label', (tester) async {
      await tester.pumpWidget(_wrap(const SentimentGauge(score: 30)));
      expect(find.text('Sentiment Score'), findsOneWidget);
    });

    testWidgets('rounds score to integer', (tester) async {
      await tester.pumpWidget(_wrap(const SentimentGauge(score: 72.8)));
      await tester.pumpAndSettle();
      expect(find.text('73'), findsOneWidget);
    });
  });

  group('HeatIndexCard', () {
    testWidgets('displays value via NumberTicker and Heat Index label', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const HeatIndexCard(heatIndex: 85)));
      expect(find.byType(NumberTicker), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('85'), findsOneWidget);
      expect(find.text('Heat Index'), findsOneWidget);
    });

    testWidgets('renders LinearProgressIndicator', (tester) async {
      await tester.pumpWidget(_wrap(const HeatIndexCard(heatIndex: 60)));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('rounds value to integer', (tester) async {
      await tester.pumpWidget(_wrap(const HeatIndexCard(heatIndex: 42.7)));
      await tester.pumpAndSettle();
      expect(find.text('43'), findsOneWidget);
    });
  });

  group('KeyInsightCard', () {
    testWidgets('displays insight text and source count', (tester) async {
      const insight = KeyInsight(
        text: 'AI adoption is accelerating',
        sentiment: 'positive',
        sourceCount: 12,
      );
      await tester.pumpWidget(_wrap(const KeyInsightCard(insight: insight)));
      expect(find.text('AI adoption is accelerating'), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(KeyInsightCard)),
      )!;
      expect(find.text(l10n.sourceCountLabel(12)), findsOneWidget);
    });

    testWidgets('renders with negative sentiment', (tester) async {
      const insight = KeyInsight(
        text: 'Market downturn expected',
        sentiment: 'negative',
        sourceCount: 5,
      );
      await tester.pumpWidget(_wrap(const KeyInsightCard(insight: insight)));
      expect(find.text('Market downturn expected'), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(KeyInsightCard)),
      )!;
      expect(find.text(l10n.sourceCountLabel(5)), findsOneWidget);
    });

    testWidgets('renders with neutral sentiment', (tester) async {
      const insight = KeyInsight(
        text: 'Mixed signals observed',
        sentiment: 'neutral',
        sourceCount: 8,
      );
      await tester.pumpWidget(_wrap(const KeyInsightCard(insight: insight)));
      expect(find.text('Mixed signals observed'), findsOneWidget);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(KeyInsightCard)),
      )!;
      expect(find.text(l10n.sourceCountLabel(8)), findsOneWidget);
    });
  });
}
