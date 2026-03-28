import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/data/analysis_repository.dart';
import 'package:trendpulse/features/analysis/presentation/providers/analysis_provider.dart';
import 'package:trendpulse/features/detail/presentation/widgets/report_tab.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class _FakeAnalysisRepository extends AnalysisRepository {
  _FakeAnalysisRepository({
    required this.task,
    required this.report,
  });

  final AnalysisTask task;
  final AnalysisReport report;

  @override
  Future<AnalysisTask> getTaskStatus(String taskId) async => task;

  @override
  Future<AnalysisReport> getReport(String taskId) async => report;
}

Widget _wrap({
  required AnalysisRepository analysisRepository,
  Locale locale = const Locale('zh'),
}) {
  return ProviderScope(
    overrides: [
      analysisRepositoryProvider.overrideWithValue(analysisRepository),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.light,
      home: const Scaffold(body: ReportTab(taskId: 'task-1')),
    ),
  );
}

void main() {
  const task = AnalysisTask(
    id: 'task-1',
    keyword: '人工智能舆情长期趋势观察',
    language: 'zh',
    maxItems: 50,
    status: 'completed',
    sources: ['reddit', 'youtube', 'x'],
    createdAt: '2026-03-28T12:00:00Z',
    updatedAt: '2026-03-28T12:05:00Z',
  );
  const report = AnalysisReport(
    id: 'report-1',
    taskId: 'task-1',
    sentimentScore: 62,
    positiveRatio: 0.42,
    negativeRatio: 0.18,
    neutralRatio: 0.40,
    heatIndex: 78,
    keyInsights: [
      KeyInsight(
        text: '讨论正从单一圈层扩展到更广泛的投资与创作者社群。',
        sentiment: 'positive',
        sourceCount: 12,
      ),
    ],
    summary: '整体讨论热度稳定，情绪基调以建设性为主。',
    createdAt: '2026-03-28T12:05:00Z',
  );

  testWidgets('report tab localizes core section headers in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        analysisRepository: _FakeAnalysisRepository(task: task, report: report),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('核心摘要'), findsOneWidget);
    expect(find.text('关键洞察'), findsOneWidget);
    expect(find.text('情感分布'), findsOneWidget);
    expect(find.text('洞察 01'), findsOneWidget);
    expect(
      find.text(
        '整体讨论热度稳定，情绪基调以建设性为主。',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });
}
