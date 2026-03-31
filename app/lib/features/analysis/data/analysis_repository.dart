import 'package:trendpulse/core/network/api_client.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';

import 'analysis_model.dart';

class AnalysisRepository {
  final ApiClient _apiClient;

  AnalysisRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<AnalysisTask> createTask({
    required String keyword,
    String contentLanguage = 'en',
    required String reportLanguage,
    int maxItems = 50,
    List<String> sources = const ['reddit', 'youtube', 'x'],
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.tasks,
      data: {
        'keyword': keyword,
        'content_language': contentLanguage,
        'report_language': reportLanguage,
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

  Future<List<AnalysisSourceAvailability>> getSourceAvailability() async {
    final response = await _apiClient.get(ApiEndpoints.sourceAvailability);
    final data = response.data as Map<String, dynamic>;
    final sources = (data['sources'] as List<dynamic>? ?? const []);
    return sources
        .map(
          (item) => AnalysisSourceAvailability.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<AnalysisReport> getReport(String taskId) async {
    final response = await _apiClient.get(ApiEndpoints.taskReport(taskId));
    return AnalysisReport.fromJson(response.data as Map<String, dynamic>);
  }
}
