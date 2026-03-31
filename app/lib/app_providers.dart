import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/network/api_client.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';

/// Shared [ApiClient] driven by [baseUrlProvider] so all repositories pick up
/// the configured API base URL from Settings.
final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  return ApiClient(baseUrl: baseUrl);
});

/// Monotonic counter that any feature can bump after mutating task data
/// (create, delete, etc.). Providers that display task lists should
/// [ref.watch] this so they rebuild automatically.
final taskMutationSignalProvider = StateProvider<int>((ref) => 0);
