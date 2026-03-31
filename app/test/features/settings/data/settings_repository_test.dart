import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendpulse/core/network/api_client.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: ApiEndpoints.defaultBaseUrl);

  String? lastGetPath;
  String? lastPutPath;
  Object? lastPutData;
  Map<String, dynamic> getResponseData = const {'report_language': 'zh'};
  Map<String, dynamic> putResponseData = const {'report_language': 'en'};

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    lastGetPath = path;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: getResponseData as T,
    );
  }

  @override
  Future<Response<T>> put<T>(String path, {Object? data}) async {
    lastPutPath = path;
    lastPutData = data;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: putResponseData as T,
    );
  }
}

void main() {
  late SettingsRepository repository;
  late _FakeApiClient apiClient;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = SettingsRepository();
    apiClient = _FakeApiClient();
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

  test('getReportLanguage reads report_language from API', () async {
    repository = SettingsRepository(apiClient: apiClient);

    final reportLanguage = await repository.getReportLanguage();

    expect(apiClient.lastGetPath, ApiEndpoints.reportLanguage);
    expect(reportLanguage, 'zh');
  });

  test('getReportLanguage throws when report_language is missing', () async {
    repository = SettingsRepository(apiClient: apiClient);
    apiClient.getResponseData = const {};

    expect(repository.getReportLanguage(), throwsFormatException);
  });

  test('setReportLanguage sends report_language to API', () async {
    repository = SettingsRepository(apiClient: apiClient);

    final reportLanguage = await repository.setReportLanguage('en');

    expect(apiClient.lastPutPath, ApiEndpoints.reportLanguage);
    expect(apiClient.lastPutData, {'report_language': 'en'});
    expect(reportLanguage, 'en');
  });

  test('setReportLanguage throws when response report_language is missing', () async {
    repository = SettingsRepository(apiClient: apiClient);
    apiClient.putResponseData = const {};

    expect(repository.setReportLanguage('en'), throwsFormatException);
  });
}
