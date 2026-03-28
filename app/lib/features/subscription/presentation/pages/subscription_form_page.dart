import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
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
        appBar: AppBar(title: Text(l10n.subscriptionKeyword)),
        body: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (sub) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_loaded) {
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
          _isEdit ? l10n.subscriptionKeyword : l10n.addFirstSubscription,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.confirm),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _SectionLabel(label: l10n.subscriptionKeyword, theme: theme),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _keywordController,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadiusMd),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.subscriptionKeyword : null,
            ),

            const SizedBox(height: AppSpacing.lg),
            _SectionLabel(label: l10n.language, theme: theme),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'zh', label: Text('ZH')),
              ],
              selected: {_language},
              onSelectionChanged: (v) => setState(() => _language = v.first),
              style: SegmentedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadiusMd),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            _SectionLabel(label: l10n.dataSources, theme: theme),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                _SourceFilterChip(
                  label: 'Reddit',
                  icon: Icons.forum_rounded,
                  color: tpColors.reddit,
                  selected: _sources.contains('reddit'),
                  onSelected: (v) =>
                      setState(() => _toggleSource('reddit', v)),
                ),
                _SourceFilterChip(
                  label: 'YouTube',
                  icon: Icons.play_circle_rounded,
                  color: tpColors.youtube,
                  selected: _sources.contains('youtube'),
                  onSelected: (v) =>
                      setState(() => _toggleSource('youtube', v)),
                ),
                _SourceFilterChip(
                  label: 'X',
                  icon: Icons.tag_rounded,
                  color: tpColors.xPlatform,
                  selected: _sources.contains('x'),
                  onSelected: (v) => setState(() => _toggleSource('x', v)),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            _SectionLabel(label: l10n.subscriptionInterval, theme: theme),
            const SizedBox(height: AppSpacing.sm),
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
                ButtonSegment(
                  value: 'daily',
                  label: Text(l10n.intervalDaily),
                ),
                ButtonSegment(
                  value: 'weekly',
                  label: Text(l10n.intervalWeekly),
                ),
              ],
              selected: {_interval},
              onSelectionChanged: (v) => setState(() => _interval = v.first),
              style: SegmentedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.borderRadiusMd),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            _SectionLabel(
              label: '${l10n.maxItems}: ${_maxItems.toInt()}',
              theme: theme,
            ),
            const SizedBox(height: AppSpacing.sm),
            Slider(
              value: _maxItems,
              min: 10,
              max: 100,
              divisions: 9,
              label: _maxItems.toInt().toString(),
              onChanged: (v) => setState(() => _maxItems = v),
            ),

            const SizedBox(height: AppSpacing.lg),
            SwitchListTile.adaptive(
              title: Text(
                l10n.notify,
                style: theme.textTheme.titleSmall,
              ),
              value: _notify,
              onChanged: (v) => setState(() => _notify = v),
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppSpacing.borderRadiusMd),
              ),
            ),
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

    final body = {
      'keyword': _keywordController.text.trim(),
      'language': _language,
      'sources': _sources.toList(),
      'interval': _interval,
      'max_items': _maxItems.toInt(),
      'notify': _notify,
    };

    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      if (_isEdit) {
        await repo.updateSubscription(widget.subId!, body);
      } else {
        await repo.createSubscription(body);
      }
      ref.invalidate(subscriptionListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
            ),
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
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SourceFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _SourceFilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? color : null),
          const SizedBox(width: AppSpacing.xs),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
      ),
    );
  }
}
