import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/app_providers.dart';
import 'package:trendpulse/features/analysis/data/analysis_repository.dart';

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AnalysisRepository(apiClient: api);
});
