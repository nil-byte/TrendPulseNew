import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trendpulse/app_providers.dart';
import 'package:trendpulse/core/network/api_client.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';
import 'package:trendpulse/features/feed/data/feed_repository_provider.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockSettingsRepository mockRepo;

  setUp(() {
    mockRepo = _MockSettingsRepository();
    when(() => mockRepo.setBaseUrl(any())).thenAnswer((_) async {});
  });

  test(
    'apiClientProvider uses preloaded base URL synchronously at startup',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockRepo),
          initialBaseUrlProvider.overrideWithValue(
            'http://configured.example:9999',
          ),
          baseUrlTargetPlatformProvider.overrideWithValue(TargetPlatform.iOS),
          baseUrlIsWebProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(baseUrlProvider), 'http://configured.example:9999');
      expect(
        container.read(apiClientProvider).baseUrl,
        'http://configured.example:9999',
      );
      verifyNever(() => mockRepo.getBaseUrl());
    },
  );

  test('apiClientProvider rebuilds when base URL changes', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(mockRepo),
        initialBaseUrlProvider.overrideWithValue('http://first:8000'),
        baseUrlTargetPlatformProvider.overrideWithValue(TargetPlatform.iOS),
        baseUrlIsWebProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    final first = container.read(apiClientProvider);
    expect(first.baseUrl, 'http://first:8000');

    await container
        .read(baseUrlProvider.notifier)
        .setBaseUrl('http://second:9000');

    final second = container.read(apiClientProvider);
    expect(second.baseUrl, 'http://second:9000');
    expect(identical(first, second), isFalse);
  });

  test(
    'feedRepositoryProvider uses ApiClient aligned with preloaded baseUrlProvider',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockRepo),
          initialBaseUrlProvider.overrideWithValue(
            'http://feed-test.example:8080',
          ),
          baseUrlTargetPlatformProvider.overrideWithValue(TargetPlatform.iOS),
          baseUrlIsWebProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      final feedRepo = container.read(feedRepositoryProvider);
      final api = container.read(apiClientProvider);
      expect(feedRepo.apiClientBaseUrl, api.baseUrl);
      expect(feedRepo.apiClientBaseUrl, 'http://feed-test.example:8080');
    },
  );

  test('ApiClient keeps localhost unchanged on Android by default', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final client = ApiClient(baseUrl: 'http://localhost:8000');

    expect(client.baseUrl, 'http://localhost:8000');
  });

  test('ApiClient keeps 127.0.0.1 unchanged on Android by default', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final client = ApiClient(baseUrl: 'http://127.0.0.1:9000');

    expect(client.baseUrl, 'http://127.0.0.1:9000');
  });

  test('baseUrlProvider keeps explicit localhost default on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(mockRepo),
        initialBaseUrlProvider.overrideWithValue(ApiEndpoints.defaultBaseUrl),
        baseUrlTargetPlatformProvider.overrideWithValue(TargetPlatform.android),
        baseUrlIsWebProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(apiClientProvider).baseUrl,
      ApiEndpoints.defaultBaseUrl,
    );
  });

  test(
    'baseUrlProvider falls back to default for unsupported Android cleartext initial URL',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockRepo),
          initialBaseUrlProvider.overrideWithValue(
            'http://api.example.com:8000',
          ),
          baseUrlTargetPlatformProvider.overrideWithValue(
            TargetPlatform.android,
          ),
          baseUrlIsWebProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(baseUrlProvider), ApiEndpoints.defaultBaseUrl);
      expect(
        container.read(apiClientProvider).baseUrl,
        ApiEndpoints.defaultBaseUrl,
      );
    },
  );

  test(
    'baseUrlProvider keeps supported Android local cleartext initial URL',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockRepo),
          initialBaseUrlProvider.overrideWithValue('http://10.0.2.2:8000'),
          baseUrlTargetPlatformProvider.overrideWithValue(
            TargetPlatform.android,
          ),
          baseUrlIsWebProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(baseUrlProvider), 'http://10.0.2.2:8000');
    },
  );

  test(
    'baseUrlProvider falls back to default for invalid initial URL scheme',
    () {
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockRepo),
          initialBaseUrlProvider.overrideWithValue('ftp://api.example.com'),
          baseUrlTargetPlatformProvider.overrideWithValue(TargetPlatform.iOS),
          baseUrlIsWebProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(baseUrlProvider), ApiEndpoints.defaultBaseUrl);
    },
  );

  test(
    'baseUrlProvider keeps default state and preserves blank input for repository fallback',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockRepo),
          initialBaseUrlProvider.overrideWithValue(
            'http://configured.example:9000',
          ),
          baseUrlTargetPlatformProvider.overrideWithValue(TargetPlatform.iOS),
          baseUrlIsWebProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      await container.read(baseUrlProvider.notifier).setBaseUrl('   ');

      expect(container.read(baseUrlProvider), ApiEndpoints.defaultBaseUrl);
      verify(() => mockRepo.setBaseUrl('')).called(1);
    },
  );

  test(
    'baseUrlProvider clears persisted override for invalid input URL',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockRepo),
          initialBaseUrlProvider.overrideWithValue(
            'http://configured.example:9000',
          ),
          baseUrlTargetPlatformProvider.overrideWithValue(TargetPlatform.iOS),
          baseUrlIsWebProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(baseUrlProvider.notifier)
          .setBaseUrl('ftp://invalid');

      expect(container.read(baseUrlProvider), ApiEndpoints.defaultBaseUrl);
      verify(() => mockRepo.setBaseUrl('')).called(1);
    },
  );

  test(
    'baseUrlProvider clears persisted override for unsupported Android cleartext input',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockRepo),
          initialBaseUrlProvider.overrideWithValue(
            'http://configured.example:9000',
          ),
          baseUrlTargetPlatformProvider.overrideWithValue(
            TargetPlatform.android,
          ),
          baseUrlIsWebProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(baseUrlProvider.notifier)
          .setBaseUrl('http://api.example.com:8000');

      expect(container.read(baseUrlProvider), ApiEndpoints.defaultBaseUrl);
      verify(() => mockRepo.setBaseUrl('')).called(1);
    },
  );
}
