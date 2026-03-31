import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/network/api_exception.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/presentation/pages/analysis_page.dart';

import 'analysis_page_test_helpers.dart';

void main() {
  testWidgets(
    'analysis search sends form content language and app report language separately',
    (tester) async {
      final repo = FakeAnalysisRepository(
        sourceAvailability: const [
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
        ],
      );
      await tester.pumpWidget(
        wrapAnalysisPage(
          const AnalysisPage(),
          analysisRepository: repo,
          settingsRepository: FakeSettingsRepository(language: 'zh'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(repo.lastCreateTaskContentLanguage, 'en');
      expect(repo.lastCreateTaskReportLanguage, 'zh');
    },
  );

  testWidgets(
    'analysis search rehydrates sources when availability recovers from an empty selection',
    (tester) async {
      final repo = FakeAnalysisRepository(
        sourceAvailability: const [
          AnalysisSourceAvailability(
            source: 'reddit',
            status: 'unconfigured',
            isAvailable: false,
          ),
          AnalysisSourceAvailability(
            source: 'youtube',
            status: 'unconfigured',
            isAvailable: false,
          ),
          AnalysisSourceAvailability(
            source: 'x',
            status: 'unconfigured',
            isAvailable: false,
          ),
        ],
        refreshedSourceAvailability: const [
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
        createTaskException: const ApiException(message: 'request failed', statusCode: 500),
      );
      await tester.pumpWidget(
        wrapAnalysisPage(const AnalysisPage(), analysisRepository: repo),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(repo.sourceAvailabilityCallCount, 2);
      expect(repo.lastCreateTaskSources, ['youtube']);
    },
  );

  testWidgets(
    'analysis search falls back to refreshed sources when auto-selected sources become stale',
    (tester) async {
      final repo = FakeAnalysisRepository(
        sourceAvailability: const [
          AnalysisSourceAvailability(
            source: 'reddit',
            status: 'available',
            isAvailable: true,
          ),
          AnalysisSourceAvailability(
            source: 'youtube',
            status: 'unconfigured',
            isAvailable: false,
          ),
          AnalysisSourceAvailability(
            source: 'x',
            status: 'unconfigured',
            isAvailable: false,
          ),
        ],
        refreshedSourceAvailability: const [
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
        createTaskException: const ApiException(message: 'request failed', statusCode: 500),
      );
      await tester.pumpWidget(
        wrapAnalysisPage(const AnalysisPage(), analysisRepository: repo),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(repo.sourceAvailabilityCallCount, 2);
      expect(repo.lastCreateTaskSources, ['youtube']);
    },
  );

  testWidgets(
    'analysis search re-expands recovered sources when selection was never customized',
    (tester) async {
      final repo = FakeAnalysisRepository(
        sourceAvailability: const [
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
            status: 'unconfigured',
            isAvailable: false,
          ),
        ],
        refreshedSourceAvailability: const [
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
        ],
        createTaskException: const ApiException(message: 'request failed', statusCode: 500),
      );
      await tester.pumpWidget(
        wrapAnalysisPage(const AnalysisPage(), analysisRepository: repo),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(repo.sourceAvailabilityCallCount, 2);
      expect(repo.lastCreateTaskSources, ['reddit', 'youtube', 'x']);
    },
  );
}
