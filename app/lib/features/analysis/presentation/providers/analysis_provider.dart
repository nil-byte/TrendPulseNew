import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/features/analysis/data/analysis_repository.dart';

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  return AnalysisRepository();
});
