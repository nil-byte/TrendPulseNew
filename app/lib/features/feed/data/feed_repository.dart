import 'package:trendpulse/core/network/api_client.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';

import 'feed_model.dart';

class FeedRepository {
  final ApiClient _apiClient;

  FeedRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  /// Effective API base URL (mirrors injected [ApiClient]).
  String get apiClientBaseUrl => _apiClient.baseUrl;

  Future<List<SourcePost>> getPosts(
    String taskId, {
    String? sourceFilter,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.taskPosts(taskId),
      queryParameters: sourceFilter != null ? {'source': sourceFilter} : null,
    );
    final data = response.data as Map<String, dynamic>;
    return (data['posts'] as List)
        .map((e) => SourcePost.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
