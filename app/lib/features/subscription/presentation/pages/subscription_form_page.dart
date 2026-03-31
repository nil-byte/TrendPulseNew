import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_motion.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_typography.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/core/widgets/editorial_switch_row.dart';
import 'package:trendpulse/core/widgets/error_widget.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';
import 'package:trendpulse/features/subscription/data/subscription_request.dart';
import 'package:trendpulse/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class SubscriptionFormPage extends ConsumerStatefulWidget {
  final String? subId;

  const SubscriptionFormPage({super.key, this.subId});

  @override
  ConsumerState<SubscriptionFormPage> createState() =>
      _SubscriptionFormPageState();
}

class _SubscriptionFormPageState extends ConsumerState<SubscriptionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _keywordController = TextEditingController();

  String _contentLanguage = 'en';
  Set<String> _sources = {'reddit'};
  String _interval = 'daily';
  double _maxItems = 50;
  bool? _notify;
  bool _saving = false;
  bool _loaded = false;

  bool get _isEdit => widget.subId != null;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tpColors = theme.trendPulseColors;

    if (!_loaded && _isEdit) {
      final detailAsync = ref.watch(subscriptionDetailProvider(widget.subId!));
      return Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.editEntry.toUpperCase(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: theme.textTheme.displayLarge?.fontFamily,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: EditorialDivider.thick(topSpace: 0, bottomSpace: 0),
          ),
        ),
        body: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.subscriptionLoadError,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (sub) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_loaded && mounted) {
                setState(() {
                  _keywordController.text = sub.keyword;
                  _contentLanguage = sub.contentLanguage;
                  _sources = sub.sources.toSet();
                  _interval = sub.interval;
                  _maxItems = sub.maxItems.toDouble();
                  _notify = sub.notify;
                  _loaded = true;
                });
              }
            });
            return const Center(child: CircularProgressIndicator());
          },
        ),
      );
    }

    if (!_loaded) {
      final subscriptionNotifyAsync = ref.watch(subscriptionNotifyProvider);
      return Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.newEntry.toUpperCase(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: theme.textTheme.displayLarge?.fontFamily,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: EditorialDivider.thick(topSpace: 0, bottomSpace: 0),
          ),
        ),
        body: subscriptionNotifyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => AppErrorWidget(
            message: l10n.errorGeneric,
            retryLabel: l10n.retry,
            onRetry: () => ref.invalidate(notificationSettingsProvider),
          ),
          data: (notifyDefault) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_loaded && mounted) {
                setState(() {
                  _contentLanguage = ref.read(defaultLanguageProvider);
                  _notify = notifyDefault;
                  _loaded = true;
                });
              }
            });
            return const Center(child: CircularProgressIndicator());
          },
        ),
      );
    }

    final notify = _notify;
    if (notify == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            (_isEdit ? l10n.editEntry : l10n.newEntry).toUpperCase(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: theme.textTheme.displayLarge?.fontFamily,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: EditorialDivider.thick(topSpace: 0, bottomSpace: 0),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          (_isEdit ? l10n.editEntry : l10n.newEntry).toUpperCase(),
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: theme.textTheme.displayLarge?.fontFamily,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: EditorialDivider.thick(topSpace: 0, bottomSpace: 0),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _SectionLabel(
              label: l10n.subscriptionSubjectLabel.toUpperCase(),
              theme: theme,
            ),
            const EditorialDivider(
              topSpace: AppSpacing.xs,
              bottomSpace: AppSpacing.md,
            ),
            TextFormField(
              controller: _keywordController,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: theme.textTheme.displayLarge?.fontFamily,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: l10n.subscriptionKeywordHint,
                hintStyle: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: theme.textTheme.displayLarge?.fontFamily,
                  color: colorScheme.onSurface.withValues(
                    alpha: AppOpacity.hint,
                  ),
                  fontStyle: FontStyle.italic,
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.requiredField.toUpperCase()
                  : null,
            ),

            const SizedBox(height: AppSpacing.xl),
            _SectionLabel(
              label: l10n.contentLanguageLabel.toUpperCase(),
              theme: theme,
            ),
            const EditorialDivider(
              topSpace: AppSpacing.xs,
              bottomSpace: AppSpacing.md,
            ),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'en',
                  label: Text(l10n.languageEnglish.toUpperCase()),
                ),
                ButtonSegment(
                  value: 'zh',
                  label: Text(l10n.languageChinese.toUpperCase()),
                ),
              ],
              selected: {_contentLanguage},
              onSelectionChanged: (v) =>
                  setState(() => _contentLanguage = v.first),
              showSelectedIcon: false,
            ),

            const SizedBox(height: AppSpacing.xl),
            _SectionLabel(label: l10n.dataSources, theme: theme),
            const EditorialDivider(
              topSpace: AppSpacing.xs,
              bottomSpace: AppSpacing.md,
            ),
            Row(
              children: [
                Expanded(
                  child: _SourceToggleButton(
                    label: l10n.platformReddit,
                    color: tpColors.reddit,
                    selected: _sources.contains('reddit'),
                    onTap: () => setState(() => _toggleSource('reddit', !_sources.contains('reddit'))),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SourceToggleButton(
                    label: l10n.platformYouTube,
                    color: tpColors.youtube,
                    selected: _sources.contains('youtube'),
                    onTap: () => setState(() => _toggleSource('youtube', !_sources.contains('youtube'))),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SourceToggleButton(
                    label: l10n.platformX,
                    color: tpColors.xPlatform,
                    selected: _sources.contains('x'),
                    onTap: () => setState(() => _toggleSource('x', !_sources.contains('x'))),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
            _SectionLabel(
              label: l10n.subscriptionInterval.toUpperCase(),
              theme: theme,
            ),
            const EditorialDivider(
              topSpace: AppSpacing.xs,
              bottomSpace: AppSpacing.md,
            ),
            _IntervalSelector(
              segments: [
                (value: 'hourly', label: l10n.intervalHourly),
                (value: '6hours', label: l10n.intervalSixHours),
                (value: 'daily', label: l10n.intervalDaily),
                (value: 'weekly', label: l10n.intervalWeekly),
              ],
              selected: _interval,
              onChanged: (v) => setState(() => _interval = v),
            ),

            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel(label: l10n.maxItems.toUpperCase(), theme: theme),
                Text(
                  _maxItems.toInt().toString(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: AppTypography.editorialSansFamily,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const EditorialDivider(
              topSpace: AppSpacing.xs,
              bottomSpace: AppSpacing.md,
            ),
            Slider(
              value: _maxItems,
              min: 10,
              max: 100,
              divisions: 9,
              onChanged: (v) => setState(() => _maxItems = v),
            ),

            const SizedBox(height: AppSpacing.xl),
            _SectionLabel(
              label: l10n.settingsNotifications.toUpperCase(),
              theme: theme,
            ),
            const EditorialDivider(topSpace: AppSpacing.xs, bottomSpace: 0),
            EditorialSwitchRow(
              title: Text(
                l10n.subscriptionEnableAlerts.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              value: notify,
              onChanged: (v) => setState(() => _notify = v),
            ),
            const EditorialDivider(topSpace: 0, bottomSpace: AppSpacing.xl),

            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Text(
                        l10n.subscriptionSaveAction.toUpperCase(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: colorScheme.onPrimary,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  void _toggleSource(String source, bool selected) {
    if (selected) {
      _sources.add(source);
    } else if (_sources.length > 1) {
      _sources.remove(source);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sources.isEmpty) return;
    final notify = _notify;
    if (notify == null) return;

    setState(() => _saving = true);

    final request = SubscriptionUpsertRequest(
      keyword: _keywordController.text.trim(),
      contentLanguage: _contentLanguage,
      sources: _sources.toList(),
      interval: _interval,
      maxItems: _maxItems.toInt(),
      notify: notify,
    );

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      if (_isEdit) {
        await repo.updateSubscription(widget.subId!, request);
      } else {
        await repo.createSubscription(request);
      }
      ref.invalidate(subscriptionListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.subscriptionSaveError),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _SectionLabel({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

/// Equal-width source toggle — fills its [Expanded] parent, pill shape,
/// brand colour when selected.
class _SourceToggleButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SourceToggleButton({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        selected ? AppColors.onBrandFill(color) : theme.colorScheme.onSurface;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
    );

    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: FilterChip(
          label: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          selectedColor: color,
          backgroundColor: Colors.transparent,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
          labelStyle: (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
          shape: shape,
          side: BorderSide(
            color: selected ? color : theme.colorScheme.outline,
            width: selected ? 1.5 : 1.0,
          ),
        ),
      ),
    );
  }
}

/// Flat editorial interval selector — 4 equal segments, sharp corners,
/// and explicit semantics for keyboard and accessibility users.
class _IntervalSelector extends StatelessWidget {
  final List<({String value, String label})> segments;
  final String selected;
  final ValueChanged<String> onChanged;

  const _IntervalSelector({
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.zero,
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(segments.length, (i) {
            final seg = segments[i];
            final isSelected = seg.value == selected;

            return Expanded(
              child: MergeSemantics(
                key: ValueKey('subscription-interval-${seg.value}'),
                child: Semantics(
                  label: seg.label,
                  selected: isSelected,
                  child: AnimatedContainer(
                    duration: AppMotion.quick,
                    curve: AppMotion.standard,
                    decoration: BoxDecoration(
                      color: isSelected ? colors.primary : Colors.transparent,
                      border: i == 0
                          ? null
                          : Border(
                              left: BorderSide(color: colors.outline),
                            ),
                    ),
                    child: TextButton(
                      onPressed: () => onChanged(seg.value),
                      style: ButtonStyle(
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                        ),
                        foregroundColor: WidgetStatePropertyAll(
                          isSelected ? colors.onPrimary : colors.onSurface,
                        ),
                        backgroundColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        shape: const WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        overlayColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.pressed)) {
                            return colors.primary.withValues(
                              alpha: AppOpacity.soft,
                            );
                          }
                          if (states.contains(WidgetState.hovered)) {
                            return colors.primary.withValues(
                              alpha: AppOpacity.hover,
                            );
                          }
                          return null;
                        }),
                      ),
                      child: ExcludeSemantics(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            seg.label,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
