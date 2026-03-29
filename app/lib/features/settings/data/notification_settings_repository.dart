import 'package:trendpulse/core/network/api_client.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';

import 'notification_settings.dart';

class NotificationSettingsRepository {
  final ApiClient _apiClient;

  NotificationSettingsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<NotificationSettings> getNotificationSettings() async {
    final response = await _apiClient.get(ApiEndpoints.notificationSettings);
    final data = response.data as Map<String, dynamic>;
    return NotificationSettings.fromJson(data);
  }

  Future<NotificationSettings> updateNotificationSettings({
    required bool subscriptionNotifyDefault,
    required bool applyToExisting,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.notificationSettings,
      data: {
        'subscription_notify_default': subscriptionNotifyDefault,
        'apply_to_existing': applyToExisting,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return NotificationSettings.fromJson(data);
  }
}
