import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/network/api_exception.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/presentation/pages/analysis_page.dart';

import 'analysis_page_test_helpers.dart';

void main() {
  testWidgets(
    'analysis search refreshes source availability before creating a task',
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
    'analysis page only shows no-available-sources message for matching 422 errors',
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
        createTaskException: const ApiException(
          message: '请求参数无效，请检查输入或稍后重试。',
          statusCode: 422,
          debugMessage: 'keyword validation failed',
        ),
      );
      await tester.pumpWidget(
        wrapAnalysisPage(const AnalysisPage(), analysisRepository: repo),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to start this analysis right now. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'No data sources are currently available. Check source configuration or try again later.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'analysis page shows no-available-sources message for matching 422 errors',
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
        createTaskException: const ApiException(
          message: '请求参数无效，请检查输入或稍后重试。',
          statusCode: 422,
          errorCode: 'no_available_sources',
          debugMessage: 'No requested sources are currently available.',
        ),
      );
      await tester.pumpWidget(
        wrapAnalysisPage(const AnalysisPage(), analysisRepository: repo),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No data sources are currently available. Check source configuration or try again later.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Unable to start this analysis right now. Please try again.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'analysis search falls back to createTask when source refresh fails after local sources became empty',
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
        sourceAvailabilityExceptionOnRefresh: Exception(
          'temporary source check failure',
        ),
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
      expect(
        find.text(
          'No data sources are currently available. Check source configuration or try again later.',
        ),
        findsNothing,
      );
    },
  );
}
