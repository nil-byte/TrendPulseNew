import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/features/subscription/data/subscription_model.dart';

void main() {
  test('SubscriptionTask.fromJson parses canonical task metrics', () {
    final task = SubscriptionTask.fromJson({
      'id': 'task-1',
      'keyword': 'AI Watch',
      'status': 'partial',
      'created_at': '2026-03-28T12:00:00Z',
      'sentiment_score': 72.5,
      'post_count': 18,
      'error_message': 'Completed with source failures: youtube (API down).',
    });

    expect(task.status, 'partial');
    expect(task.sentimentScore, 72.5);
    expect(task.postCount, 18);
    expect(
      task.errorMessage,
      'Completed with source failures: youtube (API down).',
    );
    expect(task.canViewReport, isTrue);
  });
}
