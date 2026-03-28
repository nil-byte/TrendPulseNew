import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/presentation/providers/analysis_provider.dart';
import 'package:trendpulse/features/feed/data/feed_model.dart';
import 'package:trendpulse/features/feed/data/feed_repository_provider.dart';

final taskDetailProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      TaskDetailNotifier,
      AnalysisTask,
      String
    >(TaskDetailNotifier.new);

class TaskDetailNotifier
    extends AutoDisposeFamilyAsyncNotifier<AnalysisTask, String> {
  Timer? _pollTimer;

  @override
  Future<AnalysisTask> build(String arg) async {
    ref.onDispose(() => _pollTimer?.cancel());
    final repo = ref.read(analysisRepositoryProvider);
    final task = await repo.getTaskStatus(arg);
    if (task.isInProgress) {
      _startPolling(arg);
    }
    return task;
  }

  void _startPolling(String taskId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final repo = ref.read(analysisRepositoryProvider);
        final task = await repo.getTaskStatus(taskId);
        state = AsyncData(task);
        if (!task.isInProgress) {
          _pollTimer?.cancel();
        }
      } catch (e, st) {
        state = AsyncError(e, st);
        _pollTimer?.cancel();
      }
    });
  }

  Future<void> refresh() async {
    _pollTimer?.cancel();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(analysisRepositoryProvider);
      final task = await repo.getTaskStatus(arg);
      if (task.isInProgress) {
        _startPolling(arg);
      }
      return task;
    });
  }
}

final taskReportProvider =
    AutoDisposeFutureProviderFamily<AnalysisReport?, String>((
      ref,
      taskId,
    ) async {
      final taskAsync = ref.watch(taskDetailProvider(taskId));
      final task = taskAsync.valueOrNull;
      if (task == null || !task.isCompleted) return null;
      final repo = ref.read(analysisRepositoryProvider);
      return repo.getReport(taskId);
    });

final detailSourceFilterProvider =
    AutoDisposeStateProviderFamily<String?, String>((ref, taskId) => null);

final taskAllPostsProvider =
    AutoDisposeFutureProviderFamily<List<SourcePost>, String>((
      ref,
      taskId,
    ) async {
      final repo = ref.read(feedRepositoryProvider);
      return repo.getPosts(taskId);
    });

final taskPostsProvider =
    AutoDisposeFutureProviderFamily<List<SourcePost>, String>((
      ref,
      taskId,
    ) async {
      final sourceFilter = ref.watch(detailSourceFilterProvider(taskId));
      final repo = ref.read(feedRepositoryProvider);
      return repo.getPosts(taskId, sourceFilter: sourceFilter);
    });
