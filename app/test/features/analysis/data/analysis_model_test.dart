import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';

void main() {
  group('AnalysisTask.fromJson', () {
    test('parses valid data', () {
      final json = {
        'id': 'task-1',
        'keyword': 'flutter',
        'content_language': 'en',
        'report_language': 'zh',
        'max_items': 50,
        'status': 'completed',
        'quality': 'degraded',
        'quality_summary': 'Completed with source issues: youtube (API down).',
        'source_outcomes': [
          {
            'source': 'reddit',
            'status': 'success',
            'post_count': 12,
            'reason': null,
            'reason_code': null,
          },
          {
            'source': 'youtube',
            'status': 'failed',
            'post_count': 0,
            'reason': 'API down',
            'reason_code': 'youtube_api_down',
          },
        ],
        'sources': ['reddit', 'youtube'],
        'created_at': '2026-03-28T00:00:00Z',
        'updated_at': '2026-03-28T01:00:00Z',
        'sentiment_score': 72.5,
        'post_count': 12,
      };
      final task = AnalysisTask.fromJson(json);

      expect(task.id, 'task-1');
      expect(task.keyword, 'flutter');
      expect(task.contentLanguage, 'en');
      expect(task.reportLanguage, 'zh');
      expect(task.maxItems, 50);
      expect(task.status, 'completed');
      expect(task.quality, 'degraded');
      expect(
        task.qualitySummary,
        'Completed with source issues: youtube (API down).',
      );
      expect(task.isDegraded, isTrue);
      expect(task.sources, ['reddit', 'youtube']);
      expect(task.createdAt, '2026-03-28T00:00:00Z');
      expect(task.updatedAt, '2026-03-28T01:00:00Z');
      expect(task.sentimentScore, 72.5);
      expect(task.postCount, 12);
      expect(task.errorMessage, isNull);
      expect(task.sourceOutcomes, hasLength(2));
      expect(task.sourceOutcomes.first.source, 'reddit');
      expect(task.sourceOutcomes.first.status, 'success');
      expect(task.sourceOutcomes.last.reasonCode, 'youtube_api_down');
    });

    test('uses defaults for optional fields', () {
      final json = {
        'id': 'task-2',
        'keyword': 'dart',
        'content_language': 'en',
        'report_language': 'zh',
        'status': 'pending',
        'created_at': '2026-03-28T00:00:00Z',
        'updated_at': '2026-03-28T00:00:00Z',
      };
      final task = AnalysisTask.fromJson(json);

      expect(task.contentLanguage, 'en');
      expect(task.reportLanguage, 'zh');
      expect(task.maxItems, 50);
      expect(task.quality, 'clean');
      expect(task.sourceOutcomes, isEmpty);
      expect(task.sources, isEmpty);
    });

    test('throws when content_language is missing', () {
      final json = {
        'id': 'task-4',
        'keyword': 'dart',
        'report_language': 'zh',
        'status': 'pending',
        'created_at': '2026-03-28T00:00:00Z',
        'updated_at': '2026-03-28T00:00:00Z',
      };

      expect(() => AnalysisTask.fromJson(json), throwsFormatException);
    });

    test('throws when report_language is missing', () {
      final json = {
        'id': 'task-5',
        'keyword': 'dart',
        'content_language': 'zh',
        'status': 'pending',
        'created_at': '2026-03-28T00:00:00Z',
        'updated_at': '2026-03-28T00:00:00Z',
      };

      expect(() => AnalysisTask.fromJson(json), throwsFormatException);
    });

    test('parses error_message', () {
      final json = {
        'id': 'task-3',
        'keyword': 'test',
        'content_language': 'en',
        'report_language': 'zh',
        'status': 'failed',
        'created_at': '2026-03-28T00:00:00Z',
        'updated_at': '2026-03-28T00:00:00Z',
        'error_message': 'API rate limit exceeded',
      };
      final task = AnalysisTask.fromJson(json);

      expect(task.errorMessage, 'API rate limit exceeded');
    });

    test('normalizes legacy partial tasks into completed degraded quality', () {
      final json = {
        'id': 'task-legacy',
        'keyword': 'legacy',
        'content_language': 'en',
        'report_language': 'zh',
        'status': 'partial',
        'created_at': '2026-03-28T00:00:00Z',
        'updated_at': '2026-03-28T00:00:00Z',
        'error_message': 'Completed with source failures: youtube (API down).',
      };
      final task = AnalysisTask.fromJson(json);

      expect(task.status, 'completed');
      expect(task.quality, 'degraded');
      expect(
        task.qualitySummary,
        'Completed with source failures: youtube (API down).',
      );
      expect(task.isCompleted, isTrue);
      expect(task.isDegraded, isTrue);
      expect(task.canViewReport, isTrue);
    });
  });

  group('AnalysisTask status getters', () {
    AnalysisTask makeTask(String status, {String quality = 'clean'}) => AnalysisTask(
      id: 'id',
      keyword: 'kw',
      contentLanguage: 'en',
      reportLanguage: 'zh',
      maxItems: 50,
      status: status,
      quality: quality,
      sources: const [],
      createdAt: '',
      updatedAt: '',
    );

    test('isPending', () {
      expect(makeTask('pending').isPending, isTrue);
      expect(makeTask('completed').isPending, isFalse);
    });

    test('isCollecting', () {
      expect(makeTask('collecting').isCollecting, isTrue);
    });

    test('isAnalyzing', () {
      expect(makeTask('analyzing').isAnalyzing, isTrue);
    });

    test('isCompleted', () {
      expect(makeTask('completed').isCompleted, isTrue);
      expect(makeTask('pending').isCompleted, isFalse);
    });

    test('degraded completed task can view report without becoming in-progress', () {
      final task = makeTask('completed', quality: 'degraded');

      expect(task.isDegraded, isTrue);
      expect(task.isCompleted, isTrue);
      expect(task.canViewReport, isTrue);
      expect(task.isInProgress, isFalse);
    });

    test('isFailed', () {
      expect(makeTask('failed').isFailed, isTrue);
    });

    test('isInProgress covers pending, collecting, analyzing', () {
      expect(makeTask('pending').isInProgress, isTrue);
      expect(makeTask('collecting').isInProgress, isTrue);
      expect(makeTask('analyzing').isInProgress, isTrue);
      expect(makeTask('completed').isInProgress, isFalse);
      expect(makeTask('failed').isInProgress, isFalse);
    });
  });

  group('AnalysisSourceAvailability.fromJson', () {
    test('parses availability payload', () {
      final json = {
        'source': 'x',
        'status': 'unconfigured',
        'is_available': false,
        'reason': 'Grok API key is not configured',
        'reason_code': 'grok_api_key_missing',
        'checked_at': null,
      };
      final availability = AnalysisSourceAvailability.fromJson(json);

      expect(availability.source, 'x');
      expect(availability.status, 'unconfigured');
      expect(availability.isAvailable, isFalse);
      expect(availability.reason, 'Grok API key is not configured');
      expect(availability.reasonCode, 'grok_api_key_missing');
      expect(availability.checkedAt, isNull);
    });
  });

  group('KeyInsight.fromJson', () {
    test('parses valid data', () {
      final json = {
        'text': 'AI is trending',
        'sentiment': 'positive',
        'source_count': 10,
      };
      final insight = KeyInsight.fromJson(json);

      expect(insight.text, 'AI is trending');
      expect(insight.sentiment, 'positive');
      expect(insight.sourceCount, 10);
    });

    test('uses defaults for optional fields', () {
      final json = {'text': 'Some insight'};
      final insight = KeyInsight.fromJson(json);

      expect(insight.sentiment, 'neutral');
      expect(insight.sourceCount, 0);
    });
  });

  group('AnalysisReport.fromJson', () {
    test('parses valid data', () {
      final json = {
        'id': 'report-1',
        'task_id': 'task-1',
        'sentiment_score': 72.5,
        'positive_ratio': 0.6,
        'negative_ratio': 0.15,
        'neutral_ratio': 0.25,
        'heat_index': 85.0,
        'key_insights': [
          {'text': 'Insight 1', 'sentiment': 'positive', 'source_count': 5},
          {'text': 'Insight 2', 'sentiment': 'negative', 'source_count': 3},
        ],
        'summary': 'Overall positive sentiment',
        'created_at': '2026-03-28T00:00:00Z',
      };
      final report = AnalysisReport.fromJson(json);

      expect(report.id, 'report-1');
      expect(report.taskId, 'task-1');
      expect(report.sentimentScore, 72.5);
      expect(report.positiveRatio, 0.6);
      expect(report.negativeRatio, 0.15);
      expect(report.neutralRatio, 0.25);
      expect(report.heatIndex, 85.0);
      expect(report.keyInsights, hasLength(2));
      expect(report.summary, 'Overall positive sentiment');
      expect(report.createdAt, '2026-03-28T00:00:00Z');
    });

    test('handles missing key_insights and summary', () {
      final json = {
        'id': 'report-2',
        'task_id': 'task-2',
        'sentiment_score': 50,
        'positive_ratio': 0.3,
        'negative_ratio': 0.3,
        'neutral_ratio': 0.4,
        'heat_index': 40,
        'created_at': '2026-03-28T00:00:00Z',
      };
      final report = AnalysisReport.fromJson(json);

      expect(report.keyInsights, isEmpty);
      expect(report.summary, '');
    });

    test('totalPosts sums source counts', () {
      final report = AnalysisReport(
        id: 'r',
        taskId: 't',
        sentimentScore: 50,
        positiveRatio: 0.5,
        negativeRatio: 0.2,
        neutralRatio: 0.3,
        heatIndex: 50,
        keyInsights: const [
          KeyInsight(text: 'a', sentiment: 'positive', sourceCount: 10),
          KeyInsight(text: 'b', sentiment: 'negative', sourceCount: 5),
        ],
        summary: '',
        createdAt: '',
      );
      expect(report.totalPosts, 15);
    });

    test('totalPosts returns 0 when no insights', () {
      final report = AnalysisReport(
        id: 'r',
        taskId: 't',
        sentimentScore: 50,
        positiveRatio: 0.5,
        negativeRatio: 0.2,
        neutralRatio: 0.3,
        heatIndex: 50,
        keyInsights: const [],
        summary: '',
        createdAt: '',
      );
      expect(report.totalPosts, 0);
    });
  });
}
