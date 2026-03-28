abstract final class ApiEndpoints {
  /// Single default for dev API base URL (settings + ApiClient fallback).
  static const String defaultBaseUrl = 'http://localhost:8000';

  static const String baseUrl = defaultBaseUrl;
  static const String apiPrefix = '/api/v1';

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
  static String subscriptionRunNow(String id) =>
      '$apiPrefix/subscriptions/$id/tasks';
}
