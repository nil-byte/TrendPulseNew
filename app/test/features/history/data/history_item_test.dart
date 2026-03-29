import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/features/history/data/history_item.dart';

void main() {
  test('HistoryItem.fromJson parses canonical task metrics', () {
    final item = HistoryItem.fromJson({
      'id': 'task-1',
      'keyword': 'AI Watch',
      'status': 'partial',
      'language': 'en',
      'sources': ['reddit'],
      'created_at': '2026-03-28T12:00:00Z',
      'sentiment_score': 72.5,
      'post_count': 18,
      'error_message': 'Completed with source failures: youtube (API down).',
    });

    expect(item.status, 'partial');
    expect(item.sentimentScore, 72.5);
    expect(item.postCount, 18);
    expect(
      item.errorMessage,
      'Completed with source failures: youtube (API down).',
    );
    expect(item.canViewReport, isTrue);
  });
}
