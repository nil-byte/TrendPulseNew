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
  bool _disposed = false;
  int _pollGeneration = 0;

  @override
  Future<AnalysisTask> build(String arg) async {
    ref.onDispose(() {
      _disposed = true;
      _pollGeneration++;
      _pollTimer?.cancel();
    });
    final repo = ref.read(analysisRepositoryProvider);
    final task = await repo.getTaskStatus(arg);
    if (_disposed) {
      return task;
    }
    if (task.isInProgress) {
      _startPolling(arg);
    }
    return task;
  }

  void _startPolling(String taskId) {
    _pollTimer?.cancel();
    final generation = ++_pollGeneration;
    _scheduleNextPoll(taskId, generation);
  }

  void _scheduleNextPoll(String taskId, int generation) {
    _pollTimer = Timer(const Duration(seconds: 3), () async {
      _pollTimer = null;
      if (_disposed || generation != _pollGeneration) {
        return;
      }
      try {
        final repo = ref.read(analysisRepositoryProvider);
        final task = await repo.getTaskStatus(taskId);
        if (_disposed || generation != _pollGeneration) {
          return;
        }
        state = AsyncData(task);
        if (!task.isInProgress) {
          return;
        }
        _scheduleNextPoll(taskId, generation);
      } catch (e, st) {
        if (_disposed || generation != _pollGeneration) {
          return;
        }
        state = AsyncError(e, st);
      }
    });
  }

  Future<void> refresh() async {
    _pollTimer?.cancel();
    _pollGeneration++;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(analysisRepositoryProvider);
      final task = await repo.getTaskStatus(arg);
      if (_disposed) {
        return task;
      }
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
      if (task == null || !task.canViewReport) return null;
      final repo = ref.read(analysisRepositoryProvider);
      return repo.getReport(taskId);
    });

final taskPostsRefreshVersionProvider =
    AutoDisposeNotifierProviderFamily<
      TaskPostsRefreshVersionNotifier,
      int,
      String
    >(TaskPostsRefreshVersionNotifier.new);

class TaskPostsRefreshVersionNotifier
    extends AutoDisposeFamilyNotifier<int, String> {
  bool _hasSeenInitialTaskSnapshot = false;

  @override
  int build(String arg) {
    ref.listen<AsyncValue<AnalysisTask>>(taskDetailProvider(arg), (
      previous,
      next,
    ) {
      final nextTask = next.valueOrNull;
      if (nextTask == null) {
        return;
      }

      if (!_hasSeenInitialTaskSnapshot) {
        _hasSeenInitialTaskSnapshot = true;
        return;
      }

      final previousTask = previous?.valueOrNull;
      final shouldRefreshPosts =
          previousTask?.isInProgress == true || nextTask.isInProgress;
      if (shouldRefreshPosts) {
        state++;
      }
    }, fireImmediately: true);

    return 0;
  }
}

final detailSourceFilterProvider =
    AutoDisposeStateProviderFamily<String?, String>((ref, taskId) => null);

final taskAllPostsProvider =
    AutoDisposeFutureProviderFamily<List<SourcePost>, String>((
      ref,
      taskId,
    ) async {
      ref.watch(taskPostsRefreshVersionProvider(taskId));
      final repo = ref.read(feedRepositoryProvider);
      return repo.getPosts(taskId);
    });

final taskPostsProvider =
    AutoDisposeFutureProviderFamily<List<SourcePost>, String>((
      ref,
      taskId,
    ) async {
      final sourceFilter = ref.watch(detailSourceFilterProvider(taskId));
      ref.watch(taskPostsRefreshVersionProvider(taskId));
      final repo = ref.read(feedRepositoryProvider);
      return repo.getPosts(taskId, sourceFilter: sourceFilter);
    });
