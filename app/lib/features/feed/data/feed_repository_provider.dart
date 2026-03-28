import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'feed_repository.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository();
});
