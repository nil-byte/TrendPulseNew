import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';

void main() {
  late SettingsRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = SettingsRepository();
  });

  test(
    'getBaseUrl falls back to configured default when stored value is blank',
    () async {
      SharedPreferences.setMockInitialValues({'settings_base_url': '   '});
      repository = SettingsRepository();

      expect(await repository.getBaseUrl(), ApiEndpoints.defaultBaseUrl);
    },
  );

  test('setBaseUrl trims whitespace before persisting', () async {
    await repository.setBaseUrl('  http://example.com:8080  ');

    expect(await repository.getBaseUrl(), 'http://example.com:8080');
  });

  test('setBaseUrl clears persisted value when given blank input', () async {
    await repository.setBaseUrl('http://example.com:8080');
    await repository.setBaseUrl('   ');

    expect(await repository.getBaseUrl(), ApiEndpoints.defaultBaseUrl);
  });
}
