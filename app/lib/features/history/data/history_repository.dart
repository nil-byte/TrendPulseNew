import 'package:trendpulse/core/network/api_client.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';

import 'history_item.dart';

class HistoryRepository {
  final ApiClient _apiClient;

  HistoryRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<HistoryItem>> getHistory() async {
    final response = await _apiClient.get(ApiEndpoints.tasks);
    final data = response.data as Map<String, dynamic>;
    final tasks = (data['tasks'] as List)
        .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return tasks;
  }

  Future<void> deleteTask(String taskId) async {
    await _apiClient.delete(ApiEndpoints.taskById(taskId));
  }
}
