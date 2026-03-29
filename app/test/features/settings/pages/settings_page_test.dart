import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/settings/data/notification_settings.dart';
import 'package:trendpulse/features/settings/data/notification_settings_repository.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';
import 'package:trendpulse/features/settings/presentation/pages/settings_page.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class _FakeSettingsRepository extends SettingsRepository {
  String? _baseUrl = ApiEndpoints.defaultBaseUrl;
  String _language = 'en';
  int _maxItems = 50;
  String _themeMode = 'system';
  bool _inAppNotify = true;

  @override
  Future<String> getBaseUrl() async {
    final storedUrl = _baseUrl?.trim();
    if (storedUrl == null || storedUrl.isEmpty) {
      return ApiEndpoints.defaultBaseUrl;
    }
    return storedUrl;
  }

  @override
  Future<void> setBaseUrl(String url) async {
    final trimmedUrl = url.trim();
    _baseUrl = trimmedUrl.isEmpty ? null : trimmedUrl;
  }

  @override
  Future<String> getLanguage() async => _language;

  @override
  Future<void> setLanguage(String language) async {
    _language = language;
  }

  @override
  Future<int> getMaxItems() async => _maxItems;

  @override
  Future<void> setMaxItems(int maxItems) async {
    _maxItems = maxItems;
  }

  @override
  Future<String> getThemeMode() async => _themeMode;

  @override
  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
  }

  @override
  Future<bool> getInAppNotify() async => _inAppNotify;

  @override
  Future<void> setInAppNotify(bool value) async {
    _inAppNotify = value;
  }
}

class _FakeNotificationSettingsRepository
    extends NotificationSettingsRepository {
  _FakeNotificationSettingsRepository({bool subscriptionNotifyDefault = true})
    : _settings = NotificationSettings(
        subscriptionNotifyDefault: subscriptionNotifyDefault,
      );

  NotificationSettings _settings;
  int getCalls = 0;
  int updateCalls = 0;
  bool? lastSubscriptionNotifyDefault;
  bool? lastApplyToExisting;

  @override
  Future<NotificationSettings> getNotificationSettings() async {
    getCalls++;
    return _settings;
  }

  @override
  Future<NotificationSettings> updateNotificationSettings({
    required bool subscriptionNotifyDefault,
    required bool applyToExisting,
  }) async {
    updateCalls++;
    lastSubscriptionNotifyDefault = subscriptionNotifyDefault;
    lastApplyToExisting = applyToExisting;
    _settings = NotificationSettings(
      subscriptionNotifyDefault: subscriptionNotifyDefault,
    );
    return _settings;
  }
}

Widget _wrap(
  Widget child, {
  Locale locale = const Locale('en'),
  SettingsRepository? repository,
  NotificationSettingsRepository? notificationSettingsRepository,
  String initialBaseUrl = ApiEndpoints.defaultBaseUrl,
  TargetPlatform baseUrlTargetPlatform = TargetPlatform.iOS,
  bool baseUrlIsWeb = false,
}) {
  PackageInfo.setMockInitialValues(
    appName: 'TrendPulse',
    packageName: 'trendpulse',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );

  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(
        repository ?? _FakeSettingsRepository(),
      ),
      notificationSettingsRepositoryProvider.overrideWithValue(
        notificationSettingsRepository ?? _FakeNotificationSettingsRepository(),
      ),
      initialBaseUrlProvider.overrideWithValue(initialBaseUrl),
      baseUrlTargetPlatformProvider.overrideWithValue(baseUrlTargetPlatform),
      baseUrlIsWebProvider.overrideWithValue(baseUrlIsWeb),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.light,
      home: child,
    ),
  );
}

void main() {
  testWidgets('settings page uses theme-driven segmented and switch styles', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SettingsPage()));
    await tester.pumpAndSettle();

    final segmented = tester.widget<SegmentedButton<String>>(
      find
          .byWidgetPredicate((widget) => widget is SegmentedButton<String>)
          .first,
    );
    expect(segmented.style, isNull);

    expect(find.byType(SwitchListTile), findsNothing);

    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches, isNotEmpty);
    for (final toggle in switches) {
      expect(toggle.thumbColor, isNull);
      expect(toggle.trackColor, isNull);
      expect(toggle.trackOutlineColor, isNull);
    }
  });

  testWidgets('settings page save feedback relies on snackbar theme defaults', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SettingsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, isNull);
    expect(snackBar.shape, isNull);
  });

  testWidgets('settings page url field uses editorial square input borders', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SettingsPage()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SettingsPage));
    final decoration = Theme.of(context).inputDecorationTheme;
    final border = decoration.enabledBorder! as OutlineInputBorder;

    expect(border.borderRadius, BorderRadius.zero);
  });

  testWidgets('settings page title localizes in Chinese', (tester) async {
    await tester.pumpWidget(
      _wrap(const SettingsPage(), locale: const Locale('zh')),
    );
    await tester.pumpAndSettle();

    expect(find.text('偏好设置'), findsOneWidget);
    expect(find.text('PREFERENCES'), findsNothing);
  });

  testWidgets('settings page about metadata reflects runtime app version', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SettingsPage()));
    await tester.pumpAndSettle();

    expect(find.textContaining('1.0.0'), findsOneWidget);
    expect(find.textContaining('0.1.0'), findsNothing);
  });

  testWidgets('settings page clear and save restores default server url', (
    tester,
  ) async {
    final repository = _FakeSettingsRepository();
    await repository.setBaseUrl('http://custom.example:9000');
    final initialBaseUrl = await repository.getBaseUrl();

    await tester.pumpWidget(
      _wrap(
        const SettingsPage(),
        repository: repository,
        initialBaseUrl: initialBaseUrl,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, ApiEndpoints.defaultBaseUrl);
    expect(await repository.getBaseUrl(), ApiEndpoints.defaultBaseUrl);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets(
    'settings page explicit reset button restores default server url',
    (tester) async {
      final repository = _FakeSettingsRepository();
      await repository.setBaseUrl('http://custom.example:9000');
      final initialBaseUrl = await repository.getBaseUrl();

      await tester.pumpWidget(
        _wrap(
          const SettingsPage(),
          repository: repository,
          initialBaseUrl: initialBaseUrl,
          baseUrlTargetPlatform: TargetPlatform.android,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('USE DEFAULT'));
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, ApiEndpoints.defaultBaseUrl);
      expect(await repository.getBaseUrl(), ApiEndpoints.defaultBaseUrl);
    },
  );

  testWidgets('settings page rejects missing scheme server url', (
    tester,
  ) async {
    final repository = _FakeSettingsRepository();
    await repository.setBaseUrl('http://custom.example:9000');
    final initialBaseUrl = await repository.getBaseUrl();

    await tester.pumpWidget(
      _wrap(
        const SettingsPage(),
        repository: repository,
        initialBaseUrl: initialBaseUrl,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'api.example.com:8000');
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    expect(await repository.getBaseUrl(), 'http://custom.example:9000');
    expect(
      find.textContaining('HTTP:// OR HTTPS:// SERVER URL'),
      findsOneWidget,
    );
    expect(find.text('SERVER URL SAVED'), findsNothing);
  });

  testWidgets('settings page rejects non-http server url', (tester) async {
    final repository = _FakeSettingsRepository();
    await repository.setBaseUrl('http://custom.example:9000');
    final initialBaseUrl = await repository.getBaseUrl();

    await tester.pumpWidget(
      _wrap(
        const SettingsPage(),
        repository: repository,
        initialBaseUrl: initialBaseUrl,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ftp://api.example.com');
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    expect(await repository.getBaseUrl(), 'http://custom.example:9000');
    expect(
      find.textContaining('HTTP:// OR HTTPS:// SERVER URL'),
      findsOneWidget,
    );
    expect(find.text('SERVER URL SAVED'), findsNothing);
  });

  testWidgets('settings page loads remote low-score alert default from API', (
    tester,
  ) async {
    final notificationSettingsRepository = _FakeNotificationSettingsRepository(
      subscriptionNotifyDefault: false,
    );

    await tester.pumpWidget(
      _wrap(
        const SettingsPage(),
        notificationSettingsRepository: notificationSettingsRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SUBSCRIPTION LOW-SCORE ALERTS'), findsOneWidget);

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.last.value, isFalse);
    expect(notificationSettingsRepository.getCalls, greaterThanOrEqualTo(1));
  });

  testWidgets(
    'settings page explains that in-app notifications do not hide low-score alerts',
    (tester) async {
      await tester.pumpWidget(_wrap(const SettingsPage()));
      await tester.pumpAndSettle();

      expect(
        find.text('Turning this off does not hide subscription low-score alerts.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'settings page updates remote low-score alert default with apply_to_existing',
    (tester) async {
      final notificationSettingsRepository =
          _FakeNotificationSettingsRepository(subscriptionNotifyDefault: true);

      await tester.pumpWidget(
        _wrap(
          const SettingsPage(),
          notificationSettingsRepository: notificationSettingsRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('SUBSCRIPTION LOW-SCORE ALERTS'));
      await tester.tap(find.text('SUBSCRIPTION LOW-SCORE ALERTS'));
      await tester.pumpAndSettle();

      expect(notificationSettingsRepository.updateCalls, 1);
      expect(
        notificationSettingsRepository.lastSubscriptionNotifyDefault,
        isFalse,
      );
      expect(notificationSettingsRepository.lastApplyToExisting, isTrue);

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.last.value, isFalse);
    },
  );

  testWidgets(
    'settings page blocks unsupported Android cleartext server url',
    (tester) async {
      final repository = _FakeSettingsRepository();
      await repository.setBaseUrl('http://custom.example:9000');
      final initialBaseUrl = await repository.getBaseUrl();

      await tester.pumpWidget(
        _wrap(
          const SettingsPage(),
          repository: repository,
          initialBaseUrl: initialBaseUrl,
          baseUrlTargetPlatform: TargetPlatform.android,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'http://api.example.com:8000',
      );
      await tester.tap(find.byIcon(Icons.save_outlined));
      await tester.pumpAndSettle();

      expect(await repository.getBaseUrl(), 'http://custom.example:9000');
      expect(find.textContaining('10.0.2.2'), findsOneWidget);
      expect(find.text('SERVER URL SAVED'), findsNothing);
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.android,
    }),
  );
}
