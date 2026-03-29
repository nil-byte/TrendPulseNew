import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/animations/staggered_list.dart';
import 'package:trendpulse/core/theme/app_borders.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_motion.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/features/analysis/presentation/providers/analysis_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  final _keywordController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _configExpanded = false;
  bool _isSearching = false;

  String _language = 'en';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.analysisKeywordRequiredMessage)),
      );
      return;
    }
    if (_isSearching) return;

    setState(() => _isSearching = true);

    try {
      final repo = ref.read(analysisRepositoryProvider);
      final task = await repo.createTask(
        keyword: keyword,
        language: _language,
        maxItems: _maxItems.round(),
        sources: _sources.toList(),
      );

      if (mounted) {
        context.push('/detail/${task.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.analysisCreateTaskError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _fillSearchBar(String keyword) {
    _keywordController.text = keyword;
    _searchFocusNode.requestFocus();
    _keywordController.selection = TextSelection.fromPosition(
      TextPosition(offset: keyword.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

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
                              language: _language,
                              sources: _sources,
                              maxItems: _maxItems,
                              onLanguageChanged: (v) =>
                                  setState(() => _language = v),
                              onSourcesChanged: (v) =>
                                  setState(() => _sources = v),
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
  final String language;
  final Set<String> sources;
  final double maxItems;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<Set<String>> onSourcesChanged;
  final ValueChanged<double> onMaxItemsChanged;

  const _ConfigPanel({
    required this.expanded,
    required this.language,
    required this.sources,
    required this.maxItems,
    required this.onLanguageChanged,
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
          
          // Language
          Text(
            l10n.language.toUpperCase(),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
              ButtonSegment(value: 'zh', label: Text(l10n.languageChinese)),
            ],
            selected: {language},
            onSelectionChanged: (v) => onLanguageChanged(v.first),
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
                  onSelected: (v) => _toggleSource('reddit', v),
                ),
                _SourceChip(
                  label: l10n.platformYouTube,
                  color: tpColors.youtube,
                  selected: sources.contains('youtube'),
                  onSelected: (v) => _toggleSource('youtube', v),
                ),
                _SourceChip(
                  label: l10n.platformX,
                  color: tpColors.xPlatform,
                  selected: sources.contains('x'),
                  onSelected: (v) => _toggleSource('x', v),
                ),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.lg),

          // Max Items
          Row(
            children: [
              Text(
                l10n.maxItems.toUpperCase(),
                style: theme.textTheme.labelSmall,
              ),
              const Spacer(),
              Text(
                maxItems.round().toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: theme.textTheme.displayLarge?.fontFamily,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
}

class _SourceChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _SourceChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: color,
      labelStyle: (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
        color: selected
            ? AppColors.onBrandFill(color)
            : theme.colorScheme.onSurface,
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
