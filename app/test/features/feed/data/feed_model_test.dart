import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/features/feed/data/feed_model.dart';

void main() {
  group('SourcePost.fromJson', () {
    test('parses valid data with all fields', () {
      final json = {
        'id': 'post-1',
        'task_id': 'task-1',
        'source': 'reddit',
        'source_id': 'abc123',
        'author': 'user42',
        'content': 'Flutter is amazing for mobile dev',
        'url': 'https://reddit.com/r/flutter/123',
        'engagement': 256,
        'published_at': '2026-03-27T12:00:00Z',
        'collected_at': '2026-03-28T00:00:00Z',
      };
      final post = SourcePost.fromJson(json);

      expect(post.id, 'post-1');
      expect(post.taskId, 'task-1');
      expect(post.source, 'reddit');
      expect(post.sourceId, 'abc123');
      expect(post.author, 'user42');
      expect(post.content, 'Flutter is amazing for mobile dev');
      expect(post.url, 'https://reddit.com/r/flutter/123');
      expect(post.engagement, 256);
      expect(post.publishedAt, '2026-03-27T12:00:00Z');
      expect(post.collectedAt, '2026-03-28T00:00:00Z');
    });

    test('handles nullable fields', () {
      final json = {
        'id': 'post-2',
        'task_id': 'task-1',
        'source': 'youtube',
        'content': 'Great video on Dart',
        'collected_at': '2026-03-28T00:00:00Z',
      };
      final post = SourcePost.fromJson(json);

      expect(post.sourceId, isNull);
      expect(post.author, isNull);
      expect(post.url, isNull);
      expect(post.engagement, 0);
      expect(post.publishedAt, isNull);
    });
  });
}
