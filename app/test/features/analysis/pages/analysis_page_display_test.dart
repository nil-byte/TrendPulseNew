import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/analysis/presentation/pages/analysis_page.dart';

import 'analysis_page_test_helpers.dart';

void main() {
  testWidgets('shows guidance when search is tapped without a keyword', (
    tester,
  ) async {
    await tester.pumpWidget(wrapAnalysisPage(const AnalysisPage()));

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Enter a topic before starting analysis.'), findsOneWidget);
  });

  testWidgets(
    'analysis X source chip uses a readable dark foreground in dark theme',
    (tester) async {
      await tester.pumpWidget(
        wrapAnalysisPage(const AnalysisPage(), theme: AppTheme.dark),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded).first);
      await tester.pumpAndSettle();

      final xChip = tester.widgetList<FilterChip>(find.byType(FilterChip)).last;

      expect(xChip.selected, isTrue);
      expect(xChip.labelStyle?.color, AppColors.lightInk);
    },
  );

  testWidgets(
    'analysis source chips keep accessible tap targets and toggle semantics',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(wrapAnalysisPage(const AnalysisPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded).first);
      await tester.pumpAndSettle();

      final redditChip = find.widgetWithText(FilterChip, 'Reddit');
      expect(redditChip, findsOneWidget);
      expect(tester.getSize(redditChip).height, greaterThanOrEqualTo(48));

      expect(
        tester.getSemantics(redditChip),
        matchesSemantics(
          label: 'Reddit',
          hasTapAction: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          isButton: true,
          isFocusable: true,
        ),
      );

      semanticsHandle.dispose();
    },
  );
}
