import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';
import 'package:trendpulse/main.dart' as app;

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockSettingsRepository mockRepo;

  setUp(() {
    mockRepo = _MockSettingsRepository();
    when(() => mockRepo.getInAppNotify()).thenAnswer((_) async => true);
    when(() => mockRepo.getLanguage()).thenAnswer((_) async => 'en');
    when(
      () => mockRepo.getCachedReportLanguage(
        fallbackLanguage: any(named: 'fallbackLanguage'),
      ),
    ).thenAnswer(
      (invocation) async =>
          invocation.namedArguments[#fallbackLanguage] as String,
    );
    when(() => mockRepo.getThemeMode()).thenAnswer((_) async => 'light');
    when(
      () => mockRepo.getReportLanguage(baseUrl: any(named: 'baseUrl')),
    ).thenAnswer((_) async => 'en');
    when(
      () => mockRepo.setReportLanguage(any(), baseUrl: any(named: 'baseUrl')),
    ).thenAnswer((invocation) async => invocation.positionalArguments[0] as String);
  });

  test(
    'buildAppOverrides keeps bootstrapped in-app notify value without a second repo reload',
    () async {
      var inAppNotifyCalls = 0;
      when(() => mockRepo.getBaseUrl()).thenAnswer((_) async => '');
      when(
        () => mockRepo.getInAppNotify(),
      ).thenAnswer((_) async => inAppNotifyCalls++ == 0 ? false : true);

      final overrides = await app.buildAppOverrides(
        settingsRepository: mockRepo,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(inAppNotifyProvider), isFalse);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(inAppNotifyProvider), isFalse);
      verify(() => mockRepo.getInAppNotify()).called(1);
    },
  );

  test(
    'buildAppOverrides preloads persisted base URL for synchronous provider startup',
    () async {
      when(
        () => mockRepo.getBaseUrl(),
      ).thenAnswer((_) async => 'http://bootstrap.example:7000');

      final overrides = await app.buildAppOverrides(
        settingsRepository: mockRepo,
        targetPlatform: TargetPlatform.iOS,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(baseUrlProvider), 'http://bootstrap.example:7000');
      expect(
        container.read(apiClientProvider).baseUrl,
        'http://bootstrap.example:7000',
      );
      verify(() => mockRepo.getBaseUrl()).called(1);
    },
  );

  test(
    'buildAppOverrides preloads persisted language for synchronous provider startup',
    () async {
      when(() => mockRepo.getBaseUrl()).thenAnswer((_) async => '');
      when(() => mockRepo.getLanguage()).thenAnswer((_) async => 'zh');
      when(
        () => mockRepo.getCachedReportLanguage(
          fallbackLanguage: any(named: 'fallbackLanguage'),
        ),
      ).thenAnswer((_) async => 'zh');
      when(
        () => mockRepo.getReportLanguage(baseUrl: any(named: 'baseUrl')),
      ).thenAnswer((_) async => 'zh');

      final overrides = await app.buildAppOverrides(
        settingsRepository: mockRepo,
        targetPlatform: TargetPlatform.iOS,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(defaultLanguageProvider), 'zh');

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(defaultLanguageProvider), 'zh');
      verify(() => mockRepo.getLanguage()).called(1);
    },
  );

  test(
    'buildAppOverrides preloads cached report language for synchronous startup',
    () async {
      when(() => mockRepo.getBaseUrl()).thenAnswer((_) async => '');
      when(() => mockRepo.getLanguage()).thenAnswer((_) async => 'en');
      when(
        () => mockRepo.getCachedReportLanguage(
          fallbackLanguage: any(named: 'fallbackLanguage'),
        ),
      ).thenAnswer((_) async => 'zh');
      when(
        () => mockRepo.getReportLanguage(baseUrl: any(named: 'baseUrl')),
      ).thenAnswer((_) async => 'zh');

      final overrides = await app.buildAppOverrides(
        settingsRepository: mockRepo,
        targetPlatform: TargetPlatform.iOS,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(defaultReportLanguageProvider), 'zh');

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(defaultReportLanguageProvider), 'zh');
      verify(
        () => mockRepo.getCachedReportLanguage(fallbackLanguage: 'en'),
      ).called(1);
    },
  );

  test(
    'buildAppOverrides preloads persisted theme mode for synchronous provider startup',
    () async {
      when(() => mockRepo.getBaseUrl()).thenAnswer((_) async => '');
      when(() => mockRepo.getThemeMode()).thenAnswer((_) async => 'dark');

      final overrides = await app.buildAppOverrides(
        settingsRepository: mockRepo,
        targetPlatform: TargetPlatform.iOS,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      verify(() => mockRepo.getThemeMode()).called(1);
    },
  );

  test(
    'buildAppOverrides falls back to default base URL when repo returns blank',
    () async {
      when(() => mockRepo.getBaseUrl()).thenAnswer((_) async => '   ');

      final overrides = await app.buildAppOverrides(
        settingsRepository: mockRepo,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(baseUrlProvider), ApiEndpoints.defaultBaseUrl);
    },
  );

  test(
    'buildAppOverrides falls back to default base URL for unsupported Android cleartext HTTP',
    () async {
      when(
        () => mockRepo.getBaseUrl(),
      ).thenAnswer((_) async => 'http://api.example.com:8000');

      final overrides = await app.buildAppOverrides(
        settingsRepository: mockRepo,
        targetPlatform: TargetPlatform.android,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(baseUrlProvider), ApiEndpoints.defaultBaseUrl);
      expect(
        container.read(apiClientProvider).baseUrl,
        ApiEndpoints.defaultBaseUrl,
      );
    },
  );

  test('buildAppOverrides keeps https base URL on Android', () async {
    when(
      () => mockRepo.getBaseUrl(),
    ).thenAnswer((_) async => 'https://api.example.com');

    final overrides = await app.buildAppOverrides(
      settingsRepository: mockRepo,
      targetPlatform: TargetPlatform.android,
    );
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    expect(container.read(baseUrlProvider), 'https://api.example.com');
  });

  test(
    'buildAppOverrides falls back to default base URL for invalid stored scheme',
    () async {
      when(
        () => mockRepo.getBaseUrl(),
      ).thenAnswer((_) async => 'ftp://api.example.com');

      final overrides = await app.buildAppOverrides(
        settingsRepository: mockRepo,
        targetPlatform: TargetPlatform.iOS,
      );
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(baseUrlProvider), ApiEndpoints.defaultBaseUrl);
    },
  );
}
