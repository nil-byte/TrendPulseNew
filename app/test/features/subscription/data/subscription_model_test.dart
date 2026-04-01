import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/features/subscription/data/subscription_model.dart';

void main() {
  test('Subscription.fromJson and toJson use content_language', () {
    final subscription = Subscription.fromJson({
      'id': 'sub-1',
      'keyword': 'AI Watch',
      'content_language': 'zh',
      'interval': 'daily',
      'max_items': 50,
      'sources': ['reddit', 'youtube'],
      'is_active': true,
      'notify': true,
      'created_at': '2026-03-28T12:00:00Z',
      'updated_at': '2026-03-28T12:00:00Z',
    });

    expect(subscription.contentLanguage, 'zh');
    expect(subscription.toJson()['content_language'], 'zh');
    expect(subscription.toJson().containsKey('language'), isFalse);
    expect(subscription.toJson().containsKey('report_language'), isFalse);
  });

  test('Subscription.fromJson throws when content_language is missing', () {
    expect(
      () => Subscription.fromJson({
        'id': 'sub-1',
        'keyword': 'AI Watch',
        'interval': 'daily',
        'max_items': 50,
        'sources': ['reddit', 'youtube'],
        'is_active': true,
        'notify': true,
        'created_at': '2026-03-28T12:00:00Z',
        'updated_at': '2026-03-28T12:00:00Z',
      }),
      throwsFormatException,
    );
  });

  test('SubscriptionTask.fromJson parses canonical task metrics', () {
    final task = SubscriptionTask.fromJson({
      'id': 'task-1',
      'keyword': 'AI Watch',
      'content_language': 'zh',
      'report_language': 'en',
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
      'created_at': '2026-03-28T12:00:00Z',
      'sentiment_score': 72.5,
      'post_count': 18,
    });

    expect(task.contentLanguage, 'zh');
    expect(task.reportLanguage, 'en');
    expect(task.status, 'completed');
    expect(task.quality, 'degraded');
    expect(task.qualitySummary, 'Completed with source issues: youtube (API down).');
    expect(task.sentimentScore, 72.5);
    expect(task.postCount, 18);
    expect(task.errorMessage, isNull);
    expect(task.isDegraded, isTrue);
    expect(task.sourceOutcomes, hasLength(2));
    expect(task.canViewReport, isTrue);
  });

  test('SubscriptionTask.fromJson throws when content_language is missing', () {
    expect(
      () => SubscriptionTask.fromJson({
        'id': 'task-2',
        'keyword': 'AI Watch',
        'report_language': 'en',
        'status': 'pending',
        'created_at': '2026-03-28T12:00:00Z',
      }),
      throwsFormatException,
    );
  });

  test('SubscriptionTask.fromJson throws when report_language is missing', () {
    expect(
      () => SubscriptionTask.fromJson({
        'id': 'task-3',
        'keyword': 'AI Watch',
        'content_language': 'zh',
        'status': 'pending',
        'created_at': '2026-03-28T12:00:00Z',
      }),
      throwsFormatException,
    );
  });
}
