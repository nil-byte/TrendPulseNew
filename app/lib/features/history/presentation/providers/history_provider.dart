import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/app_providers.dart';
import 'package:trendpulse/features/history/data/history_item.dart';
import 'package:trendpulse/features/history/data/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return HistoryRepository(apiClient: api);
});

final historyPollingIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 3),
);

final historyListProvider =
    AutoDisposeNotifierProvider<
      HistoryListNotifier,
      AsyncValue<List<HistoryItem>>
    >(
      HistoryListNotifier.new,
    );

class HistoryListNotifier
    extends AutoDisposeNotifier<AsyncValue<List<HistoryItem>>> {
  Timer? _pollTimer;
  bool _disposed = false;
  int _pollGeneration = 0;
  List<HistoryItem> _lastKnownItems = const <HistoryItem>[];
  bool _shouldRetryPollingAfterError = false;
  Future<void> _requestQueue = Future<void>.value();

  @override
  AsyncValue<List<HistoryItem>> build() {
    ref.onDispose(() {
      _disposed = true;
      _pollGeneration++;
      _cancelPollingTimer();
    });

    ref.watch(historyRepositoryProvider);
    _startInitialLoad();
    return const AsyncLoading();
  }

  Future<void> refresh() async {
    final generation = _beginGeneration(showLoading: true);
    await _runRequestForGeneration(generation);
  }

  void _startInitialLoad() {
    final generation = _beginGeneration();
    unawaited(_runRequestForGeneration(generation));
  }

  int _beginGeneration({bool showLoading = false}) {
    _pollGeneration++;
    _cancelPollingTimer();
    _shouldRetryPollingAfterError = _shouldPoll(_lastKnownItems);
    if (showLoading) {
      state = const AsyncLoading();
    }
    return _pollGeneration;
  }

  Future<void> _runRequestForGeneration(int generation) async {
    try {
      final items = await _enqueueHistoryRequest();
      if (!_isActiveGeneration(generation)) {
        return;
      }

      _lastKnownItems = items;
      state = AsyncData(items);
      _syncPolling(items, generation);
    } catch (error, stackTrace) {
      if (!_isActiveGeneration(generation)) {
        return;
      }

      state = AsyncError(error, stackTrace);
      if (_shouldRetryPollingAfterError) {
        _scheduleNextPoll(generation);
      }
    }
  }

  bool _isActiveGeneration(int generation) {
    return !_disposed && generation == _pollGeneration;
  }

  Future<List<HistoryItem>> _getHistory() {
    final repository = ref.read(historyRepositoryProvider);
    return repository.getHistory();
  }

  void _syncPolling(List<HistoryItem> items, int generation) {
    _shouldRetryPollingAfterError = _shouldPoll(items);
    if (_shouldRetryPollingAfterError) {
      _scheduleNextPoll(generation);
      return;
    }

    _cancelPollingTimer();
  }

  bool _shouldPoll(List<HistoryItem> items) {
    return items.any((item) => item.isInProgress);
  }

  void _scheduleNextPoll(int generation) {
    _pollTimer?.cancel();
    final interval = ref.read(historyPollingIntervalProvider);
    _pollTimer = Timer(interval, () async {
      _pollTimer = null;
      if (!_isActiveGeneration(generation)) {
        return;
      }

      await _runRequestForGeneration(generation);
    });
  }

  void _cancelPollingTimer() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<List<HistoryItem>> _enqueueHistoryRequest() {
    final completer = Completer<List<HistoryItem>>();
    _requestQueue = _requestQueue.catchError((_) {}).then((_) async {
      if (_disposed) {
        completer.complete(state.valueOrNull ?? const <HistoryItem>[]);
        return;
      }

      try {
        final items = await _getHistory();
        completer.complete(items);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
