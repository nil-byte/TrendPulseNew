import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:trendpulse/core/network/api_endpoints.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  final repo = ref.watch(settingsRepositoryProvider);
  return ThemeModeNotifier(repo);
});

final baseUrlProvider = StateNotifierProvider<BaseUrlNotifier, String>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return BaseUrlNotifier(repo);
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
  return InAppNotifyNotifier(repo);
});

final subscriptionNotifyProvider =
    StateNotifierProvider<SubscriptionNotifyNotifier, bool>((ref) {
      final repo = ref.watch(settingsRepositoryProvider);
      return SubscriptionNotifyNotifier(repo);
    });

final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

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

  BaseUrlNotifier(this._repo) : super(ApiEndpoints.defaultBaseUrl) {
    _load();
  }

  Future<void> _load() async {
    final loadedBaseUrl = await _repo.getBaseUrl();
    state = loadedBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    state = url;
    await _repo.setBaseUrl(url);
  }
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

  InAppNotifyNotifier(this._repo) : super(true) {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.getInAppNotify();
  }

  Future<void> toggle() async {
    state = !state;
    await _repo.setInAppNotify(state);
  }
}

class SubscriptionNotifyNotifier extends StateNotifier<bool> {
  final SettingsRepository _repo;

  SubscriptionNotifyNotifier(this._repo) : super(true) {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.getSubscriptionNotify();
  }

  Future<void> toggle() async {
    state = !state;
    await _repo.setSubscriptionNotify(state);
  }
}
