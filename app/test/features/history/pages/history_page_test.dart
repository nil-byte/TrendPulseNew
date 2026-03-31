import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/history/data/history_item.dart';
import 'package:trendpulse/features/history/data/history_repository.dart';
import 'package:trendpulse/features/history/presentation/pages/history_page.dart';
import 'package:trendpulse/features/history/presentation/providers/history_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

HistoryItem _itemWithStatus(String status) {
  return HistoryItem(
    id: 'task-1',
    keyword: 'AI Watch',
    status: status,
    contentLanguage: 'en',
    reportLanguage: 'en',
    sources: const ['reddit'],
    createdAt: '2026-03-28T12:00:00Z',
  );
}

class _PendingHistoryRepository extends HistoryRepository {
  final Completer<List<HistoryItem>> _never = Completer<List<HistoryItem>>();

  @override
  Future<List<HistoryItem>> getHistory() => _never.future;
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

class _DeleteControlledHistoryRepository extends HistoryRepository {
  _DeleteControlledHistoryRepository({
    required this.items,
    required this.deleteCompleter,
  });

  final List<HistoryItem> items;
  final Completer<void> deleteCompleter;
  int getHistoryCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<HistoryItem>> getHistory() async {
    getHistoryCalls++;
    return items;
  }

  @override
  Future<void> deleteTask(String taskId) async {
    deleteCalls++;
    await deleteCompleter.future;
  }
}

Widget _wrap(HistoryRepository repository) {
  return ProviderScope(
    overrides: [historyRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: const HistoryPage(),
    ),
  );
}

class _HistoryPageHost extends StatefulWidget {
  const _HistoryPageHost({super.key});

  @override
  State<_HistoryPageHost> createState() => _HistoryPageHostState();
}

class _HistoryPageHostState extends State<_HistoryPageHost> {
  bool _showHistory = true;

  void hideHistory() {
    setState(() => _showHistory = false);
  }

  @override
  Widget build(BuildContext context) {
    return _showHistory
        ? const HistoryPage()
        : const Scaffold(body: SizedBox.shrink());
  }
}

Widget _wrapWithHost(
  ProviderContainer container, {
  required GlobalKey<_HistoryPageHostState> hostKey,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: _HistoryPageHost(key: hostKey),
    ),
  );
}

void main() {
  testWidgets('history page loading state uses editorial card skeletons', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_PendingHistoryRepository()));
    await tester.pump();

    final shimmer = tester.widget<ShimmerLoading>(find.byType(ShimmerLoading));

    expect(shimmer.cardSkeleton, isTrue);
    expect(
      shimmer.padding,
      const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.sm,
      ),
    );
  });

  testWidgets('history page manual refresh re-fetches history', (tester) async {
    final repository = _SequencedHistoryRepository([
      [_itemWithStatus('completed')],
      [_itemWithStatus('completed')],
    ]);

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(repository.getHistoryCalls, 1);

    final refreshIndicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );

    await refreshIndicator.onRefresh();
    await tester.pumpAndSettle();

    expect(repository.getHistoryCalls, 2);
  });

  testWidgets('does not refresh after delete succeeds when page is disposed', (
    tester,
  ) async {
    final deleteCompleter = Completer<void>();
    final hostKey = GlobalKey<_HistoryPageHostState>();
    final repository = _DeleteControlledHistoryRepository(
      items: [_itemWithStatus('completed')],
      deleteCompleter: deleteCompleter,
    );
    final container = ProviderContainer(
      overrides: [historyRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen<AsyncValue<List<HistoryItem>>>(
      historyListProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await tester.pumpWidget(_wrapWithHost(container, hostKey: hostKey));
    await tester.pumpAndSettle();

    expect(repository.getHistoryCalls, 1);

    final dismissible = tester.widget<Dismissible>(find.byType(Dismissible));
    unawaited(dismissible.confirmDismiss!(DismissDirection.endToStart));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'DELETE'));
    await tester.pump();

    expect(repository.deleteCalls, 1);

    hostKey.currentState!.hideHistory();
    await tester.pump();

    deleteCompleter.complete();
    await tester.pump();
    await tester.pump();

    expect(repository.getHistoryCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
