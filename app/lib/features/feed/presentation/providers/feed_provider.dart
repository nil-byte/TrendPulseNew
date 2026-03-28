import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/features/feed/data/feed_model.dart';
import 'package:trendpulse/features/feed/data/feed_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository();
});

final selectedTaskIdProvider = StateProvider<String?>((ref) => null);

final sourceFilterProvider = StateProvider<String?>((ref) => null);

final feedPostsProvider = FutureProvider<List<SourcePost>>((ref) async {
  final taskId = ref.watch(selectedTaskIdProvider);
  final sourceFilter = ref.watch(sourceFilterProvider);

  if (taskId == null) return [];

  final repository = ref.watch(feedRepositoryProvider);
  return repository.getPosts(taskId, sourceFilter: sourceFilter);
});
