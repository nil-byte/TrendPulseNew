import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/features/analysis/data/analysis_repository.dart';
import 'package:trendpulse/features/settings/presentation/providers/api_client_provider.dart';

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AnalysisRepository(apiClient: api);
});
