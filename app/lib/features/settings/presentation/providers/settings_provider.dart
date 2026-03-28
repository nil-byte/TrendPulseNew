import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/features/settings/data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return ThemeModeNotifier(repo);
});

final baseUrlProvider =
    StateNotifierProvider<BaseUrlNotifier, String>((ref) {
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

  BaseUrlNotifier(this._repo) : super('http://localhost:8000') {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.getBaseUrl();
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
