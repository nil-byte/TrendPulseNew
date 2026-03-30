import 'package:flutter/material.dart';
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
  testWidgets('App renders with navigation bar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analysisRepositoryProvider.overrideWithValue(_FakeAnalysisRepository()),
        ],
        child: const TrendPulseApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('ANALYSIS'), findsWidgets);
    expect(find.text('HISTORY'), findsWidgets);
    expect(find.text('SUBSCRIBE'), findsWidgets);
    expect(find.text('SETTINGS'), findsWidgets);
  });
}
