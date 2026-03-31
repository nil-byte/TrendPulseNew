import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/app_providers.dart';
import 'package:trendpulse/features/history/data/history_item.dart';
import 'package:trendpulse/features/history/data/history_repository.dart';
import 'package:trendpulse/features/history/presentation/providers/history_provider.dart';

HistoryItem _itemWithStatus(String status, {String keyword = 'AI Watch'}) {
  return HistoryItem(
    id: 'task-1',
    keyword: keyword,
    status: status,
    contentLanguage: 'en',
    reportLanguage: 'en',
    sources: const ['reddit'],
    createdAt: '2026-03-28T12:00:00Z',
  );
}

class _SequencedHistoryRepository extends HistoryRepository {
  _SequencedHistoryRepository(this._responses);

  final List<List<HistoryItem>> _responses;
  int getHistoryCalls = 0;

  @override
  Future<List<HistoryItem>> getHistory() async {
    final index = getHistoryCalls < _responses.length
        ? getHistoryCalls
        : _responses.length - 1;
    getHistoryCalls++;
    return _responses[index];
  }
}

class _QueuedRefreshHistoryRepository extends HistoryRepository {
  int getHistoryCalls = 0;
  final List<Completer<List<HistoryItem>>> pendingRequests = [];

  @override
  Future<List<HistoryItem>> getHistory() {
    getHistoryCalls++;
    if (getHistoryCalls == 1) {
      return Future.value([_itemWithStatus('completed')]);
    }

    final completer = Completer<List<HistoryItem>>();
    pendingRequests.add(completer);
    return completer.future;
  }
}

class _InitialLoadRaceHistoryRepository extends HistoryRepository {
  int getHistoryCalls = 0;
  int maxConcurrentRequests = 0;
  int _inFlightRequests = 0;
  final List<Completer<List<HistoryItem>>> pendingRequests = [];

  @override
  Future<List<HistoryItem>> getHistory() {
    getHistoryCalls++;
    _inFlightRequests++;
    if (_inFlightRequests > maxConcurrentRequests) {
      maxConcurrentRequests = _inFlightRequests;
    }

    final completer = Completer<List<HistoryItem>>();
    pendingRequests.add(completer);
    return completer.future.whenComplete(() {
      _inFlightRequests--;
    });
  }
}

class _FlakyPollingHistoryRepository extends HistoryRepository {
  _FlakyPollingHistoryRepository(this._responses);

  final List<Object> _responses;
  int getHistoryCalls = 0;

  @override
  Future<List<HistoryItem>> getHistory() async {
    final index = getHistoryCalls < _responses.length
        ? getHistoryCalls
        : _responses.length - 1;
    getHistoryCalls++;

    final response = _responses[index];
    if (response is List<HistoryItem>) {
      return response;
    }

    throw response;
  }
}

Widget _wrap(
  HistoryRepository repository, {
  Duration pollingInterval = const Duration(seconds: 1),
}) {
  return ProviderScope(
    overrides: [
      historyRepositoryProvider.overrideWithValue(repository),
      historyPollingIntervalProvider.overrideWithValue(pollingInterval),
    ],
    child: const MaterialApp(home: _HistoryWatcher()),
  );
}

class _HistoryWatcher extends ConsumerWidget {
  const _HistoryWatcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(historyListProvider);
    return const SizedBox.shrink();
  }
}

Future<void> _waitForHistoryValue(ProviderContainer container) async {
  final current = container.read(historyListProvider);
  if (current.hasValue) {
    return;
  }

  final completer = Completer<void>();
  late final ProviderSubscription<AsyncValue<List<HistoryItem>>> subscription;
  subscription = container.listen<AsyncValue<List<HistoryItem>>>(
    historyListProvider,
    (_, next) {
      if (!completer.isCompleted && next.hasValue) {
        completer.complete();
      }
    },
    fireImmediately: true,
  );

  await completer.future;
  subscription.close();
}

void main() {
  testWidgets('polls history again while in-progress tasks remain', (
    tester,
  ) async {
    final repository = _SequencedHistoryRepository([
      [_itemWithStatus('pending')],
      [_itemWithStatus('completed')],
    ]);

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(repository.getHistoryCalls, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(repository.getHistoryCalls, 2);
  });

  testWidgets('stops polling after tasks reach terminal states', (
    tester,
  ) async {
    final repository = _SequencedHistoryRepository([
      [_itemWithStatus('pending')],
      [_itemWithStatus('completed')],
      [_itemWithStatus('completed')],
    ]);

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(repository.getHistoryCalls, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(repository.getHistoryCalls, 2);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(repository.getHistoryCalls, 2);
  });

  testWidgets('continues polling after a transient polling failure', (
    tester,
  ) async {
    final repository = _FlakyPollingHistoryRepository([
      [_itemWithStatus('pending')],
      Exception('temporary history failure'),
      [_itemWithStatus('completed')],
    ]);

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(repository.getHistoryCalls, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(repository.getHistoryCalls, 2);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(repository.getHistoryCalls, 3);
    expect(find.byType(_HistoryWatcher), findsOneWidget);
  });

  test('queues refreshes so only one request runs at a time', () async {
    final repository = _QueuedRefreshHistoryRepository();
    final container = ProviderContainer(
      overrides: [
        historyRepositoryProvider.overrideWithValue(repository),
        historyPollingIntervalProvider.overrideWithValue(
          const Duration(minutes: 1),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen<AsyncValue<List<HistoryItem>>>(
      historyListProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await _waitForHistoryValue(container);

    expect(repository.getHistoryCalls, 1);

    final notifier = container.read(historyListProvider.notifier);
    final firstRefresh = notifier.refresh();
    final secondRefresh = notifier.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(repository.getHistoryCalls, 2);
    expect(repository.pendingRequests, hasLength(1));

    repository.pendingRequests.first.complete([_itemWithStatus('completed')]);
    await firstRefresh;
    await Future<void>.delayed(Duration.zero);

    expect(repository.getHistoryCalls, 3);
    expect(repository.pendingRequests, hasLength(2));

    repository.pendingRequests.last.complete([_itemWithStatus('completed')]);
    await secondRefresh;
  });

  test('queues refresh behind the initial load and keeps refresh result', () async {
    final repository = _InitialLoadRaceHistoryRepository();
    final container = ProviderContainer(
      overrides: [
        historyRepositoryProvider.overrideWithValue(repository),
        historyPollingIntervalProvider.overrideWithValue(
          const Duration(minutes: 1),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen<AsyncValue<List<HistoryItem>>>(
      historyListProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await Future<void>.delayed(Duration.zero);

    expect(repository.getHistoryCalls, 1);
    expect(repository.pendingRequests, hasLength(1));

    final notifier = container.read(historyListProvider.notifier);
    final refreshFuture = notifier.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(repository.getHistoryCalls, 1);
    expect(repository.pendingRequests, hasLength(1));
    expect(repository.maxConcurrentRequests, 1);

    repository.pendingRequests.first.complete([
      _itemWithStatus('completed', keyword: 'initial result'),
    ]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repository.getHistoryCalls, 2);
    expect(repository.pendingRequests, hasLength(2));
    expect(repository.maxConcurrentRequests, 1);

    repository.pendingRequests.last.complete([
      _itemWithStatus('completed', keyword: 'refresh result'),
    ]);
    await refreshFuture;

    expect(
      container.read(historyListProvider).requireValue.single.keyword,
      'refresh result',
    );
  });

  test(
    'does not publish the initial list before the queued refresh result arrives',
    () async {
      final repository = _InitialLoadRaceHistoryRepository();
      final container = ProviderContainer(
        overrides: [
          historyRepositoryProvider.overrideWithValue(repository),
          historyPollingIntervalProvider.overrideWithValue(
            const Duration(minutes: 1),
          ),
        ],
      );
      addTearDown(container.dispose);

      final seenKeywords = <String>[];
      final subscription = container.listen<AsyncValue<List<HistoryItem>>>(
        historyListProvider,
        (_, next) {
          final keyword = next.valueOrNull?.single.keyword;
          if (keyword != null) {
            seenKeywords.add(keyword);
          }
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await Future<void>.delayed(Duration.zero);

      final refreshFuture = container.read(historyListProvider.notifier).refresh();
      await Future<void>.delayed(Duration.zero);

      repository.pendingRequests.first.complete([
        _itemWithStatus('completed', keyword: 'initial result'),
      ]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repository.getHistoryCalls, 2);
      expect(seenKeywords, isEmpty);
      expect(container.read(historyListProvider).valueOrNull, isNull);

      repository.pendingRequests.last.complete([
        _itemWithStatus('completed', keyword: 'refresh result'),
      ]);
      await refreshFuture;

      expect(seenKeywords, ['refresh result']);
    },
  );

  testWidgets('reloads history when task mutation signal changes', (
    tester,
  ) async {
    final repository = _SequencedHistoryRepository([
      [_itemWithStatus('completed', keyword: 'initial result')],
      [_itemWithStatus('completed', keyword: 'mutated result')],
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(repository),
          historyPollingIntervalProvider.overrideWithValue(
            const Duration(minutes: 1),
          ),
        ],
        child: const MaterialApp(home: _HistoryMutationWatcher()),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.getHistoryCalls, 1);
    expect(find.text('initial result'), findsOneWidget);

    await tester.tap(find.text('mutate'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.getHistoryCalls, 2);
    expect(find.text('mutated result'), findsOneWidget);
  });
}

class _HistoryMutationWatcher extends ConsumerWidget {
  const _HistoryMutationWatcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyListProvider);

    return Column(
      children: [
        Text(historyAsync.valueOrNull?.single.keyword ?? 'loading'),
        TextButton(
          onPressed: () => ref.read(taskMutationSignalProvider.notifier).state++,
          child: const Text('mutate'),
        ),
      ],
    );
  }
}
