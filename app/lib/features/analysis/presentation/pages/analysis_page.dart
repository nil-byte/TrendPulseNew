import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/animations/press_feedback.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
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
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty || _isSearching) return;

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
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.trending_up_rounded,
              color: theme.colorScheme.primary,
              size: 26,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.appTitle),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = (constraints.maxHeight * 0.12).clamp(24.0, 80.0);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              topPadding,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    _SearchBar(
                      controller: _keywordController,
                      focusNode: _searchFocusNode,
                      isSearching: _isSearching,
                      configExpanded: _configExpanded,
                      onSearch: _onSearch,
                      onToggleConfig: () {
                        setState(() => _configExpanded = !_configExpanded);
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _ConfigPanel(
                      expanded: _configExpanded,
                      language: _language,
                      sources: _sources,
                      maxItems: _maxItems,
                      onLanguageChanged: (v) => setState(() => _language = v),
                      onSourcesChanged: (v) => setState(() => _sources = v),
                      onMaxItemsChanged: (v) => setState(() => _maxItems = v),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _TrendingTopicsSection(onTopicTap: _fillSearchBar),
                    const SizedBox(height: AppSpacing.xxl + AppSpacing.lg),
                    const _PoweredByFooter(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search Bar
// ---------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final bool configExpanded;
  final VoidCallback onSearch;
  final VoidCallback onToggleConfig;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.configExpanded,
    required this.onSearch,
    required this.onToggleConfig,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXl),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXl),
        onTap: () => focusNode.requestFocus(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.md),
                child: Icon(
                  Icons.search_rounded,
                  color: colors.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSearch(),
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    isCollapsed: true,
                  ),
                ),
              ),
              _ConfigToggle(expanded: configExpanded, onTap: onToggleConfig),
              const SizedBox(width: AppSpacing.xs),
              _SearchButton(isSearching: isSearching, onTap: onSearch),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _ConfigToggle({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onTap,
      icon: AnimatedRotation(
        turns: expanded ? 0.5 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        child: Icon(
          Icons.tune_rounded,
          color: expanded ? colors.primary : colors.onSurfaceVariant,
          size: 20,
        ),
      ),
      style: IconButton.styleFrom(
        backgroundColor: expanded
            ? colors.primaryContainer.withValues(alpha: 0.5)
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        ),
      ),
      tooltip: AppLocalizations.of(context)!.configureSearch,
    );
  }
}

class _SearchButton extends StatelessWidget {
  final bool isSearching;
  final VoidCallback onTap;

  const _SearchButton({required this.isSearching, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return FilledButton(
      onPressed: isSearching ? null : onTap,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        ),
      ),
      child: isSearching
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.onPrimary,
              ),
            )
          : Text(l10n.searchButton),
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
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: expanded ? _buildPanel(context) : const SizedBox.shrink(),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language
            Text(
              l10n.language,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
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
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Data Sources
            Text(
              l10n.dataSources,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _SourceChip(
                  label: l10n.platformReddit,
                  icon: Icons.forum_rounded,
                  color: theme.trendPulseColors.reddit,
                  selected: sources.contains('reddit'),
                  onSelected: (v) => _toggleSource('reddit', v),
                ),
                _SourceChip(
                  label: l10n.platformYouTube,
                  icon: Icons.play_circle_rounded,
                  color: theme.trendPulseColors.youtube,
                  selected: sources.contains('youtube'),
                  onSelected: (v) => _toggleSource('youtube', v),
                ),
                _SourceChip(
                  label: l10n.platformX,
                  icon: Icons.tag_rounded,
                  color: theme.trendPulseColors.xPlatform,
                  selected: sources.contains('x'),
                  onSelected: (v) => _toggleSource('x', v),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Max Items
            Row(
              children: [
                Text(
                  l10n.maxItems,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.borderRadiusSm,
                    ),
                  ),
                  child: Text(
                    maxItems.round().toString(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
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
  final IconData icon;
  final Color color;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _SourceChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon, size: 18, color: selected ? color : null),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
    );
  }
}

// ---------------------------------------------------------------------------
// Trending Topics
// ---------------------------------------------------------------------------

class _TrendingTopicsSection extends StatelessWidget {
  final ValueChanged<String> onTopicTap;

  const _TrendingTopicsSection({required this.onTopicTap});

  static const _topics = [
    _TrendingTopic('AI', Icons.auto_awesome_rounded),
    _TrendingTopic('Bitcoin', Icons.currency_bitcoin_rounded),
    _TrendingTopic('iPhone', Icons.phone_iphone_rounded),
    _TrendingTopic('Tesla', Icons.electric_car_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colors = theme.colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 18,
              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.trendingTopics,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _topics.map((topic) {
            return PressFeedback(
              onTap: () => onTopicTap(topic.label),
              child: ActionChip(
                avatar: Icon(topic.icon, size: 18),
                label: Text(topic.label),
                onPressed: () => onTopicTap(topic.label),
                side: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusXl,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TrendingTopic {
  final String label;
  final IconData icon;
  const _TrendingTopic(this.label, this.icon);
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
    final tpColors = theme.trendPulseColors;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
    );
    final dotStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${l10n.poweredBy}  ', style: muted),
        Icon(
          Icons.forum_rounded,
          size: 12,
          color: tpColors.reddit.withValues(alpha: 0.5),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(l10n.platformReddit, style: muted),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('·', style: dotStyle),
        ),
        Icon(
          Icons.play_circle_rounded,
          size: 12,
          color: tpColors.youtube.withValues(alpha: 0.5),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(l10n.platformYouTube, style: muted),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('·', style: dotStyle),
        ),
        Icon(
          Icons.tag_rounded,
          size: 12,
          color: tpColors.xPlatform.withValues(alpha: 0.5),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(l10n.platformX, style: muted),
      ],
    );
  }
}
