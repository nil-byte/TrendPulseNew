import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'l10n/app_localizations.dart';
import 'core/network/api_base_url_resolver.dart';
import 'core/network/api_endpoints.dart';
import 'core/observers/app_provider_observer.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/settings/presentation/providers/settings_provider.dart';

Future<String> loadInitialBaseUrl(
  SettingsRepository repository, {
  TargetPlatform? targetPlatform,
  bool isWeb = kIsWeb,
}) async {
  final storedBaseUrl = await repository.getBaseUrl();
  return ApiBaseUrlResolver.normalizeStoredBaseUrl(
    storedBaseUrl,
    fallbackBaseUrl: ApiEndpoints.defaultBaseUrl,
    targetPlatform: targetPlatform,
    isWeb: isWeb,
  );
}

Future<String> loadInitialLanguage(SettingsRepository repository) async {
  return repository.getLanguage();
}

Future<String> loadInitialReportLanguage(
  SettingsRepository repository, {
  required String fallbackLanguage,
}) async {
  return repository.getCachedReportLanguage(
    fallbackLanguage: fallbackLanguage,
  );
}

Future<ThemeMode> loadInitialThemeMode(SettingsRepository repository) async {
  final storedThemeMode = await repository.getThemeMode();
  return ThemeModeNotifier.fromStorage(storedThemeMode);
}

/// Loads persisted URL/locale/notifications before the first [ProviderScope] frame.
Future<List<Override>> buildAppOverrides({
  SettingsRepository? settingsRepository,
  TargetPlatform? targetPlatform,
  bool isWeb = kIsWeb,
}) async {
  final repository = settingsRepository ?? SettingsRepository();
  final initialBaseUrl = await loadInitialBaseUrl(
    repository,
    targetPlatform: targetPlatform,
    isWeb: isWeb,
  );
  final initialInAppNotify = await repository.getInAppNotify();
  final initialLanguage = await loadInitialLanguage(repository);
  final initialReportLanguage = await loadInitialReportLanguage(
    repository,
    fallbackLanguage: initialLanguage,
  );
  final initialThemeMode = await loadInitialThemeMode(repository);

  final overrides = <Override>[
    initialBaseUrlProvider.overrideWithValue(initialBaseUrl),
    initialInAppNotifyProvider.overrideWithValue(initialInAppNotify),
    initialLanguageProvider.overrideWithValue(initialLanguage),
    initialLanguagePreloadedProvider.overrideWithValue(true),
    initialReportLanguageProvider.overrideWithValue(initialReportLanguage),
    initialReportLanguagePreloadedProvider.overrideWithValue(true),
    initialThemeModeProvider.overrideWithValue(initialThemeMode),
    initialThemeModePreloadedProvider.overrideWithValue(true),
    baseUrlTargetPlatformProvider.overrideWithValue(
      targetPlatform ?? defaultTargetPlatform,
    ),
    baseUrlIsWebProvider.overrideWithValue(isWeb),
  ];

  if (settingsRepository != null) {
    overrides.insert(
      0,
      settingsRepositoryProvider.overrideWithValue(repository),
    );
  }

  return overrides;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Zone.current.handleUncaughtError(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    Zone.current.handleUncaughtError(error, stack);
    return true;
  };

  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const _ReleaseErrorFallback();
  }

  await runZonedGuarded(() async {
    final overrides = await buildAppOverrides();
    runApp(
      ProviderScope(
        overrides: overrides,
        observers: [AppProviderObserver()],
        child: const TrendPulseApp(),
      ),
    );
  }, (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[ZoneError] $error');
      debugPrint('$stackTrace');
    }
  });
}

class _ReleaseErrorFallback extends StatelessWidget {
  const _ReleaseErrorFallback();

  @override
  Widget build(BuildContext context) {
    final message =
        AppLocalizations.of(context)?.errorGeneric ??
        '出了点问题 / Something went wrong.';

    return ColoredBox(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
