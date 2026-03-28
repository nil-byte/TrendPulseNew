import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/network/api_endpoints.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ref.read(baseUrlProvider));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(defaultLanguageProvider);
    final maxItems = ref.watch(defaultMaxItemsProvider);
    final inAppNotify = ref.watch(inAppNotifyProvider);
    final subscriptionNotify = ref.watch(subscriptionNotifyProvider);

    ref.listen<String>(baseUrlProvider, (_, next) {
      if (_urlController.text != next) {
        _urlController.text = next;
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTab)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Appearance ---
            _SectionTitle(label: l10n.settingsAppearance),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsTheme,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: _ThemePreviewCard(
                            label: l10n.themeLight,
                            selected: themeMode == ThemeMode.light,
                            mode: ThemeMode.light,
                            onTap: () => ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.light),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ThemePreviewCard(
                            label: l10n.themeDark,
                            selected: themeMode == ThemeMode.dark,
                            mode: ThemeMode.dark,
                            onTap: () => ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.dark),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ThemePreviewCard(
                            label: l10n.themeSystem,
                            selected: themeMode == ThemeMode.system,
                            mode: ThemeMode.system,
                            onTap: () => ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(ThemeMode.system),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.lg * 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.settingsLanguageLabel,
                          style: theme.textTheme.titleSmall,
                        ),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'en',
                              label: Text(l10n.languageEnglish),
                            ),
                            ButtonSegment(
                              value: 'zh',
                              label: Text(l10n.languageChinese),
                            ),
                          ],
                          selected: {language},
                          onSelectionChanged: (values) {
                            ref
                                .read(defaultLanguageProvider.notifier)
                                .setLanguage(values.first);
                          },
                          style: SegmentedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // --- Service ---
            _SectionTitle(label: l10n.settingsService),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsServerUrl,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            decoration: InputDecoration(
                              hintText: ApiEndpoints.defaultBaseUrl,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm + 2,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.borderRadiusMd,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _saveBaseUrl(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton.tonal(
                          onPressed: _saveBaseUrl,
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Icon(Icons.save_outlined, size: 20),
                        ),
                      ],
                    ),
                    const Divider(height: AppSpacing.lg * 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            l10n.settingsDefaultItems,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm + 2,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.borderRadiusSm,
                            ),
                          ),
                          child: Text(
                            '$maxItems',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: maxItems.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 9,
                      label: '$maxItems',
                      onChanged: (value) {
                        ref
                            .read(defaultMaxItemsProvider.notifier)
                            .setMaxItems(value.round());
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // --- Notifications ---
            _SectionTitle(label: l10n.settingsNotifications),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n.settingsInAppNotify),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    value: inAppNotify,
                    onChanged: (_) =>
                        ref.read(inAppNotifyProvider.notifier).toggle(),
                  ),
                  const Divider(indent: AppSpacing.md, endIndent: AppSpacing.md),
                  SwitchListTile(
                    title: Text(l10n.settingsSubscriptionNotify),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    value: subscriptionNotify,
                    onChanged: (_) =>
                        ref.read(subscriptionNotifyProvider.notifier).toggle(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // --- About ---
            _SectionTitle(label: l10n.settingsAbout),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.analytics_rounded,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          l10n.appTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${l10n.settingsVersion} 0.1.0',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${l10n.settingsLicense}: MIT',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Divider(height: AppSpacing.lg * 2),
                    Text(
                      'AI-powered social media trend analysis. '
                      'Aggregate content from Reddit, YouTube, and X, '
                      'then generate insights with Grok.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  void _saveBaseUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      ref.read(baseUrlProvider.notifier).setBaseUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.settingsServerUrl),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Section title
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme preview card
// ---------------------------------------------------------------------------

class _ThemePreviewCard extends StatelessWidget {
  final String label;
  final bool selected;
  final ThemeMode mode;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.label,
    required this.selected,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bool isLight = mode == ThemeMode.light;
    final bool isDark = mode == ThemeMode.dark;

    final Color previewBg =
        isLight
            ? const Color(0xFFF8FAFC)
            : isDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF8FAFC); // system uses light as base
    final Color previewHeader =
        isLight
            ? colorScheme.primary
            : isDark
                ? colorScheme.primary.withValues(alpha: 0.7)
                : colorScheme.primary;
    final Color previewCard =
        isLight
            ? const Color(0xFFFFFFFF)
            : isDark
                ? const Color(0xFF334155)
                : const Color(0xFFFFFFFF);
    final Color previewCardLine =
        isLight
            ? const Color(0xFFE2E8F0)
            : isDark
                ? const Color(0xFF475569)
                : const Color(0xFFE2E8F0);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusMd),
        ),
        child: Column(
          children: [
            // Mini preview
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.borderRadiusMd - 1),
              ),
              child: _buildPreviewBody(
                previewBg: previewBg,
                previewHeader: previewHeader,
                previewCard: previewCard,
                previewCardLine: previewCardLine,
                isSystem: mode == ThemeMode.system,
              ),
            ),

            // Label area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppSpacing.borderRadiusMd - 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewBody({
    required Color previewBg,
    required Color previewHeader,
    required Color previewCard,
    required Color previewCardLine,
    required bool isSystem,
  }) {
    if (isSystem) {
      return SizedBox(
        height: 100,
        child: Row(
          children: [
            Expanded(
              child: _PreviewMock(
                bg: const Color(0xFFF8FAFC),
                header: previewHeader,
                card: const Color(0xFFFFFFFF),
                cardLine: const Color(0xFFE2E8F0),
                clipLeft: true,
              ),
            ),
            Expanded(
              child: _PreviewMock(
                bg: const Color(0xFF1E293B),
                header: previewHeader.withValues(alpha: 0.7),
                card: const Color(0xFF334155),
                cardLine: const Color(0xFF475569),
                clipRight: true,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: _PreviewMock(
        bg: previewBg,
        header: previewHeader,
        card: previewCard,
        cardLine: previewCardLine,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini mock preview widget
// ---------------------------------------------------------------------------

class _PreviewMock extends StatelessWidget {
  final Color bg;
  final Color header;
  final Color card;
  final Color cardLine;
  final bool clipLeft;
  final bool clipRight;

  const _PreviewMock({
    required this.bg,
    required this.header,
    required this.card,
    required this.cardLine,
    this.clipLeft = false,
    this.clipRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AppBar mock
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: header,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 6),
          // Card 1
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: cardLine, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    height: 4,
                    width: 24,
                    decoration: BoxDecoration(
                      color: cardLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Card 2
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: cardLine, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    height: 4,
                    width: 18,
                    decoration: BoxDecoration(
                      color: cardLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Nav dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == 0 ? header : cardLine,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
