import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/animations/staggered_list.dart';
import 'package:trendpulse/core/network/api_exception.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/app_providers.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/presentation/providers/analysis_provider.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/analysis_config_panel.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/analysis_editorial_search_bar.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/analysis_marketing_sections.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  static const _noAvailableSourcesCode = 'no_available_sources';
  static const _defaultSources = {'reddit', 'youtube', 'x'};
  final _keywordController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _configExpanded = false;
  bool _isSearching = false;
  bool _sourcesHydrated = false;
  bool _maxItemsHydrated = false;
  bool _hasCustomSourceSelection = false;
  bool _hasCustomMaxItemsSelection = false;

  String _contentLanguage = 'en';
  Set<String> _sources = {'reddit', 'youtube', 'x'};
  double _maxItems = 50;

  @override
  void dispose() {
    _keywordController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    final l10n = AppLocalizations.of(context)!;
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      _showMessage(l10n.analysisKeywordRequiredMessage);
      return;
    }
    if (_isSearching) return;

    setState(() => _isSearching = true);

    try {
      var effectiveSources = Set<String>.from(_sources);
      var sourceAvailabilityRefreshFailed = false;
      try {
        final sourceAvailability = await ref.refresh(
          sourceAvailabilityProvider.future,
        );
        final availableSources = sourceAvailability
            .where((source) => source.isAvailable)
            .map((source) => source.source)
            .toSet();
        effectiveSources = _resolveEffectiveSources(
          currentSelection: effectiveSources,
          availableSources: availableSources,
          followAvailableSources: !_hasCustomSourceSelection,
        );
        if (!setEquals(effectiveSources, _sources) && mounted) {
          setState(() => _sources = effectiveSources);
        }
      } catch (_) {
        sourceAvailabilityRefreshFailed = true;
        // Backend task creation performs the authoritative availability check.
      }

      if (effectiveSources.isEmpty &&
          sourceAvailabilityRefreshFailed &&
          !_hasCustomSourceSelection) {
        effectiveSources = Set<String>.from(_defaultSources);
      }

      if (effectiveSources.isEmpty) {
        if (mounted) {
          _showMessage(l10n.analysisNoAvailableSourcesMessage);
        }
        return;
      }

      final repo = ref.read(analysisRepositoryProvider);
      final reportLanguage = ref.read(defaultReportLanguageProvider);
      final task = await repo.createTask(
        keyword: keyword,
        contentLanguage: _contentLanguage,
        reportLanguage: reportLanguage,
        maxItems: _maxItems.round(),
        sources: effectiveSources.toList(),
      );

      ref.read(taskMutationSignalProvider.notifier).state++;

      if (mounted) {
        context.push('/detail/${task.id}');
      }
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(
          _isNoAvailableSourcesError(e)
              ? l10n.analysisNoAvailableSourcesMessage
              : l10n.analysisCreateTaskError,
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage(l10n.analysisCreateTaskError);
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _synchronizeSources(List<AnalysisSourceAvailability> availability) {
    final availableSources = availability
        .where((source) => source.isAvailable)
        .map((source) => source.source)
        .toSet();
    final nextSources = _sourcesHydrated
        ? _resolveEffectiveSources(
            currentSelection: _sources,
            availableSources: availableSources,
            followAvailableSources: !_hasCustomSourceSelection,
          )
        : _hasCustomSourceSelection
        ? _resolveEffectiveSources(
            currentSelection: _sources,
            availableSources: availableSources,
            followAvailableSources: false,
          )
        : availableSources;
    _sourcesHydrated = true;
    if (setEquals(nextSources, _sources)) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _sources = nextSources);
  }

  void _fillSearchBar(String keyword) {
    _keywordController.text = keyword;
    _searchFocusNode.requestFocus();
    _keywordController.selection = TextSelection.fromPosition(
      TextPosition(offset: keyword.length),
    );
  }

  bool _isNoAvailableSourcesError(ApiException error) {
    return error.statusCode == 422 && error.errorCode == _noAvailableSourcesCode;
  }

  Set<String> _resolveEffectiveSources({
    required Set<String> currentSelection,
    required Set<String> availableSources,
    required bool followAvailableSources,
  }) {
    if (followAvailableSources) {
      return Set<String>.from(availableSources);
    }
    return currentSelection.intersection(availableSources);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sourceAvailabilityAsync = ref.watch(sourceAvailabilityProvider);
    final defaultMaxItems = ref.watch(defaultMaxItemsProvider);
    ref.watch(defaultReportLanguageProvider);
    if (!_maxItemsHydrated) {
      _maxItems = defaultMaxItems.toDouble();
      _maxItemsHydrated = true;
    }
    ref.listen<int>(defaultMaxItemsProvider, (_, next) {
      if (_hasCustomMaxItemsSelection || !mounted) {
        return;
      }
      final nextMaxItems = next.toDouble();
      if (nextMaxItems == _maxItems) {
        return;
      }
      setState(() {
        _maxItems = nextMaxItems;
        _maxItemsHydrated = true;
      });
    });
    ref.listen<AsyncValue<List<AnalysisSourceAvailability>>>(
      sourceAvailabilityProvider,
      (_, next) {
        final availability = next.valueOrNull;
        if (availability != null) {
          _synchronizeSources(availability);
        }
      },
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const StaggeredListItem(
                        index: 0,
                        child: AnalysisMastheadSection(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      StaggeredListItem(
                        index: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnalysisEditorialSearchBar(
                              controller: _keywordController,
                              focusNode: _searchFocusNode,
                              isSearching: _isSearching,
                              configExpanded: _configExpanded,
                              searchHint: l10n.analysisSearchHintEditorial,
                              onSearch: _onSearch,
                              onToggleConfig: () {
                                setState(
                                  () => _configExpanded = !_configExpanded,
                                );
                              },
                            ),
                            if (sourceAvailabilityAsync.hasError)
                              _SourceAvailabilityError(
                                onRetry: () =>
                                    ref.invalidate(sourceAvailabilityProvider),
                              ),
                            AnalysisConfigPanel(
                              expanded: _configExpanded,
                              contentLanguage: _contentLanguage,
                              sources: _sources,
                              sourceAvailability:
                                  sourceAvailabilityAsync.valueOrNull ?? const [],
                              maxItems: _maxItems,
                              onContentLanguageChanged: (v) =>
                                  setState(() => _contentLanguage = v),
                              onSourcesChanged: (v) => setState(() {
                                _sources = v;
                                _hasCustomSourceSelection = true;
                              }),
                              onMaxItemsChanged: (v) => setState(() {
                                _maxItems = v;
                                _hasCustomMaxItemsSelection = true;
                              }),
                            ),
                          ],
                        ),
                      ),
                      const EditorialDivider.thick(
                        topSpace: AppSpacing.xxl,
                        bottomSpace: AppSpacing.lg,
                      ),
                      StaggeredListItem(
                        index: 2,
                        child: AnalysisTrendingTopicsSection(
                          onTopicTap: _fillSearchBar,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      const StaggeredListItem(
                        index: 3,
                        child: AnalysisPoweredByFooter(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SourceAvailabilityError extends StatelessWidget {
  final VoidCallback onRetry;

  const _SourceAvailabilityError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tpColors = theme.trendPulseColors;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: tpColors.negative, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: tpColors.negative),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n.errorSourceAvailabilityMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          InkWell(
            onTap: onRetry,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                Icons.refresh_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
