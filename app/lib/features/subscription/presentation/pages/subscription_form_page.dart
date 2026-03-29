import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/core/widgets/editorial_switch_row.dart';
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

  String _language = 'en';
  Set<String> _sources = {'reddit'};
  String _interval = 'daily';
  double _maxItems = 50;
  bool _notify = false;
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

    if (_isEdit && !_loaded) {
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
                  _language = sub.language;
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
            const EditorialDivider(topSpace: AppSpacing.xs, bottomSpace: AppSpacing.md),
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
                  color: colorScheme.onSurface.withValues(alpha: AppOpacity.hint),
                  fontStyle: FontStyle.italic,
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.requiredField.toUpperCase()
                  : null,
            ),

            const SizedBox(height: AppSpacing.xl),
            _SectionLabel(label: l10n.language.toUpperCase(), theme: theme),
            const EditorialDivider(topSpace: AppSpacing.xs, bottomSpace: AppSpacing.md),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'en', label: Text(l10n.languageEnglish.toUpperCase())),
                ButtonSegment(value: 'zh', label: Text(l10n.languageChinese.toUpperCase())),
              ],
              selected: {_language},
              onSelectionChanged: (v) => setState(() => _language = v.first),
              showSelectedIcon: false,
            ),

            const SizedBox(height: AppSpacing.xl),
            _SectionLabel(label: l10n.dataSources.toUpperCase(), theme: theme),
            const EditorialDivider(topSpace: AppSpacing.xs, bottomSpace: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _SourceFilterChip(
                  label: l10n.platformReddit.toUpperCase(),
                  color: tpColors.reddit,
                  selected: _sources.contains('reddit'),
                  onSelected: (v) => setState(() => _toggleSource('reddit', v)),
                ),
                _SourceFilterChip(
                  label: l10n.platformYouTube.toUpperCase(),
                  color: tpColors.youtube,
                  selected: _sources.contains('youtube'),
                  onSelected: (v) =>
                      setState(() => _toggleSource('youtube', v)),
                ),
                _SourceFilterChip(
                  label: l10n.platformX.toUpperCase(),
                  color: tpColors.xPlatform,
                  selected: _sources.contains('x'),
                  onSelected: (v) => setState(() => _toggleSource('x', v)),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
            _SectionLabel(
              label: l10n.subscriptionInterval.toUpperCase(),
              theme: theme,
            ),
            const EditorialDivider(topSpace: AppSpacing.xs, bottomSpace: AppSpacing.md),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'hourly',
                  label: Text(l10n.intervalHourly),
                ),
                ButtonSegment(
                  value: '6hours',
                  label: Text(l10n.intervalSixHours),
                ),
                ButtonSegment(value: 'daily', label: Text(l10n.intervalDaily)),
                ButtonSegment(
                  value: 'weekly',
                  label: Text(l10n.intervalWeekly),
                ),
              ],
              selected: {_interval},
              onSelectionChanged: (v) => setState(() => _interval = v.first),
              showSelectedIcon: false,
            ),

            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel(
                  label: l10n.maxItems.toUpperCase(),
                  theme: theme,
                ),
                Text(
                  _maxItems.toInt().toString(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: theme.textTheme.displayLarge?.fontFamily,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const EditorialDivider(topSpace: AppSpacing.xs, bottomSpace: AppSpacing.md),
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
              value: _notify,
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
                          fontSize: 17,
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

    setState(() => _saving = true);

    final request = SubscriptionUpsertRequest(
      keyword: _keywordController.text.trim(),
      language: _language,
      sources: _sources.toList(),
      interval: _interval,
      maxItems: _maxItems.toInt(),
      notify: _notify,
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

class _SourceFilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _SourceFilterChip({
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
