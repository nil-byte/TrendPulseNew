import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/features/history/data/history_item.dart';

void main() {
  test('HistoryItem.fromJson parses canonical task metrics', () {
    final item = HistoryItem.fromJson({
      'id': 'task-1',
      'keyword': 'AI Watch',
      'status': 'completed',
      'quality': 'degraded',
      'quality_summary': 'Completed with source issues: youtube (API down).',
      'source_outcomes': [
        {
          'source': 'reddit',
          'status': 'success',
          'post_count': 18,
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
      'content_language': 'en',
      'report_language': 'zh',
      'sources': ['reddit'],
      'created_at': '2026-03-28T12:00:00Z',
      'sentiment_score': 72.5,
      'post_count': 18,
    });

    expect(item.status, 'completed');
    expect(item.quality, 'degraded');
    expect(item.qualitySummary, 'Completed with source issues: youtube (API down).');
    expect(item.contentLanguage, 'en');
    expect(item.reportLanguage, 'zh');
    expect(item.sentimentScore, 72.5);
    expect(item.postCount, 18);
    expect(item.errorMessage, isNull);
    expect(item.isDegraded, isTrue);
    expect(item.sourceOutcomes, hasLength(2));
    expect(item.canViewReport, isTrue);
  });

  test('HistoryItem.fromJson throws when content_language is missing', () {
    expect(
      () => HistoryItem.fromJson({
        'id': 'task-2',
        'keyword': 'AI Watch',
        'status': 'pending',
        'report_language': 'zh',
        'created_at': '2026-03-28T12:00:00Z',
      }),
      throwsFormatException,
    );
  });

  test('HistoryItem.fromJson throws when report_language is missing', () {
    expect(
      () => HistoryItem.fromJson({
        'id': 'task-3',
        'keyword': 'AI Watch',
        'status': 'pending',
        'content_language': 'zh',
        'created_at': '2026-03-28T12:00:00Z',
      }),
      throwsFormatException,
    );
  });
}
