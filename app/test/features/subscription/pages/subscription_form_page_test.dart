import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/core/theme/app_typography.dart';
import 'package:trendpulse/features/subscription/presentation/pages/subscription_form_page.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.light,
      home: child,
    ),
  );
}

void main() {
  testWidgets(
    'subscription form defers segmented, switch, and primary button styling to theme',
    (tester) async {
      await tester.pumpWidget(_wrap(const SubscriptionFormPage()));
      await tester.pumpAndSettle();

      final segmentedButtons = tester.widgetList<SegmentedButton<String>>(
        find.byWidgetPredicate((widget) => widget is SegmentedButton<String>),
      );
      expect(segmentedButtons, isNotEmpty);
      for (final segmented in segmentedButtons) {
        expect(segmented.style, isNull);
      }

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.thumbColor, isNull);
      expect(toggle.trackColor, isNull);
      expect(toggle.trackOutlineColor, isNull);

      final filledButton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(filledButton.style, isNull);
    },
  );

  testWidgets('subscription source chips avoid harsh onSurface fill', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SubscriptionFormPage()));
    await tester.pumpAndSettle();

    final pageContext = tester.element(find.byType(SubscriptionFormPage));
    final theme = Theme.of(pageContext);
    final chip = tester.widget<FilterChip>(find.byType(FilterChip).first);

    expect(chip.selectedColor, isNot(theme.colorScheme.onSurface));
  });

  testWidgets('subscription source chips inherit the bundled editorial sans family', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SubscriptionFormPage()));
    await tester.pumpAndSettle();

    final chip = tester.widget<FilterChip>(find.byType(FilterChip).first);

    expect(chip.labelStyle?.fontFamily, AppTypography.editorialSansFamily);
  });

  testWidgets('subscription keyword field uses softened filled borders', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SubscriptionFormPage()));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField).first);
    final decoration = field.decoration!;
    final border = decoration.enabledBorder! as OutlineInputBorder;

    expect(decoration.filled, isTrue);
    expect(border.borderRadius, isNot(BorderRadius.zero));
  });

  testWidgets('subscription form localizes editorial labels in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const SubscriptionFormPage(), locale: const Locale('zh')),
    );
    await tester.pumpAndSettle();

    expect(find.text('新建条目'), findsOneWidget);
    expect(find.text('关注主题'), findsOneWidget);
    expect(find.text('输入关键词...'), findsOneWidget);
    expect(find.text('频率'), findsOneWidget);
    expect(find.text('每小时'), findsOneWidget);
    expect(find.text('每6小时'), findsOneWidget);
    expect(find.text('1H'), findsNothing);
    expect(find.text('NEW ENTRY'), findsNothing);
    expect(find.text('SUBJECT OF INQUIRY'), findsNothing);
  });
}
