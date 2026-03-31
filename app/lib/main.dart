import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/network/api_base_url_resolver.dart';
import 'core/network/api_endpoints.dart';
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

  return [
    settingsRepositoryProvider.overrideWithValue(repository),
    initialBaseUrlProvider.overrideWithValue(initialBaseUrl),
    initialInAppNotifyProvider.overrideWithValue(initialInAppNotify),
    initialLanguageProvider.overrideWithValue(initialLanguage),
    initialLanguagePreloadedProvider.overrideWithValue(true),
    baseUrlTargetPlatformProvider.overrideWithValue(
      targetPlatform ?? defaultTargetPlatform,
    ),
    baseUrlIsWebProvider.overrideWithValue(isWeb),
  ];
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = await buildAppOverrides();
  runApp(ProviderScope(overrides: overrides, child: const TrendPulseApp()));
}
