import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/network/api_client.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';
import 'package:trendpulse/features/settings/data/notification_settings_repository.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: ApiEndpoints.defaultBaseUrl);

  String? lastGetPath;
  String? lastPutPath;
  Object? lastPutData;
  Map<String, dynamic> getResponseData = const {
    'subscription_notify_default': true,
  };
  Map<String, dynamic> putResponseData = const {
    'subscription_notify_default': false,
  };

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
  late _FakeApiClient apiClient;
  late NotificationSettingsRepository repository;

  setUp(() {
    apiClient = _FakeApiClient();
    repository = NotificationSettingsRepository(apiClient: apiClient);
  });

  test('getNotificationSettings reads subscription default from API', () async {
    final settings = await repository.getNotificationSettings();

    expect(apiClient.lastGetPath, ApiEndpoints.notificationSettings);
    expect(settings.subscriptionNotifyDefault, isTrue);
  });

  test('updateNotificationSettings sends apply_to_existing to API', () async {
    final settings = await repository.updateNotificationSettings(
      subscriptionNotifyDefault: false,
      applyToExisting: true,
    );

    expect(apiClient.lastPutPath, ApiEndpoints.notificationSettings);
    expect(apiClient.lastPutData, {
      'subscription_notify_default': false,
      'apply_to_existing': true,
    });
    expect(settings.subscriptionNotifyDefault, isFalse);
  });
}
