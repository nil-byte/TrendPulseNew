import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/app_providers.dart';
import 'package:trendpulse/features/history/data/history_item.dart';
import 'package:trendpulse/features/history/data/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return HistoryRepository(apiClient: api);
});

final historyListProvider = AutoDisposeFutureProvider<List<HistoryItem>>((
  ref,
) async {
  final repository = ref.watch(historyRepositoryProvider);
  return repository.getHistory();
});
