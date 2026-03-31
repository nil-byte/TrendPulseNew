import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/data/analysis_repository.dart';
import 'package:trendpulse/features/analysis/presentation/providers/analysis_provider.dart';
import 'package:trendpulse/features/detail/presentation/providers/detail_provider.dart';

AnalysisTask _taskWithStatus(String status) {
  return AnalysisTask(
    id: 'task-1',
    keyword: 'Macro AI Sentiment Outlook',
    contentLanguage: 'en',
    reportLanguage: 'en',
    maxItems: 50,
    status: status,
    sources: const ['reddit', 'youtube', 'x'],
    createdAt: '2026-03-28T12:00:00Z',
    updatedAt: '2026-03-28T12:05:00Z',
  );
}

class _SerialPollingRepository extends AnalysisRepository {
  int statusCalls = 0;
  int maxConcurrentPolls = 0;
  int _inFlightPolls = 0;
  final List<Completer<AnalysisTask>> pendingPolls = [];

  @override
  Future<AnalysisTask> getTaskStatus(String taskId) {
    statusCalls++;
    if (statusCalls == 1) {
      return Future.value(_taskWithStatus('pending'));
    }

    _inFlightPolls += 1;
    if (_inFlightPolls > maxConcurrentPolls) {
      maxConcurrentPolls = _inFlightPolls;
    }

    final completer = Completer<AnalysisTask>();
    pendingPolls.add(completer);
    return completer.future.whenComplete(() {
      _inFlightPolls -= 1;
    });
  }
}

class _SlowInitialRepository extends AnalysisRepository {
  int statusCalls = 0;
  final Completer<AnalysisTask> initialCompleter = Completer<AnalysisTask>();

  @override
  Future<AnalysisTask> getTaskStatus(String taskId) {
    statusCalls++;
    return initialCompleter.future;
  }
}

Widget _wrap(AnalysisRepository repository) {
  return ProviderScope(
    overrides: [analysisRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: _TaskWatcher()),
  );
}

class _TaskWatcher extends ConsumerWidget {
  const _TaskWatcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(taskDetailProvider('task-1'));
    return const SizedBox.shrink();
  }
}

void main() {
  testWidgets('task detail polling stays serial while a request is still pending', (
    tester,
  ) async {
    final repository = _SerialPollingRepository();

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(repository.statusCalls, 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(repository.statusCalls, 2);
    expect(repository.maxConcurrentPolls, 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(repository.statusCalls, 2);
    expect(repository.maxConcurrentPolls, 1);

    repository.pendingPolls.single.complete(_taskWithStatus('completed'));
    await tester.pump();
    await tester.pumpAndSettle();
  });

  testWidgets('disposing during the initial load does not start polling later', (
    tester,
  ) async {
    final repository = _SlowInitialRepository();

    await tester.pumpWidget(_wrap(repository));
    await tester.pump();

    expect(repository.statusCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    repository.initialCompleter.complete(_taskWithStatus('pending'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(repository.statusCalls, 1);
  });
}
