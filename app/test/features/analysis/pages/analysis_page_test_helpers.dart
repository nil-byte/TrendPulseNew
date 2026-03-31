import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trendpulse/core/network/api_exception.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/data/analysis_repository.dart';
import 'package:trendpulse/features/analysis/presentation/providers/analysis_provider.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class FakeAnalysisRepository extends AnalysisRepository {
  FakeAnalysisRepository({
    required this.sourceAvailability,
    this.refreshedSourceAvailability,
    this.sourceAvailabilityExceptionOnRefresh,
    this.createTaskException,
  });

  final List<AnalysisSourceAvailability> sourceAvailability;
  final List<AnalysisSourceAvailability>? refreshedSourceAvailability;
  final Object? sourceAvailabilityExceptionOnRefresh;
  final ApiException? createTaskException;
  int sourceAvailabilityCallCount = 0;
  String? lastCreateTaskContentLanguage;
  String? lastCreateTaskReportLanguage;
  List<String>? lastCreateTaskSources;

  @override
  Future<List<AnalysisSourceAvailability>> getSourceAvailability() async {
    sourceAvailabilityCallCount += 1;
    if (sourceAvailabilityCallCount > 1 &&
        sourceAvailabilityExceptionOnRefresh != null) {
      throw sourceAvailabilityExceptionOnRefresh!;
    }
    if (sourceAvailabilityCallCount > 1 && refreshedSourceAvailability != null) {
      return refreshedSourceAvailability!;
    }
    return sourceAvailability;
  }

  @override
  Future<AnalysisTask> createTask({
    required String keyword,
    String contentLanguage = 'en',
    required String reportLanguage,
    int maxItems = 50,
    List<String> sources = const ['reddit', 'youtube', 'x'],
  }) async {
    lastCreateTaskContentLanguage = contentLanguage;
    lastCreateTaskReportLanguage = reportLanguage;
    lastCreateTaskSources = List<String>.from(sources);
    if (createTaskException != null) {
      throw createTaskException!;
    }
    return const AnalysisTask(
      id: 'task-1',
      keyword: 'ai',
      contentLanguage: 'en',
      reportLanguage: 'zh',
      maxItems: 50,
      status: 'pending',
      sources: ['reddit'],
      createdAt: '2026-03-30T00:00:00Z',
      updatedAt: '2026-03-30T00:00:00Z',
    );
  }
}

class DelayedSourceAvailabilityRepository extends AnalysisRepository {
  final Completer<List<AnalysisSourceAvailability>> sourceAvailabilityCompleter =
      Completer<List<AnalysisSourceAvailability>>();

  @override
  Future<List<AnalysisSourceAvailability>> getSourceAvailability() {
    return sourceAvailabilityCompleter.future;
  }

  @override
  Future<AnalysisTask> createTask({
    required String keyword,
    String contentLanguage = 'en',
    required String reportLanguage,
    int maxItems = 50,
    List<String> sources = const ['reddit', 'youtube', 'x'],
  }) async {
    return const AnalysisTask(
      id: 'task-1',
      keyword: 'ai',
      contentLanguage: 'en',
      reportLanguage: 'zh',
      maxItems: 50,
      status: 'pending',
      sources: ['reddit'],
      createdAt: '2026-03-30T00:00:00Z',
      updatedAt: '2026-03-30T00:00:00Z',
    );
  }
}

class FakeSettingsRepository extends SettingsRepository {
  FakeSettingsRepository({required this.language});

  final String language;

  @override
  Future<String> getLanguage() async => language;

  @override
  Future<String> getReportLanguage({String? baseUrl}) async => language;

  @override
  Future<String> setReportLanguage(String language, {String? baseUrl}) async =>
      language;
}

Widget wrapAnalysisPage(
  Widget child, {
  ThemeData? theme,
  AnalysisRepository? analysisRepository,
  SettingsRepository? settingsRepository,
}) {
  return ProviderScope(
    overrides: [
      analysisRepositoryProvider.overrideWithValue(
        analysisRepository ??
            FakeAnalysisRepository(
              sourceAvailability: const [
                AnalysisSourceAvailability(
                  source: 'reddit',
                  status: 'available',
                  isAvailable: true,
                ),
                AnalysisSourceAvailability(
                  source: 'youtube',
                  status: 'available',
                  isAvailable: true,
                ),
                AnalysisSourceAvailability(
                  source: 'x',
                  status: 'available',
                  isAvailable: true,
                ),
              ],
            ),
      ),
      settingsRepositoryProvider.overrideWithValue(
        settingsRepository ?? FakeSettingsRepository(language: 'en'),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: theme ?? AppTheme.light,
      home: child,
    ),
  );
}
