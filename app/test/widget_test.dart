import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/app.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/data/analysis_repository.dart';
import 'package:trendpulse/features/analysis/presentation/providers/analysis_provider.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';

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

class _FakeSettingsRepository extends SettingsRepository {
  @override
  Future<String> getLanguage() async => 'en';

  @override
  Future<String> getReportLanguage({String? baseUrl}) async => 'en';

  @override
  Future<String> setReportLanguage(String language, {String? baseUrl}) async =>
      language;
}

void main() {
  testWidgets('App renders Analysis tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analysisRepositoryProvider.overrideWithValue(_FakeAnalysisRepository()),
          settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepository()),
          initialLanguageProvider.overrideWithValue('en'),
          initialLanguagePreloadedProvider.overrideWithValue(true),
        ],
        child: const TrendPulseApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ANALYSIS'), findsWidgets);
  });
}
