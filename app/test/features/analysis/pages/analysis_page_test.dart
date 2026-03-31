import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/network/api_exception.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/data/analysis_repository.dart';
import 'package:trendpulse/features/analysis/presentation/pages/analysis_page.dart';
import 'package:trendpulse/features/analysis/presentation/providers/analysis_provider.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class _FakeAnalysisRepository extends AnalysisRepository {
  _FakeAnalysisRepository({
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

class _DelayedSourceAvailabilityRepository extends AnalysisRepository {
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

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository({required this.language});

  final String language;

  @override
  Future<String> getLanguage() async => language;

  @override
  Future<String> getReportLanguage({String? baseUrl}) async => language;

  @override
  Future<String> setReportLanguage(String language, {String? baseUrl}) async =>
      language;
}

Widget _wrap(
  Widget child, {
  ThemeData? theme,
  AnalysisRepository? analysisRepository,
  SettingsRepository? settingsRepository,
}) {
  return ProviderScope(
    overrides: [
      analysisRepositoryProvider.overrideWithValue(
        analysisRepository ??
            _FakeAnalysisRepository(
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
        settingsRepository ?? _FakeSettingsRepository(language: 'en'),
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

void main() {
  testWidgets('shows guidance when search is tapped without a keyword', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AnalysisPage()));

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Enter a topic before starting analysis.'), findsOneWidget);
  });

  testWidgets(
    'analysis X source chip uses a readable dark foreground in dark theme',
    (tester) async {
      await tester.pumpWidget(_wrap(const AnalysisPage(), theme: AppTheme.dark));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded).first);
      await tester.pumpAndSettle();

      final xChip = tester.widgetList<FilterChip>(find.byType(FilterChip)).last;

      expect(xChip.selected, isTrue);
      expect(xChip.labelStyle?.color, AppColors.lightInk);
    },
  );

  testWidgets(
    'analysis source chips keep accessible tap targets and toggle semantics',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(_wrap(const AnalysisPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded).first);
      await tester.pumpAndSettle();

      final redditChip = find.widgetWithText(FilterChip, 'Reddit');
      expect(redditChip, findsOneWidget);
      expect(tester.getSize(redditChip).height, greaterThanOrEqualTo(48));

      expect(
        tester.getSemantics(redditChip),
        matchesSemantics(
          label: 'Reddit',
          hasTapAction: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          isButton: true,
          isFocusable: true,
        ),
      );

      semanticsHandle.dispose();
    },
  );

  testWidgets('analysis page deselects and disables unavailable sources', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AnalysisPage(),
        analysisRepository: _FakeAnalysisRepository(
          sourceAvailability: const [
            AnalysisSourceAvailability(
              source: 'reddit',
              status: 'unconfigured',
              isAvailable: false,
            ),
            AnalysisSourceAvailability(
              source: 'youtube',
              status: 'available',
              isAvailable: true,
            ),
            AnalysisSourceAvailability(
              source: 'x',
              status: 'unconfigured',
              isAvailable: false,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await tester.pumpAndSettle();

    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
    final redditChip = chips[0];
    final youtubeChip = chips[1];
    final xChip = chips[2];

    expect(redditChip.selected, isFalse);
    expect(redditChip.onSelected, isNull);
    expect(youtubeChip.selected, isTrue);
    expect(youtubeChip.onSelected, isNotNull);
    expect(xChip.selected, isFalse);
    expect(xChip.onSelected, isNull);
  });

  testWidgets('analysis page keeps degraded sources selectable', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AnalysisPage(),
        analysisRepository: _FakeAnalysisRepository(
          sourceAvailability: const [
            AnalysisSourceAvailability(
              source: 'reddit',
              status: 'degraded',
              isAvailable: true,
              reason: 'Reddit connection failed on last run.',
              reasonCode: 'reddit_network_unreachable',
              checkedAt: '2026-03-30T00:00:00Z',
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
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded).first);
    await tester.pumpAndSettle();

    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
    final redditChip = chips[0];

    expect(redditChip.selected, isTrue);
    expect(redditChip.onSelected, isNotNull);
  });

  testWidgets(
    'analysis search sends form content language and app report language separately',
    (tester) async {
      final repo = _FakeAnalysisRepository(
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
      );
      await tester.pumpWidget(
        _wrap(
          const AnalysisPage(),
          analysisRepository: repo,
          settingsRepository: _FakeSettingsRepository(language: 'zh'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(repo.lastCreateTaskContentLanguage, 'en');
      expect(repo.lastCreateTaskReportLanguage, 'zh');
    },
  );

  testWidgets(
    'analysis search rehydrates sources when availability recovers from an empty selection',
    (tester) async {
      final repo = _FakeAnalysisRepository(
        sourceAvailability: const [
          AnalysisSourceAvailability(
            source: 'reddit',
            status: 'unconfigured',
            isAvailable: false,
          ),
          AnalysisSourceAvailability(
            source: 'youtube',
            status: 'unconfigured',
            isAvailable: false,
          ),
          AnalysisSourceAvailability(
            source: 'x',
            status: 'unconfigured',
            isAvailable: false,
          ),
        ],
        refreshedSourceAvailability: const [
          AnalysisSourceAvailability(
            source: 'reddit',
            status: 'unconfigured',
            isAvailable: false,
          ),
          AnalysisSourceAvailability(
            source: 'youtube',
            status: 'available',
            isAvailable: true,
          ),
          AnalysisSourceAvailability(
            source: 'x',
            status: 'unconfigured',
            isAvailable: false,
          ),
        ],
        createTaskException: const ApiException(message: 'request failed', statusCode: 500),
      );
      await tester.pumpWidget(_wrap(const AnalysisPage(), analysisRepository: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(repo.sourceAvailabilityCallCount, 2);
      expect(repo.lastCreateTaskSources, ['youtube']);
    },
  );

  testWidgets(
    'analysis search falls back to refreshed sources when auto-selected sources become stale',
    (tester) async {
      final repo = _FakeAnalysisRepository(
        sourceAvailability: const [
          AnalysisSourceAvailability(
            source: 'reddit',
            status: 'available',
            isAvailable: true,
          ),
          AnalysisSourceAvailability(
            source: 'youtube',
            status: 'unconfigured',
            isAvailable: false,
          ),
          AnalysisSourceAvailability(
            source: 'x',
            status: 'unconfigured',
            isAvailable: false,
          ),
        ],
        refreshedSourceAvailability: const [
          AnalysisSourceAvailability(
            source: 'reddit',
            status: 'unconfigured',
            isAvailable: false,
          ),
          AnalysisSourceAvailability(
            source: 'youtube',
            status: 'available',
            isAvailable: true,
          ),
          AnalysisSourceAvailability(
            source: 'x',
            status: 'unconfigured',
            isAvailable: false,
          ),
        ],
        createTaskException: const ApiException(message: 'request failed', statusCode: 500),
      );
      await tester.pumpWidget(_wrap(const AnalysisPage(), analysisRepository: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(repo.sourceAvailabilityCallCount, 2);
      expect(repo.lastCreateTaskSources, ['youtube']);
    },
  );

  testWidgets(
    'analysis search re-expands recovered sources when selection was never customized',
    (tester) async {
      final repo = _FakeAnalysisRepository(
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
            status: 'unconfigured',
            isAvailable: false,
          ),
        ],
        refreshedSourceAvailability: const [
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
        createTaskException: const ApiException(message: 'request failed', statusCode: 500),
      );
      await tester.pumpWidget(_wrap(const AnalysisPage(), analysisRepository: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(repo.sourceAvailabilityCallCount, 2);
      expect(repo.lastCreateTaskSources, ['reddit', 'youtube', 'x']);
    },
  );

  testWidgets(
    'initial source hydration does not overwrite a user selection made while loading',
    (tester) async {
      final repo = _DelayedSourceAvailabilityRepository();
      await tester.pumpWidget(_wrap(const AnalysisPage(), analysisRepository: repo));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.tune_rounded).first);
      await tester.pumpAndSettle();

      final youtubeChip = find.byType(FilterChip).at(1);
      final xChip = find.byType(FilterChip).at(2);

      await tester.ensureVisible(youtubeChip);
      await tester.tap(youtubeChip);
      await tester.pumpAndSettle();
      await tester.ensureVisible(xChip);
      await tester.tap(xChip);
      await tester.pumpAndSettle();

      repo.sourceAvailabilityCompleter.complete(const [
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
      ]);
      await tester.pumpAndSettle();

      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
      expect(chips[0].selected, isTrue);
      expect(chips[1].selected, isFalse);
      expect(chips[2].selected, isFalse);
    },
  );

  testWidgets(
    'analysis search refreshes source availability before creating a task',
    (tester) async {
      final repo = _FakeAnalysisRepository(
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
        refreshedSourceAvailability: const [
          AnalysisSourceAvailability(
            source: 'reddit',
            status: 'unconfigured',
            isAvailable: false,
          ),
          AnalysisSourceAvailability(
            source: 'youtube',
            status: 'available',
            isAvailable: true,
          ),
          AnalysisSourceAvailability(
            source: 'x',
            status: 'unconfigured',
            isAvailable: false,
          ),
        ],
        createTaskException: const ApiException(message: 'request failed', statusCode: 500),
      );
      await tester.pumpWidget(_wrap(const AnalysisPage(), analysisRepository: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(repo.sourceAvailabilityCallCount, 2);
      expect(repo.lastCreateTaskSources, ['youtube']);
    },
  );

  testWidgets(
    'analysis page only shows no-available-sources message for matching 422 errors',
    (tester) async {
      final repo = _FakeAnalysisRepository(
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
        createTaskException: const ApiException(
          message: '请求参数无效，请检查输入或稍后重试。',
          statusCode: 422,
          debugMessage: 'keyword validation failed',
        ),
      );
      await tester.pumpWidget(_wrap(const AnalysisPage(), analysisRepository: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to start this analysis right now. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'No data sources are currently available. Check source configuration or try again later.',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'analysis page shows no-available-sources message for matching 422 errors',
    (tester) async {
      final repo = _FakeAnalysisRepository(
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
        createTaskException: const ApiException(
          message: '请求参数无效，请检查输入或稍后重试。',
          statusCode: 422,
          debugMessage:
              'No requested sources are currently available. Unavailable sources: reddit (missing credentials).',
        ),
      );
      await tester.pumpWidget(_wrap(const AnalysisPage(), analysisRepository: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No data sources are currently available. Check source configuration or try again later.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Unable to start this analysis right now. Please try again.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'analysis search falls back to createTask when source refresh fails after local sources became empty',
    (tester) async {
      final repo = _FakeAnalysisRepository(
        sourceAvailability: const [
          AnalysisSourceAvailability(
            source: 'reddit',
            status: 'unconfigured',
            isAvailable: false,
          ),
          AnalysisSourceAvailability(
            source: 'youtube',
            status: 'unconfigured',
            isAvailable: false,
          ),
          AnalysisSourceAvailability(
            source: 'x',
            status: 'unconfigured',
            isAvailable: false,
          ),
        ],
        sourceAvailabilityExceptionOnRefresh: Exception('temporary source check failure'),
        createTaskException: const ApiException(message: 'request failed', statusCode: 500),
      );
      await tester.pumpWidget(_wrap(const AnalysisPage(), analysisRepository: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'openai');
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
      await tester.pumpAndSettle();

      expect(repo.sourceAvailabilityCallCount, 2);
      expect(repo.lastCreateTaskSources, ['reddit', 'youtube', 'x']);
      expect(
        find.text(
          'No data sources are currently available. Check source configuration or try again later.',
        ),
        findsNothing,
      );
    },
  );
}
