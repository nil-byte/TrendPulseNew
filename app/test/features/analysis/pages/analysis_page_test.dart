import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/analysis/presentation/pages/analysis_page.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: theme ?? AppTheme.light,
      home: child,
    ),
  );
}

void main() {
  testWidgets('shows guidance when search is tapped without a keyword', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AnalysisPage()));

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Enter a topic before starting analysis.'), findsOneWidget);
  });

  testWidgets(
    'analysis X source chip uses a readable dark foreground in dark theme',
    (tester) async {
      await tester.pumpWidget(_wrap(const AnalysisPage(), theme: AppTheme.dark));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded).first);
      await tester.pumpAndSettle();

      final xChip = tester.widgetList<FilterChip>(find.byType(FilterChip)).last;

      expect(xChip.selected, isTrue);
      expect(xChip.labelStyle?.color, AppColors.lightInk);
    },
  );
}
