import 'package:trendpulse/core/network/api_client.dart';
import 'package:trendpulse/core/network/api_endpoints.dart';

import 'subscription_request.dart';
import 'subscription_model.dart';

class SubscriptionRepository {
  final ApiClient _apiClient;

  SubscriptionRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<Subscription>> getSubscriptions() async {
    final response = await _apiClient.get(ApiEndpoints.subscriptions);
    final data = response.data as Map<String, dynamic>;
    final list = data['subscriptions'] as List? ?? data['items'] as List? ?? [];
    return list
        .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Subscription> getSubscription(String id) async {
    final response = await _apiClient.get(ApiEndpoints.subscriptionById(id));
    final data = response.data as Map<String, dynamic>;
    return Subscription.fromJson(data);
  }

  Future<Subscription> createSubscription(
    SubscriptionUpsertRequest request,
  ) async {
    final response = await _apiClient.post(
      ApiEndpoints.subscriptions,
      data: request.toJson(),
    );
    final data = response.data as Map<String, dynamic>;
    return Subscription.fromJson(data);
  }

  Future<Subscription> updateSubscription(
    String id,
    SubscriptionUpsertRequest request,
  ) async {
    final response = await _apiClient.put(
      ApiEndpoints.subscriptionById(id),
      data: request.toJson(),
    );
    final data = response.data as Map<String, dynamic>;
    return Subscription.fromJson(data);
  }

  Future<void> deleteSubscription(String id) async {
    await _apiClient.delete(ApiEndpoints.subscriptionById(id));
  }

  Future<List<SubscriptionTask>> getSubscriptionTasks(String id) async {
    final response = await _apiClient.get(ApiEndpoints.subscriptionTasks(id));
    final data = response.data as Map<String, dynamic>;
    final list = data['tasks'] as List? ?? [];
    return list
        .map((e) => SubscriptionTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> runSubscriptionNow(String id) async {
    await _apiClient.post(ApiEndpoints.subscriptionRunNow(id));
  }

  Future<void> toggleActive(String id, {required bool isActive}) async {
    await _apiClient.put(
      ApiEndpoints.subscriptionById(id),
      data: {'is_active': isActive},
    );
  }
}
