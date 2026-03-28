import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/network/api_client.dart';

import 'settings_provider.dart';

/// Shared [ApiClient] driven by [baseUrlProvider] so network calls use the
/// configured API base URL from Settings.
final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(baseUrlProvider);
  return ApiClient(baseUrl: baseUrl);
});
