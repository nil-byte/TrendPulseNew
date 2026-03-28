import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/app_providers.dart';

import 'feed_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return FeedRepository(apiClient: api);
});
