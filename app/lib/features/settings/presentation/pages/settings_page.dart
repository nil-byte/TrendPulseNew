import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/network/api_base_url_resolver.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/core/theme/app_typography.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/core/widgets/editorial_switch_row.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';
import 'package:trendpulse/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _urlController;
  bool _isBaseUrlSaving = false;
  bool _isSubscriptionNotifySaving = false;

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
    final subscriptionNotifyAsync = ref.watch(subscriptionNotifyProvider);
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
          child: EditorialDivider.thick(topSpace: 0, bottomSpace: 0),
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
            const EditorialDivider(
              topSpace: AppSpacing.sm,
              bottomSpace: AppSpacing.md,
            ),

            Text(
              l10n.settingsTheme.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
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
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
                  onSelectionChanged: (values) async {
                    await _changeLanguage(values.first);
                  },
                  showSelectedIcon: false,
                ),
              ],
            ),

            const EditorialDivider.thick(
              topSpace: AppSpacing.xl,
              bottomSpace: AppSpacing.lg,
            ),

            // --- Service ---
            _SectionTitle(label: l10n.settingsService),
            const EditorialDivider(
              topSpace: AppSpacing.sm,
              bottomSpace: AppSpacing.md,
            ),

            Text(
              l10n.settingsServerUrl.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: AppTypography.editorialSansFamily,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: ApiEndpoints.defaultBaseUrl,
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      _saveBaseUrl();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  height: 52,
                  width: 52,
                  child: IconButton.filled(
                    onPressed: _isBaseUrlSaving ? null : _saveBaseUrl,
                    icon: const Icon(Icons.save_outlined),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isBaseUrlSaving ? null : _resetBaseUrl,
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(l10n.settingsServerUrlUseDefault.toUpperCase()),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l10n.settingsDefaultItems.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$maxItems',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: AppTypography.editorialSansFamily,
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

            const EditorialDivider.thick(
              topSpace: AppSpacing.xl,
              bottomSpace: AppSpacing.lg,
            ),

            // --- Notifications ---
            _SectionTitle(label: l10n.settingsNotifications),
            const EditorialDivider(topSpace: AppSpacing.sm, bottomSpace: 0),

            EditorialSwitchRow(
              title: Text(
                l10n.settingsInAppNotify.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              value: inAppNotify,
              onChanged: (_) => ref.read(inAppNotifyProvider.notifier).toggle(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.settingsInAppNotifyHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(
                    alpha: AppOpacity.body,
                  ),
                  height: 1.5,
                ),
              ),
            ),
            const EditorialDivider(topSpace: 0, bottomSpace: 0),
            _buildSubscriptionNotifyRow(subscriptionNotifyAsync, theme, l10n),
            const EditorialDivider(topSpace: 0, bottomSpace: AppSpacing.lg),

            const SizedBox(height: AppSpacing.lg),

            // --- About ---
            _SectionTitle(label: l10n.settingsAbout),
            const EditorialDivider(
              topSpace: AppSpacing.sm,
              bottomSpace: AppSpacing.md,
            ),

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
                      style: AppTypography.caption(theme.textTheme).copyWith(
                        color: colorScheme.onSurface.withValues(
                          alpha: AppOpacity.body,
                        ),
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
                color: colorScheme.onSurface.withValues(
                  alpha: AppOpacity.primary,
                ),
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

  Future<void> _saveBaseUrl() async {
    if (_isBaseUrlSaving) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final rawUrl = _urlController.text;
    final trimmedUrl = rawUrl.trim();
    final targetPlatform = ref.read(baseUrlTargetPlatformProvider);
    final isWeb = ref.read(baseUrlIsWebProvider);
    if (trimmedUrl.isEmpty) {
      await _resetBaseUrl();
      return;
    }

    final validationError = ApiBaseUrlResolver.validateBaseUrl(
      trimmedUrl,
      targetPlatform: targetPlatform,
      isWeb: isWeb,
    );
    if (validationError != null) {
      _showBaseUrlSnackBar(_messageForValidationError(validationError, l10n));
      return;
    }

    await _runExclusiveBaseUrlSave(
      () => _updateBaseUrlAndSync(
        trimmedUrl,
        successMessage: l10n.settingsServerUrlSaved,
      ),
    );
  }

  Future<void> _resetBaseUrl() async {
    if (_isBaseUrlSaving) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    await _runExclusiveBaseUrlSave(
      () => _updateBaseUrlAndSync(
        '',
        successMessage: l10n.settingsServerUrlResetToDefault,
      ),
    );
  }

  Future<void> _runExclusiveBaseUrlSave(
    Future<void> Function() action,
  ) async {
    if (_isBaseUrlSaving) {
      return;
    }

    setState(() {
      _isBaseUrlSaving = true;
    });

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isBaseUrlSaving = false;
        });
      }
    }
  }

  Future<void> _updateBaseUrlAndSync(
    String url, {
    required String successMessage,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final previousBaseUrl = ref.read(baseUrlProvider);
    await ref.read(baseUrlProvider.notifier).setBaseUrl(url);
    final nextBaseUrl = ref.read(baseUrlProvider);

    try {
      await ref
          .read(defaultLanguageProvider.notifier)
          .syncCurrentReportLanguage(
            baseUrl: nextBaseUrl,
            rethrowOnFailure: true,
          );
    } catch (_) {
      await ref.read(baseUrlProvider.notifier).setBaseUrl(previousBaseUrl);
      if (!mounted) {
        return;
      }
      _showBaseUrlSnackBar(l10n.settingsServerUrlSyncFailed);
      return;
    }

    if (!mounted) {
      return;
    }
    _showBaseUrlSnackBar(successMessage);
  }

  Future<void> _setSubscriptionNotifyDefault(bool value) async {
    if (_isSubscriptionNotifySaving) {
      return;
    }

    setState(() {
      _isSubscriptionNotifySaving = true;
    });

    try {
      await ref
          .read(notificationSettingsControllerProvider)
          .setSubscriptionNotifyDefault(value);
      ref.invalidate(subscriptionListProvider);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showBaseUrlSnackBar(AppLocalizations.of(context)!.errorGeneric);
    } finally {
      if (mounted) {
        setState(() {
          _isSubscriptionNotifySaving = false;
        });
      }
    }
  }

  Future<void> _changeLanguage(String language) async {
    try {
      await ref.read(defaultLanguageProvider.notifier).setLanguage(language);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showBaseUrlSnackBar(
        AppLocalizations.of(context)!.settingsLanguageSyncFailed,
      );
    }
  }

  Widget _buildSubscriptionNotifyRow(
    AsyncValue<bool> subscriptionNotifyAsync,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final title = Text(
      l10n.settingsSubscriptionNotify.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
    );

    return subscriptionNotifyAsync.when(
      data: (subscriptionNotify) => EditorialSwitchRow(
        title: title,
        value: subscriptionNotify,
        onChanged: _isSubscriptionNotifySaving
            ? null
            : _setSubscriptionNotifyDefault,
      ),
      loading: () => _AsyncSettingsRow(
        title: title,
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => _AsyncSettingsRow(
        title: title,
        trailing: TextButton(
          onPressed: () => ref.invalidate(notificationSettingsProvider),
          child: Text(l10n.retry.toUpperCase()),
        ),
      ),
    );
  }

  void _showBaseUrlSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message.toUpperCase()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _messageForValidationError(
    ApiBaseUrlValidationError error,
    AppLocalizations l10n,
  ) => switch (error) {
    ApiBaseUrlValidationError.invalidUrl => l10n.settingsServerUrlInvalid,
    ApiBaseUrlValidationError.unsupportedAndroidHttp =>
      l10n.settingsServerUrlAndroidHttpUnsupported,
  };
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

class _AsyncSettingsRow extends StatelessWidget {
  final Widget title;
  final Widget trailing;

  const _AsyncSettingsRow({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      child: Row(
        children: [
          Expanded(child: title),
          const SizedBox(width: AppSpacing.md),
          trailing,
        ],
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
                : colorScheme.outline.withValues(alpha: AppOpacity.primary),
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.zero,
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

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primary.withValues(alpha: AppOpacity.focus)
                    : Colors.transparent,
                border: Border(
                  top: BorderSide(
                    color: selected
                        ? colorScheme.primary.withValues(
                            alpha: AppOpacity.mutedSoft,
                          )
                        : colorScheme.outline.withValues(
                            alpha: AppOpacity.primary,
                          ),
                  ),
                ),
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: selected ? colorScheme.primary : colorScheme.onSurface,
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
          Container(height: 12, color: header),
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
