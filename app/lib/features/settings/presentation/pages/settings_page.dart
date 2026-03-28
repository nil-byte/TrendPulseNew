import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/network/api_endpoints.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
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
    final packageInfoAsync = ref.watch(packageInfoProvider);
    final appVersion = packageInfoAsync.valueOrNull?.version ?? '...';

    ref.listen<String>(baseUrlProvider, (_, next) {
      if (_urlController.text != next) {
        _urlController.text = next;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.settingsTitle.toUpperCase(),
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: theme.textTheme.displayLarge?.fontFamily,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: EditorialDivider(topSpace: 0, bottomSpace: 0),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Appearance ---
            _SectionTitle(label: l10n.settingsAppearance),
            const EditorialDivider(topSpace: AppSpacing.sm, bottomSpace: AppSpacing.md),
            
            Text(l10n.settingsTheme.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _ThemePreviewCard(
                    label: l10n.themeLight.toUpperCase(),
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
                    label: l10n.themeDark.toUpperCase(),
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
                    label: l10n.themeSystem.toUpperCase(),
                    selected: themeMode == ThemeMode.system,
                    mode: ThemeMode.system,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(ThemeMode.system),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.settingsLanguageLabel.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
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
                  selected: {language},
                  onSelectionChanged: (values) {
                    ref
                        .read(defaultLanguageProvider.notifier)
                        .setLanguage(values.first);
                  },
                  showSelectedIcon: false,
                ),
              ],
            ),
            
            const EditorialDivider.thick(topSpace: AppSpacing.xl, bottomSpace: AppSpacing.lg),

            // --- Service ---
            _SectionTitle(label: l10n.settingsService),
            const EditorialDivider(topSpace: AppSpacing.sm, bottomSpace: AppSpacing.md),
            
            Text(
              l10n.settingsServerUrl.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: theme.textTheme.displayLarge?.fontFamily,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: ApiEndpoints.defaultBaseUrl,
                      isDense: true,
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.borderRadiusXl + 4,
                        ),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.borderRadiusXl + 4,
                        ),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.borderRadiusXl + 4,
                        ),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 1.4,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveBaseUrl(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  height: 52,
                  width: 52,
                  child: IconButton.filledTonal(
                    onPressed: _saveBaseUrl,
                    icon: const Icon(Icons.save_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l10n.settingsDefaultItems.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '$maxItems',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: theme.textTheme.displayLarge?.fontFamily,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Slider(
              value: maxItems.toDouble(),
              min: 10,
              max: 100,
              divisions: 9,
              onChanged: (value) {
                ref
                    .read(defaultMaxItemsProvider.notifier)
                    .setMaxItems(value.round());
              },
            ),
            
            const EditorialDivider.thick(topSpace: AppSpacing.xl, bottomSpace: AppSpacing.lg),

            // --- Notifications ---
            _SectionTitle(label: l10n.settingsNotifications),
            const EditorialDivider(topSpace: AppSpacing.sm, bottomSpace: 0),
            
            SwitchListTile(
              title: Text(
                l10n.settingsInAppNotify.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              contentPadding: EdgeInsets.zero,
              value: inAppNotify,
              onChanged: (_) =>
                  ref.read(inAppNotifyProvider.notifier).toggle(),
            ),
            const EditorialDivider(topSpace: 0, bottomSpace: 0),
            SwitchListTile(
              title: Text(
                l10n.settingsSubscriptionNotify.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              contentPadding: EdgeInsets.zero,
              value: subscriptionNotify,
              onChanged: (_) =>
                  ref.read(subscriptionNotifyProvider.notifier).toggle(),
            ),
            const EditorialDivider(topSpace: 0, bottomSpace: AppSpacing.lg),

            const SizedBox(height: AppSpacing.lg),

            // --- About ---
            _SectionTitle(label: l10n.settingsAbout),
            const EditorialDivider(topSpace: AppSpacing.sm, bottomSpace: AppSpacing.md),
            
            Row(
              children: [
                Icon(
                  Icons.analytics_rounded,
                  color: colorScheme.onSurface,
                  size: 32,
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appTitle.toUpperCase(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: theme.textTheme.displayLarge?.fontFamily,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    Text(
                      l10n.settingsAboutMeta(appVersion, 'MIT').toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.settingsAboutDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
            
            const SizedBox(height: AppSpacing.xxl),
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
          content: Text(
            AppLocalizations.of(context)!.settingsServerUrlSaved.toUpperCase(),
          ),
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
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.titleMedium?.copyWith(
        fontFamily: theme.textTheme.displayLarge?.fontFamily,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
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
    final previewTheme = switch (mode) {
      ThemeMode.dark => AppTheme.dark,
      _ => AppTheme.light,
    };
    final previewColors = previewTheme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.8),
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXl + 4),
        ),
        child: Column(
          children: [
            // Mini preview
            _buildPreviewBody(
              previewBg: previewColors.surfaceContainerLowest,
              previewHeader: previewColors.onSurface,
              previewCard: previewColors.surface,
              previewCardLine: previewColors.outline,
              isSystem: mode == ThemeMode.system,
            ),

            // Label area
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: selected ? colorScheme.primaryContainer : Colors.transparent,
                border: Border(top: BorderSide(
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.4)
                      : colorScheme.outline.withValues(alpha: 0.8),
                )),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppSpacing.borderRadiusXl + 4),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
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
      final lightPreview = AppTheme.light.colorScheme;
      final darkPreview = AppTheme.dark.colorScheme;
      return SizedBox(
        height: 80,
        child: Row(
          children: [
            Expanded(
              child: _PreviewMock(
                bg: lightPreview.surfaceContainerLowest,
                header: lightPreview.onSurface,
                card: lightPreview.surface,
                cardLine: lightPreview.outline,
              ),
            ),
            Container(width: 1, color: lightPreview.outline),
            Expanded(
              child: _PreviewMock(
                bg: darkPreview.surfaceContainerLowest,
                header: darkPreview.onSurface,
                card: darkPreview.surface,
                cardLine: darkPreview.outline,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 80,
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

  const _PreviewMock({
    required this.bg,
    required this.header,
    required this.card,
    required this.cardLine,
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
            height: 12,
            color: header,
          ),
          const SizedBox(height: 6),
          // Divider mock
          Container(height: 1, color: cardLine),
          const SizedBox(height: 6),
          // Card 1
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: card,
                border: Border.all(color: cardLine, width: 1.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(height: 2, width: double.infinity, color: cardLine),
                  Container(height: 2, width: 24, color: cardLine),
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
                border: Border.all(color: cardLine, width: 1.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(height: 2, width: double.infinity, color: cardLine),
                  Container(height: 2, width: 18, color: cardLine),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
