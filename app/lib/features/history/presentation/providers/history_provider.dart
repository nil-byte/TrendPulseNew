import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/features/history/data/history_item.dart';
import 'package:trendpulse/features/history/data/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository();
});

final historyListProvider =
    AutoDisposeFutureProvider<List<HistoryItem>>((ref) async {
  final repository = ref.watch(historyRepositoryProvider);
  return repository.getHistory();
});
