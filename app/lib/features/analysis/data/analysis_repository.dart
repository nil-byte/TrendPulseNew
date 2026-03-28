import 'package:trendpulse/core/network/api_client.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';

import 'analysis_model.dart';

class AnalysisRepository {
  final ApiClient _apiClient;

  AnalysisRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<AnalysisTask> createTask({
    required String keyword,
    String language = 'en',
    int maxItems = 50,
    List<String> sources = const ['reddit', 'youtube', 'x'],
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.tasks,
      data: {
        'keyword': keyword,
        'language': language,
        'max_items': maxItems,
        'sources': sources,
      },
    );
    return AnalysisTask.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AnalysisTask> getTaskStatus(String taskId) async {
    final response = await _apiClient.get(ApiEndpoints.taskById(taskId));
    return AnalysisTask.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AnalysisReport> getReport(String taskId) async {
    final response = await _apiClient.get(ApiEndpoints.taskReport(taskId));
    return AnalysisReport.fromJson(response.data as Map<String, dynamic>);
  }
}
