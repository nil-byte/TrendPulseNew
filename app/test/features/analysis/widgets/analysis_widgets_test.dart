import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/animations/number_ticker.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/l10n/app_localizations.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/sentiment_gauge.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/heat_index_card.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/key_insight_card.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
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

    testWidgets('displays normalized scale suffix', (tester) async {
      await tester.pumpWidget(_wrap(const SentimentGauge(score: 50)));
      expect(find.text('/100'), findsOneWidget);
    });

    testWidgets('displays localized sentiment score label in English', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SentimentGauge(score: 30)));
      expect(find.text('SENTIMENT SCORE'), findsOneWidget);
    });

    testWidgets('displays localized sentiment score label in Chinese', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SentimentGauge(score: 30), locale: const Locale('zh')),
      );
      expect(find.text('情感评分'), findsOneWidget);
      expect(find.text('SENTIMENT'), findsNothing);
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
      expect(find.text('HEAT INDEX'), findsOneWidget);
    });

    testWidgets('displays localized heat index label in Chinese', (tester) async {
      await tester.pumpWidget(
        _wrap(const HeatIndexCard(heatIndex: 85), locale: const Locale('zh')),
      );
      expect(find.text('热度指数'), findsOneWidget);
      expect(find.text('HEAT INDEX'), findsNothing);
    });

    testWidgets('renders editorial heat icon', (tester) async {
      await tester.pumpWidget(_wrap(const HeatIndexCard(heatIndex: 60)));
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
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
      expect(find.text(l10n.sourceCountLabel(12).toUpperCase()), findsOneWidget);
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
      expect(find.text(l10n.sourceCountLabel(5).toUpperCase()), findsOneWidget);
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
      expect(find.text(l10n.sourceCountLabel(8).toUpperCase()), findsOneWidget);
    });
  });
}
