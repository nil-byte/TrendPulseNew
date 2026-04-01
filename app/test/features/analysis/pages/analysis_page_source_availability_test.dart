import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/presentation/pages/analysis_page.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/analysis_source_chip.dart';

import 'analysis_page_test_helpers.dart';

void main() {
  testWidgets('analysis page deselects and disables unavailable sources', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapAnalysisPage(
        const AnalysisPage(),
        analysisRepository: FakeAnalysisRepository(
          sourceAvailability: const [
            AnalysisSourceAvailability(
              source: 'reddit',
              status: 'unconfigured',
              isAvailable: false,
            ),
            AnalysisSourceAvailability(
              source: 'youtube',
              status: 'available',
              isAvailable: true,
            ),
            AnalysisSourceAvailability(
              source: 'x',
              status: 'unconfigured',
              isAvailable: false,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await tester.pumpAndSettle();

    final chips = tester
        .widgetList<AnalysisSourceChip>(find.byType(AnalysisSourceChip))
        .toList();
    final redditChip = chips[0];
    final youtubeChip = chips[1];
    final xChip = chips[2];

    expect(redditChip.selected, isFalse);
    expect(redditChip.enabled, isFalse);
    expect(youtubeChip.selected, isTrue);
    expect(youtubeChip.enabled, isTrue);
    expect(xChip.selected, isFalse);
    expect(xChip.enabled, isFalse);
  });

  testWidgets('analysis page keeps degraded sources selectable', (tester) async {
    await tester.pumpWidget(
      wrapAnalysisPage(
        const AnalysisPage(),
        analysisRepository: FakeAnalysisRepository(
          sourceAvailability: const [
            AnalysisSourceAvailability(
              source: 'reddit',
              status: 'degraded',
              isAvailable: true,
              reason: 'Reddit connection failed on last run.',
              reasonCode: 'reddit_network_unreachable',
              checkedAt: '2026-03-30T00:00:00Z',
            ),
            AnalysisSourceAvailability(
              source: 'youtube',
              status: 'available',
              isAvailable: true,
            ),
            AnalysisSourceAvailability(
              source: 'x',
              status: 'available',
              isAvailable: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await tester.pumpAndSettle();

    final chips = tester
        .widgetList<AnalysisSourceChip>(find.byType(AnalysisSourceChip))
        .toList();
    final redditChip = chips[0];

    expect(redditChip.selected, isTrue);
    expect(redditChip.enabled, isTrue);
    expect(redditChip.status, 'degraded');
  });

  testWidgets(
    'initial source hydration does not overwrite a user selection made while loading',
    (tester) async {
      final repo = DelayedSourceAvailabilityRepository();
      await tester.pumpWidget(
        wrapAnalysisPage(const AnalysisPage(), analysisRepository: repo),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.tune_rounded).first);
      await tester.pumpAndSettle();

      final youtubeChip = find.byKey(const ValueKey('analysis-source-youtube'));
      final xChip = find.byKey(const ValueKey('analysis-source-x'));

      await tester.ensureVisible(youtubeChip);
      await tester.tap(youtubeChip);
      await tester.pumpAndSettle();
      await tester.ensureVisible(xChip);
      await tester.tap(xChip);
      await tester.pumpAndSettle();

      repo.sourceAvailabilityCompleter.complete(const [
        AnalysisSourceAvailability(
          source: 'reddit',
          status: 'available',
          isAvailable: true,
        ),
        AnalysisSourceAvailability(
          source: 'youtube',
          status: 'available',
          isAvailable: true,
        ),
        AnalysisSourceAvailability(
          source: 'x',
          status: 'available',
          isAvailable: true,
        ),
      ]);
      await tester.pumpAndSettle();

      final chips = tester
          .widgetList<AnalysisSourceChip>(find.byType(AnalysisSourceChip))
          .toList();
      expect(chips[0].selected, isTrue);
      expect(chips[1].selected, isFalse);
      expect(chips[2].selected, isFalse);
    },
  );
}
