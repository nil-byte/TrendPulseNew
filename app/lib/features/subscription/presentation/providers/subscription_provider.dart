import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/features/settings/presentation/providers/api_client_provider.dart';
import 'package:trendpulse/features/subscription/data/subscription_model.dart';
import 'package:trendpulse/features/subscription/data/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return SubscriptionRepository(apiClient: api);
});

final subscriptionListProvider = AutoDisposeFutureProvider<List<Subscription>>((
  ref,
) async {
  final repository = ref.watch(subscriptionRepositoryProvider);
  return repository.getSubscriptions();
});

final subscriptionDetailProvider =
    AutoDisposeFutureProvider.family<Subscription, String>((ref, id) async {
      final repository = ref.watch(subscriptionRepositoryProvider);
      return repository.getSubscription(id);
    });

final subscriptionTasksProvider =
    AutoDisposeFutureProvider.family<List<SubscriptionTask>, String>((
      ref,
      id,
    ) async {
      final repository = ref.watch(subscriptionRepositoryProvider);
      return repository.getSubscriptionTasks(id);
    });
