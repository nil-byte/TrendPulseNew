import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trendpulse/app_providers.dart';
import 'package:trendpulse/features/feed/data/feed_repository_provider.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

Future<void> _waitForBaseUrl(
  ProviderContainer container,
  String expected,
) async {
  for (var i = 0; i < 200; i++) {
    if (container.read(baseUrlProvider) == expected) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail(
    'Timeout waiting for baseUrl $expected, '
    'got ${container.read(baseUrlProvider)}',
  );
}

void main() {
  late _MockSettingsRepository mockRepo;

  setUp(() {
    mockRepo = _MockSettingsRepository();
    when(() => mockRepo.setBaseUrl(any())).thenAnswer((_) async {});
  });

  test(
    'apiClientProvider tracks baseUrlProvider after persisted URL loads',
    () async {
      when(
        () => mockRepo.getBaseUrl(),
      ).thenAnswer((_) async => 'http://configured.example:9999');

      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      await _waitForBaseUrl(container, 'http://configured.example:9999');

      final client = container.read(apiClientProvider);
      expect(
        client.baseUrl,
        container.read(baseUrlProvider),
        reason: 'ApiClient must use the same base URL as Settings',
      );
    },
  );

  test('apiClientProvider rebuilds when base URL changes', () async {
    when(
      () => mockRepo.getBaseUrl(),
    ).thenAnswer((_) async => 'http://first:8000');

    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(mockRepo)],
    );
    addTearDown(container.dispose);

    await _waitForBaseUrl(container, 'http://first:8000');

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
    'feedRepositoryProvider uses ApiClient aligned with baseUrlProvider',
    () async {
      when(
        () => mockRepo.getBaseUrl(),
      ).thenAnswer((_) async => 'http://feed-test.example:8080');

      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      await _waitForBaseUrl(container, 'http://feed-test.example:8080');

      final feedRepo = container.read(feedRepositoryProvider);
      final api = container.read(apiClientProvider);
      expect(feedRepo.apiClientBaseUrl, api.baseUrl);
      expect(feedRepo.apiClientBaseUrl, 'http://feed-test.example:8080');
    },
  );
}
