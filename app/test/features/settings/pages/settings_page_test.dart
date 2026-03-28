import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';
import 'package:trendpulse/features/settings/presentation/pages/settings_page.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class _FakeSettingsRepository extends SettingsRepository {
  String _baseUrl = 'http://localhost:8000';
  String _language = 'en';
  int _maxItems = 50;
  String _themeMode = 'system';
  bool _inAppNotify = true;
  bool _subscriptionNotify = true;

  @override
  Future<String> getBaseUrl() async => _baseUrl;

  @override
  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
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

  @override
  Future<bool> getSubscriptionNotify() async => _subscriptionNotify;

  @override
  Future<void> setSubscriptionNotify(bool value) async {
    _subscriptionNotify = value;
  }
}

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  PackageInfo.setMockInitialValues(
    appName: 'TrendPulse',
    packageName: 'trendpulse',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );

  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepository()),
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
      find.byWidgetPredicate((widget) => widget is SegmentedButton<String>).first,
    );
    expect(segmented.style, isNull);

    final switches = tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    for (final switchTile in switches) {
      expect(switchTile.activeThumbColor, isNull);
      expect(switchTile.activeTrackColor, isNull);
      expect(switchTile.inactiveThumbColor, isNull);
      expect(switchTile.inactiveTrackColor, isNull);
      expect(switchTile.trackOutlineColor, isNull);
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

  testWidgets('settings page url field uses softened input borders', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SettingsPage()));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    final decoration = field.decoration!;
    final border = decoration.enabledBorder! as OutlineInputBorder;

    expect(border.borderRadius, isNot(BorderRadius.zero));
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
}
