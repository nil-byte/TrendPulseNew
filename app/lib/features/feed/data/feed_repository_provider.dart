import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/features/settings/presentation/providers/api_client_provider.dart';

import 'feed_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return FeedRepository(apiClient: api);
});
