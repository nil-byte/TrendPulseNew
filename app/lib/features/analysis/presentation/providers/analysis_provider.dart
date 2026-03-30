import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/app_providers.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/data/analysis_repository.dart';

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AnalysisRepository(apiClient: api);
});

final sourceAvailabilityProvider =
    FutureProvider<List<AnalysisSourceAvailability>>((ref) async {
      final repo = ref.watch(analysisRepositoryProvider);
      return repo.getSourceAvailability();
    });
