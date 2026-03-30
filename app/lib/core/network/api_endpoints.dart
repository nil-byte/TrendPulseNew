abstract final class ApiEndpoints {
  /// Single default for dev API base URL (settings + ApiClient fallback).
  ///
  /// Keep this value explicit. Android emulator access should be configured
  /// explicitly via `10.0.2.2` or `adb reverse`, rather than inferred here.
  static const String defaultBaseUrl = 'http://localhost:8000';

  static const String baseUrl = defaultBaseUrl;
  static const String apiPrefix = '/api/v1';

  // Settings
  static const String notificationSettings =
      '$apiPrefix/settings/notifications';
  static const String sourceAvailability = '$apiPrefix/settings/sources';

  // Tasks
  static const String tasks = '$apiPrefix/tasks';
  static String taskById(String id) => '$apiPrefix/tasks/$id';
  static String taskReport(String id) => '$apiPrefix/tasks/$id/report';
  static String taskPosts(String id) => '$apiPrefix/tasks/$id/posts';

  // Subscriptions
  static const String subscriptions = '$apiPrefix/subscriptions';
  static String subscriptionById(String id) => '$apiPrefix/subscriptions/$id';
  static String subscriptionTasks(String id) =>
      '$apiPrefix/subscriptions/$id/tasks';
  static String subscriptionAlertsRead(String id) =>
      '$apiPrefix/subscriptions/$id/alerts/read';
  static String subscriptionRunNow(String id) =>
      '$apiPrefix/subscriptions/$id/tasks';
}
