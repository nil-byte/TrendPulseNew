import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/animations/staggered_list.dart';
import 'package:trendpulse/core/network/api_exception.dart';
import 'package:trendpulse/core/theme/app_borders.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_motion.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_typography.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/presentation/providers/analysis_provider.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  static const _noAvailableSourcesDetail =
      'no requested sources are currently available';
  static const _defaultSources = {'reddit', 'youtube', 'x'};
  final _keywordController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _configExpanded = false;
  bool _isSearching = false;
  bool _sourcesHydrated = false;
  bool _hasCustomSourceSelection = false;

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
      final reportLanguage = ref.read(defaultLanguageProvider);
      final task = await repo.createTask(
        keyword: keyword,
        contentLanguage: _contentLanguage,
        reportLanguage: reportLanguage,
        maxItems: _maxItems.round(),
        sources: effectiveSources.toList(),
      );

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
    if (error.statusCode != 422) {
      return false;
    }
    final detail = error.debugMessage?.toLowerCase().trim();
    return detail?.contains(_noAvailableSourcesDetail) ?? false;
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final sourceAvailabilityAsync = ref.watch(sourceAvailabilityProvider);
    ref.watch(defaultLanguageProvider);
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
                      StaggeredListItem(
                        index: 0,
                        child: Column(
                          children: [
                            Text(
                              l10n.analysisMastheadTop.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                letterSpacing: 4.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                l10n.appTitle.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.displayLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -2.0,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              l10n.analysisMastheadSubtitle.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 2.0,
                              ),
                            ),
                            EditorialDivider.doubleLine(
                              topSpace: AppSpacing.xl,
                              bottomSpace: AppSpacing.xl,
                            ),
                          ],
                        ),
                      ),
                      StaggeredListItem(
                        index: 1,
                        child: Text(
                          l10n.analysisIntro,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      StaggeredListItem(
                        index: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _EditorialSearchBar(
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
                            _ConfigPanel(
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
                              onMaxItemsChanged: (v) =>
                                  setState(() => _maxItems = v),
                            ),
                          ],
                        ),
                      ),
                      const EditorialDivider.thick(
                        topSpace: AppSpacing.xxl,
                        bottomSpace: AppSpacing.lg,
                      ),
                      StaggeredListItem(
                        index: 3,
                        child: _TrendingTopicsSection(onTopicTap: _fillSearchBar),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      const StaggeredListItem(
                        index: 4,
                        child: _PoweredByFooter(),
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

// ---------------------------------------------------------------------------
// Editorial Search Bar
// ---------------------------------------------------------------------------

class _EditorialSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final bool configExpanded;
  final String searchHint;
  final VoidCallback onSearch;
  final VoidCallback onToggleConfig;

  const _EditorialSearchBar({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.configExpanded,
    required this.searchHint,
    required this.onSearch,
    required this.onToggleConfig,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.onSurface, width: AppBorders.thick),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: theme.textTheme.displayLarge?.fontFamily,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: theme.textTheme.displayLarge?.fontFamily,
                  color: colors.onSurface.withValues(alpha: AppOpacity.divider),
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
          Container(
            width: AppBorders.thick,
            height: 56.0,
            color: colors.onSurface,
          ),
          IconButton(
            onPressed: onToggleConfig,
            icon: Icon(
              configExpanded ? Icons.close : Icons.tune_rounded,
              color: colors.onSurface,
            ),
            style: IconButton.styleFrom(
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
          ),
          Container(
            width: AppBorders.thick,
            height: 56.0,
            color: colors.onSurface,
          ),
          Semantics(
            button: true,
            child: InkWell(
              onTap: isSearching ? null : onSearch,
              child: Container(
                width: 56,
                height: 56.0,
                color: colors.primary,
                alignment: Alignment.center,
                child: isSearching
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : Icon(
                        Icons.arrow_forward_rounded,
                        color: colors.onPrimary,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Config Panel
// ---------------------------------------------------------------------------

class _ConfigPanel extends StatelessWidget {
  final bool expanded;
  final String contentLanguage;
  final Set<String> sources;
  final List<AnalysisSourceAvailability> sourceAvailability;
  final double maxItems;
  final ValueChanged<String> onContentLanguageChanged;
  final ValueChanged<Set<String>> onSourcesChanged;
  final ValueChanged<double> onMaxItemsChanged;

  const _ConfigPanel({
    required this.expanded,
    required this.contentLanguage,
    required this.sources,
    required this.sourceAvailability,
    required this.maxItems,
    required this.onContentLanguageChanged,
    required this.onSourcesChanged,
    required this.onMaxItemsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.slow,
      curve: AppMotion.emphasized,
      alignment: Alignment.topCenter,
      child: expanded ? _buildPanel(context) : const SizedBox.shrink(),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colors = theme.colorScheme;
    final availabilityBySource = {
      for (final item in sourceAvailability) item.source: item,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colors.onSurface, width: AppBorders.thick),
          right: BorderSide(color: colors.onSurface, width: AppBorders.thick),
          bottom: BorderSide(color: colors.onSurface, width: AppBorders.thick),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.analysisParametersTitle.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const EditorialDivider(topSpace: AppSpacing.xs, bottomSpace: AppSpacing.md),
          
          // Content language
          Text(
            l10n.contentLanguageLabel.toUpperCase(),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
              ButtonSegment(value: 'zh', label: Text(l10n.languageChinese)),
            ],
            selected: {contentLanguage},
            onSelectionChanged: (v) => onContentLanguageChanged(v.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Data Sources
          Text(
            l10n.dataSources.toUpperCase(),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Builder(builder: (context) {
            final tpColors = Theme.of(context).trendPulseColors;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _SourceChip(
                  label: l10n.platformReddit,
                  color: tpColors.reddit,
                  selected: sources.contains('reddit'),
                  status: availabilityBySource['reddit']?.status ?? 'available',
                  reason: availabilityBySource['reddit']?.reason,
                  enabled: availabilityBySource['reddit']?.isAvailable ?? true,
                  onSelected: (v) => _toggleSource('reddit', v),
                ),
                _SourceChip(
                  label: l10n.platformYouTube,
                  color: tpColors.youtube,
                  selected: sources.contains('youtube'),
                  status: availabilityBySource['youtube']?.status ?? 'available',
                  reason: availabilityBySource['youtube']?.reason,
                  enabled: availabilityBySource['youtube']?.isAvailable ?? true,
                  onSelected: (v) => _toggleSource('youtube', v),
                ),
                _SourceChip(
                  label: l10n.platformX,
                  color: tpColors.xPlatform,
                  selected: sources.contains('x'),
                  status: availabilityBySource['x']?.status ?? 'available',
                  reason: availabilityBySource['x']?.reason,
                  enabled: availabilityBySource['x']?.isAvailable ?? true,
                  onSelected: (v) => _toggleSource('x', v),
                ),
              ],
            );
          }),
          if (sourceAvailability.any((item) => item.reason?.trim().isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.analysisSourceStatusHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.72),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ...sourceAvailability
                      .where((item) => item.reason?.trim().isNotEmpty ?? false)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text(
                            '${_sourceLabel(item.source, l10n)} · ${_statusLabel(item, l10n)} · ${item.reason}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: item.isAvailable
                                  ? colors.onSurface.withValues(alpha: 0.72)
                                  : colors.error,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Max Items
          Row(
            children: [
              Text(
                l10n.analysisMaxItemsPerSource.toUpperCase(),
                style: theme.textTheme.labelSmall,
              ),
              const Spacer(),
              Text(
                maxItems.round().toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: AppTypography.editorialSansFamily,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.analysisPerSourceLimitHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.72),
              fontStyle: FontStyle.italic,
            ),
          ),
          Slider(
            value: maxItems,
            min: 10,
            max: 100,
            divisions: 9,
            onChanged: onMaxItemsChanged,
          ),
        ],
      ),
    );
  }

  void _toggleSource(String source, bool selected) {
    final next = Set<String>.from(sources);
    if (selected) {
      next.add(source);
    } else if (next.length > 1) {
      next.remove(source);
    }
    onSourcesChanged(next);
  }

  String _sourceLabel(String source, AppLocalizations l10n) {
    switch (source) {
      case 'reddit':
        return l10n.platformReddit;
      case 'youtube':
        return l10n.platformYouTube;
      case 'x':
        return l10n.platformX;
      default:
        return source;
    }
  }

  String _statusLabel(
    AnalysisSourceAvailability availability,
    AppLocalizations l10n,
  ) {
    switch (availability.status) {
      case 'degraded':
        return l10n.analysisSourceDegradedLabel;
      case 'unconfigured':
        return l10n.analysisSourceUnavailableLabel;
      default:
        return availability.status;
    }
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final String status;
  final bool enabled;
  final String? reason;
  final ValueChanged<bool>? onSelected;

  const _SourceChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.status,
    required this.enabled,
    this.reason,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tooltipMessage = reason?.trim();
    final chip = FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'degraded') ...[
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: selected
                  ? AppColors.onBrandFill(color)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: enabled ? onSelected : null,
      showCheckmark: false,
      selectedColor: color,
      labelStyle: (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
        color: selected
            ? AppColors.onBrandFill(color)
            : theme.colorScheme.onSurface.withValues(alpha: enabled ? 1.0 : 0.48),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      side: BorderSide(
        color: selected ? color : theme.colorScheme.outline,
        width: selected ? 1.2 : 1.0,
      ),
    );
    if (tooltipMessage == null || tooltipMessage.isEmpty) {
      return chip;
    }
    return Tooltip(message: tooltipMessage, child: chip);
  }
}

// ---------------------------------------------------------------------------
// Trending Topics
// ---------------------------------------------------------------------------

class _TrendingTopicsSection extends StatelessWidget {
  final ValueChanged<String> onTopicTap;

  const _TrendingTopicsSection({required this.onTopicTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final topics = [
      l10n.analysisStarterTopicAi,
      l10n.analysisStarterTopicCrypto,
      l10n.analysisStarterTopicEv,
      l10n.analysisStarterTopicMarkets,
      l10n.analysisStarterTopicLayoffs,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.analysisStarterTopicsTitle.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const EditorialDivider(topSpace: AppSpacing.xs, bottomSpace: AppSpacing.md),
        Text(
          l10n.analysisStarterTopicsDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(
              alpha: AppOpacity.secondaryStrong,
            ),
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...List.generate(topics.length, (index) {
          final topic = topics[index];
          return InkWell(
            onTap: () => onTopicTap(topic),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      topic,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: theme.textTheme.displayLarge?.fontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          );
        }),
        const EditorialDivider(topSpace: AppSpacing.sm, bottomSpace: 0),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

class _PoweredByFooter extends StatelessWidget {
  const _PoweredByFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final style = theme.textTheme.labelSmall?.copyWith(
      letterSpacing: 1.0,
      fontWeight: FontWeight.w700,
    );

    return Column(
      children: [
        Text(l10n.analysisDataSourcesTitle.toUpperCase(), style: style),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.analysisDataSourcesList.toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }
}
