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

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) {
      // Keep settings sync independent from the shared ApiClient provider graph.
      // Report-language sync needs to work while baseUrlProvider is being read
      // or updated, so reusing apiClientProvider here creates a dependency cycle.
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

final initialLanguageProvider = Provider<String>((ref) {
  return 'zh';
});

final initialLanguagePreloadedProvider = Provider<bool>((ref) {
  return false;
});

final initialReportLanguageProvider = Provider<String>((ref) {
  return ref.watch(initialLanguageProvider);
});

final initialReportLanguagePreloadedProvider = Provider<bool>((ref) {
  return ref.watch(initialLanguagePreloadedProvider);
});

final initialThemeModeProvider = Provider<ThemeMode>((ref) {
  return ThemeMode.light;
});

final initialThemeModePreloadedProvider = Provider<bool>((ref) {
  return false;
});

final reportLanguageSyncStateProvider = StateProvider<AsyncValue<void>>((ref) {
  return const AsyncData<void>(null);
});

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  final repo = ref.watch(settingsRepositoryProvider);
  final initialThemeMode = ref.watch(initialThemeModeProvider);
  final isPreloaded = ref.watch(initialThemeModePreloadedProvider);
  return ThemeModeNotifier(
    repo,
    initialThemeMode: initialThemeMode,
    isPreloaded: isPreloaded,
  );
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

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  return ApiClient(baseUrl: baseUrl);
});

final defaultLanguageProvider =
    StateNotifierProvider<DefaultLanguageNotifier, String>((ref) {
      final repo = ref.watch(settingsRepositoryProvider);
      final initialLanguage = ref.watch(initialLanguageProvider);
      final languagePreloaded = ref.watch(initialLanguagePreloadedProvider);
      return DefaultLanguageNotifier(
        repo,
        initialLanguage: initialLanguage,
        isPreloaded: languagePreloaded,
      );
    });

final defaultReportLanguageProvider =
    StateNotifierProvider<DefaultReportLanguageNotifier, String>((ref) {
      final repo = ref.watch(settingsRepositoryProvider);
      final initialReportLanguage = ref.watch(initialReportLanguageProvider);
      final reportLanguagePreloaded = ref.watch(
        initialReportLanguagePreloadedProvider,
      );
      return DefaultReportLanguageNotifier(
        repo,
        initialReportLanguage: initialReportLanguage,
        isPreloaded: reportLanguagePreloaded,
        readBaseUrl: () => ref.read(baseUrlProvider),
        setSyncState: (status) {
          ref.read(reportLanguageSyncStateProvider.notifier).state = status;
        },
      );
    });

final languagePreferenceControllerProvider =
    Provider<LanguagePreferenceController>((ref) {
      return LanguagePreferenceController(ref);
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
      final apiClient = ref.watch(apiClientProvider);
      return NotificationSettingsRepository(apiClient: apiClient);
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

class LanguagePreferenceController {
  final Ref _ref;

  LanguagePreferenceController(this._ref);

  Future<bool> setLanguage(String language) async {
    await _ref.read(defaultLanguageProvider.notifier).setLanguage(language);
    try {
      await _ref.read(defaultReportLanguageProvider.notifier).setLanguage(
        language,
        rethrowOnFailure: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SettingsRepository _repo;

  ThemeModeNotifier(
    this._repo, {
    required ThemeMode initialThemeMode,
    required bool isPreloaded,
  }) : super(initialThemeMode) {
    if (!isPreloaded) {
      _load();
    }
  }

  Future<void> _load() async {
    final mode = await _repo.getThemeMode();
    state = fromStorage(mode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _repo.setThemeMode(toStorage(mode));
  }

  static ThemeMode fromStorage(String value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String toStorage(ThemeMode mode) => switch (mode) {
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

  DefaultLanguageNotifier(
    this._repo, {
    required String initialLanguage,
    required bool isPreloaded,
  }) : super(initialLanguage) {
    if (isPreloaded) {
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final language = await _repo.getLanguage();
    state = language;
  }

  Future<void> setLanguage(String language) async {
    if (language == state) {
      return;
    }
    state = language;
    await _repo.setLanguage(language);
  }
}

class DefaultReportLanguageNotifier extends StateNotifier<String> {
  final SettingsRepository _repo;
  final String Function() _readBaseUrl;
  final void Function(AsyncValue<void> status) _setSyncState;
  Future<void> _reportLanguageSyncChain = Future<void>.value();

  DefaultReportLanguageNotifier(
    this._repo, {
    required String initialReportLanguage,
    required bool isPreloaded,
    required String Function() readBaseUrl,
    required void Function(AsyncValue<void> status) setSyncState,
  }) : _readBaseUrl = readBaseUrl,
       _setSyncState = setSyncState,
       super(initialReportLanguage) {
    if (isPreloaded) {
      _enqueueReportLanguageSync(
        () => _syncReportLanguage(initialReportLanguage, checkRemoteFirst: true),
      );
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final language = await _repo.getCachedReportLanguage(
      fallbackLanguage: state,
    );
    state = language;
    await _enqueueReportLanguageSync(
      () => _syncReportLanguage(language, checkRemoteFirst: true),
    );
  }

  Future<void> setLanguage(
    String language, {
    bool rethrowOnFailure = false,
  }) async {
    if (language == state) {
      return;
    }
    state = language;
    await _repo.setCachedReportLanguage(language);
    await _enqueueReportLanguageSync(
      () => _syncReportLanguage(language, rethrowOnFailure: rethrowOnFailure),
    );
  }

  Future<void> syncCurrentReportLanguage({
    String? baseUrl,
    bool rethrowOnFailure = false,
  }) async {
    await _enqueueReportLanguageSync(
      () => _syncReportLanguage(
        state,
        baseUrl: baseUrl,
        rethrowOnFailure: rethrowOnFailure,
      ),
    );
  }

  Future<void> _enqueueReportLanguageSync(
    Future<void> Function() action,
  ) {
    _publishSyncState(const AsyncLoading<void>());
    final nextSync = _reportLanguageSyncChain.then((_) => action());
    _reportLanguageSyncChain = nextSync.catchError((_) {});
    return nextSync;
  }

  void _publishSyncState(AsyncValue<void> status) {
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      _setSyncState(status);
    });
  }

  Future<void> _syncReportLanguage(
    String language, {
    bool checkRemoteFirst = false,
    String? baseUrl,
    bool rethrowOnFailure = false,
  }) async {
    final targetBaseUrl = baseUrl ?? _readBaseUrl();
    if (checkRemoteFirst) {
      try {
        final remoteLanguage = await _repo.getReportLanguage(
          baseUrl: targetBaseUrl,
        );
        if (remoteLanguage == language) {
          _publishSyncState(const AsyncData<void>(null));
          return;
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Failed to precheck report language: $error');
        }
      }
    }

    try {
      final resolvedLanguage = await _repo.setReportLanguage(
        language,
        baseUrl: targetBaseUrl,
      );
      if (resolvedLanguage != state) {
        state = resolvedLanguage;
        await _repo.setCachedReportLanguage(resolvedLanguage);
      }
      _publishSyncState(const AsyncData<void>(null));
    } catch (error, stackTrace) {
      _publishSyncState(AsyncError<void>(error, stackTrace));
      if (rethrowOnFailure) {
        rethrow;
      }
      if (kDebugMode) {
        debugPrint('Failed to sync report language: $error');
      }
    }
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
