abstract final class ApiEndpoints {
  static const String baseUrl = 'http://localhost:8000';
  static const String apiPrefix = '/api/v1';

  // Tasks
  static const String tasks = '$apiPrefix/tasks';
  static String taskById(String id) => '$apiPrefix/tasks/$id';
  static String taskReport(String id) => '$apiPrefix/tasks/$id/report';
  static String taskPosts(String id) => '$apiPrefix/tasks/$id/posts';

  // Settings
  static const String settings = '$apiPrefix/settings';
}
