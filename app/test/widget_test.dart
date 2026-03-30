import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/app.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/data/analysis_repository.dart';
import 'package:trendpulse/features/analysis/presentation/providers/analysis_provider.dart';

class _FakeAnalysisRepository extends AnalysisRepository {
  @override
  Future<List<AnalysisSourceAvailability>> getSourceAvailability() async {
    return const [
      AnalysisSourceAvailability(
        source: 'reddit',
        status: 'available',
        isAvailable: true,
      ),
      AnalysisSourceAvailability(
        source: 'youtube',
        status: 'available',
        isAvailable: true,
      ),
      AnalysisSourceAvailability(
        source: 'x',
        status: 'available',
        isAvailable: true,
      ),
    ];
  }
}

void main() {
  testWidgets('App renders Analysis tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analysisRepositoryProvider.overrideWithValue(_FakeAnalysisRepository()),
        ],
        child: const TrendPulseApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ANALYSIS'), findsWidgets);
  });
}
