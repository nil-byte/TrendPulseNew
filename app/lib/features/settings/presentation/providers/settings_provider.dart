import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:trendpulse/core/network/api_client.dart';
import 'package:trendpulse/core/network/api_base_url_resolver.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';
import 'package:trendpulse/features/settings/data/notification_settings.dart';
import 'package:trendpulse/features/settings/data/notification_settings_repository.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final initialBaseUrlProvider = Provider<String>((ref) {
  return ApiEndpoints.defaultBaseUrl;
});

final baseUrlTargetPlatformProvider = Provider<TargetPlatform>((ref) {
  return defaultTargetPlatform;
});

final baseUrlIsWebProvider = Provider<bool>((ref) {
  return kIsWeb;
});

final initialInAppNotifyProvider = Provider<bool>((ref) {
  return true;
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  final repo = ref.watch(settingsRepositoryProvider);
  return ThemeModeNotifier(repo);
});

final baseUrlProvider = StateNotifierProvider<BaseUrlNotifier, String>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  final initialBaseUrl = ref.watch(initialBaseUrlProvider);
  final targetPlatform = ref.watch(baseUrlTargetPlatformProvider);
  final isWeb = ref.watch(baseUrlIsWebProvider);
  return BaseUrlNotifier(
    repo,
    initialBaseUrl,
    targetPlatform: targetPlatform,
    isWeb: isWeb,
  );
});

final defaultLanguageProvider =
    StateNotifierProvider<DefaultLanguageNotifier, String>((ref) {
      final repo = ref.watch(settingsRepositoryProvider);
      return DefaultLanguageNotifier(repo);
    });

final defaultMaxItemsProvider =
    StateNotifierProvider<DefaultMaxItemsNotifier, int>((ref) {
      final repo = ref.watch(settingsRepositoryProvider);
      return DefaultMaxItemsNotifier(repo);
    });

final inAppNotifyProvider = StateNotifierProvider<InAppNotifyNotifier, bool>((
  ref,
) {
  final repo = ref.watch(settingsRepositoryProvider);
  final initialValue = ref.watch(initialInAppNotifyProvider);
  return InAppNotifyNotifier(repo, initialValue);
});

final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>((ref) {
      final baseUrl = ref.watch(baseUrlProvider);
      return NotificationSettingsRepository(
        apiClient: ApiClient(baseUrl: baseUrl),
      );
    });

final notificationSettingsProvider = FutureProvider<NotificationSettings>((
  ref,
) async {
  final repository = ref.watch(notificationSettingsRepositoryProvider);
  return repository.getNotificationSettings();
});

final subscriptionNotifyProvider = Provider<AsyncValue<bool>>((ref) {
  final notificationSettingsAsync = ref.watch(notificationSettingsProvider);
  return notificationSettingsAsync.whenData(
    (settings) => settings.subscriptionNotifyDefault,
  );
});

final notificationSettingsControllerProvider =
    Provider<NotificationSettingsController>((ref) {
      final repository = ref.watch(notificationSettingsRepositoryProvider);
      return NotificationSettingsController(ref, repository);
    });

final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

class NotificationSettingsController {
  final Ref _ref;
  final NotificationSettingsRepository _repository;

  NotificationSettingsController(this._ref, this._repository);

  Future<void> setSubscriptionNotifyDefault(bool value) async {
    await _repository.updateNotificationSettings(
      subscriptionNotifyDefault: value,
      applyToExisting: true,
    );
    _ref.invalidate(notificationSettingsProvider);
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SettingsRepository _repo;

  ThemeModeNotifier(this._repo) : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final mode = await _repo.getThemeMode();
    state = _fromString(mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _repo.setThemeMode(_toString(mode));
  }

  static ThemeMode _fromString(String value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _toString(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

class BaseUrlNotifier extends StateNotifier<String> {
  final SettingsRepository _repo;
  final TargetPlatform _targetPlatform;
  final bool _isWeb;

  BaseUrlNotifier(
    this._repo,
    String initialBaseUrl, {
    required TargetPlatform targetPlatform,
    required bool isWeb,
  }) : _targetPlatform = targetPlatform,
       _isWeb = isWeb,
       super(
         _normalizeBaseUrl(
           initialBaseUrl,
           targetPlatform: targetPlatform,
           isWeb: isWeb,
         ),
       );

  Future<void> setBaseUrl(String url) async {
    final normalizedBaseUrl = _normalizeBaseUrl(
      url,
      targetPlatform: _targetPlatform,
      isWeb: _isWeb,
    );
    final persistedBaseUrl = _sanitizeBaseUrlForStorage(
      url,
      targetPlatform: _targetPlatform,
      isWeb: _isWeb,
    );
    state = normalizedBaseUrl;
    await _repo.setBaseUrl(persistedBaseUrl);
  }

  static String _normalizeBaseUrl(
    String? url, {
    required TargetPlatform targetPlatform,
    required bool isWeb,
  }) => ApiBaseUrlResolver.normalizeStoredBaseUrl(
    url,
    fallbackBaseUrl: ApiEndpoints.defaultBaseUrl,
    targetPlatform: targetPlatform,
    isWeb: isWeb,
  );

  static String _sanitizeBaseUrlForStorage(
    String? url, {
    required TargetPlatform targetPlatform,
    required bool isWeb,
  }) => ApiBaseUrlResolver.sanitizeBaseUrlForStorage(
    url,
    targetPlatform: targetPlatform,
    isWeb: isWeb,
  );
}

class DefaultLanguageNotifier extends StateNotifier<String> {
  final SettingsRepository _repo;

  DefaultLanguageNotifier(this._repo) : super('en') {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.getLanguage();
  }

  Future<void> setLanguage(String language) async {
    state = language;
    await _repo.setLanguage(language);
  }
}

class DefaultMaxItemsNotifier extends StateNotifier<int> {
  final SettingsRepository _repo;

  DefaultMaxItemsNotifier(this._repo) : super(50) {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.getMaxItems();
  }

  Future<void> setMaxItems(int maxItems) async {
    state = maxItems;
    await _repo.setMaxItems(maxItems);
  }
}

class InAppNotifyNotifier extends StateNotifier<bool> {
  final SettingsRepository _repo;

  InAppNotifyNotifier(this._repo, bool initialValue) : super(initialValue);

  Future<void> toggle() async {
    state = !state;
    await _repo.setInAppNotify(state);
  }
}
