import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/data/analysis_repository.dart';

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  return AnalysisRepository();
});

final currentTaskProvider = StateProvider<AnalysisTask?>((ref) => null);

final analysisReportProvider = FutureProvider<AnalysisReport?>((ref) async {
  final task = ref.watch(currentTaskProvider);
  if (task == null || !task.isCompleted) return null;
  final repo = ref.read(analysisRepositoryProvider);
  return repo.getReport(task.id);
});

final analysisControllerProvider =
    StateNotifierProvider<AnalysisController, AnalysisState>((ref) {
  return AnalysisController(ref);
});

enum AnalysisStatus { idle, loading, polling, completed, failed }

class AnalysisState {
  final AnalysisStatus status;
  final String? errorMessage;
  final AnalysisReport? report;

  const AnalysisState({
    this.status = AnalysisStatus.idle,
    this.errorMessage,
    this.report,
  });

  AnalysisState copyWith({
    AnalysisStatus? status,
    String? errorMessage,
    AnalysisReport? report,
  }) {
    return AnalysisState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      report: report ?? this.report,
    );
  }
}

class AnalysisController extends StateNotifier<AnalysisState> {
  final Ref _ref;
  Timer? _pollTimer;

  AnalysisController(this._ref) : super(const AnalysisState());

  Future<void> createTask({
    required String keyword,
    String language = 'en',
    int maxItems = 50,
    List<String> sources = const ['reddit', 'youtube', 'x'],
  }) async {
    state = const AnalysisState(status: AnalysisStatus.loading);

    try {
      final repo = _ref.read(analysisRepositoryProvider);
      final task = await repo.createTask(
        keyword: keyword,
        language: language,
        maxItems: maxItems,
        sources: sources,
      );
      _ref.read(currentTaskProvider.notifier).state = task;
      state = state.copyWith(status: AnalysisStatus.polling);
      _startPolling(task.id);
    } catch (e) {
      state = AnalysisState(
        status: AnalysisStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  void _startPolling(String taskId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final repo = _ref.read(analysisRepositoryProvider);
        final task = await repo.getTaskStatus(taskId);
        _ref.read(currentTaskProvider.notifier).state = task;

        if (task.isCompleted) {
          _pollTimer?.cancel();
          final report = await repo.getReport(taskId);
          state = AnalysisState(
            status: AnalysisStatus.completed,
            report: report,
          );
        } else if (task.isFailed) {
          _pollTimer?.cancel();
          state = AnalysisState(
            status: AnalysisStatus.failed,
            errorMessage: task.errorMessage ?? 'Analysis failed',
          );
        }
      } catch (e) {
        _pollTimer?.cancel();
        state = AnalysisState(
          status: AnalysisStatus.failed,
          errorMessage: e.toString(),
        );
      }
    });
  }

  void reset() {
    _pollTimer?.cancel();
    _ref.read(currentTaskProvider.notifier).state = null;
    state = const AnalysisState();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
