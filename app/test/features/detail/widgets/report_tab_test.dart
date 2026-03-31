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
    contentLanguage: 'zh',
    reportLanguage: 'zh',
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
    mermaidMindmap:
        'mindmap\n'
        '  root((人工智能))\n'
        '    摘要\n'
        '      整体讨论热度稳定，情绪基调以建设性为主。\n'
        '    观点脉络\n'
        '      洞察 1\n'
        '        讨论正从单一圈层扩展到更广泛的投资与创作者社群。\n'
        '        正面观点\n'
        '        12 条来源\n',
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
    expect(find.text('洞察 01'), findsOneWidget);
    expect(
      find.text(
        '整体讨论热度稳定，情绪基调以建设性为主。',
        findRichText: true,
      ),
      findsWidgets,
    );

    await tester.scrollUntilVisible(
      find.text('情感分布'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('情感分布'), findsOneWidget);
  });

  testWidgets('report tab renders the Mermaid mindmap section', (tester) async {
    await tester.pumpWidget(
      _wrap(
        analysisRepository: _FakeAnalysisRepository(task: task, report: report),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('思维导图'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-mermaid-mindmap')), findsOneWidget);
    expect(find.text('人工智能'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('观点脉络'), findsOneWidget);
    expect(find.text('正面观点'), findsOneWidget);
    expect(find.text('12 条来源'), findsOneWidget);
  });

  testWidgets(
    'report tab shows a visible fallback card when Mermaid text is unsupported',
    (tester) async {
      const unsupportedMermaidReport = AnalysisReport(
        id: 'report-unsupported',
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
        mermaidMindmap: 'flowchart TD\n  A[Unsupported] --> B[Mindmap]',
        createdAt: '2026-03-28T12:05:00Z',
      );

      await tester.pumpWidget(
        _wrap(
          analysisRepository: _FakeAnalysisRepository(
            task: task,
            report: unsupportedMermaidReport,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('report-mermaid-mindmap-fallback')),
        findsOneWidget,
      );
      expect(find.text('当前导图暂不可视化'), findsOneWidget);
      expect(find.textContaining('目前仅支持后端生成的 Mermaid mindmap 子集'), findsOneWidget);
      expect(find.textContaining('flowchart TD'), findsOneWidget);
    },
  );
}
