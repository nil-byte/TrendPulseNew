import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_typography.dart';

void main() {
  group('AppTypography', () {
    testWidgets('body styles favor readable long-form sizing', (tester) async {
      final textTheme = AppTypography.textTheme;

      expect(textTheme.bodyLarge?.fontSize, 16);
      expect(textTheme.bodyLarge?.height, 1.65);
      expect(textTheme.bodyMedium?.fontSize, 15);
      expect(textTheme.bodyMedium?.height, 1.55);
      expect(textTheme.bodySmall?.fontSize, 13.5);
      expect(textTheme.bodySmall?.height, 1.5);
    });

    testWidgets('label styles no longer drop below readable comfort floor', (
      tester,
    ) async {
      final textTheme = AppTypography.textTheme;

      expect(textTheme.labelLarge?.fontSize, 15);
      expect(textTheme.labelMedium?.fontSize, 13.5);
      expect(textTheme.labelSmall?.fontSize, 13);
      expect(textTheme.labelSmall?.letterSpacing, 0.35);
    });

    testWidgets('display and title hierarchy keeps editorial structure', (
      tester,
    ) async {
      final textTheme = AppTypography.textTheme;

      expect(textTheme.displayLarge?.fontSize, 57);
      expect(textTheme.headlineSmall?.fontSize, 24);
      expect(textTheme.titleLarge?.fontSize, 22);
      expect(textTheme.titleMedium?.fontSize, 18);
      expect(textTheme.titleSmall?.fontSize, 15);
      expect(
        textTheme.displayLarge?.fontFamily,
        AppTypography.editorialSerifFamily,
      );
      expect(textTheme.titleLarge?.fontFamily, AppTypography.editorialSerifFamily);
    });

    testWidgets('text theme uses bundled editorial font families', (tester) async {
      final textTheme = AppTypography.textTheme;

      expect(
        textTheme.bodyLarge?.fontFamily,
        AppTypography.editorialSansFamily,
      );
      expect(
        textTheme.bodyMedium?.fontFamily,
        AppTypography.editorialSansFamily,
      );
      expect(
        textTheme.labelLarge?.fontFamily,
        AppTypography.editorialSansFamily,
      );
      expect(
        textTheme.titleMedium?.fontFamily,
        AppTypography.editorialSansFamily,
      );
      expect(
        textTheme.displayLarge?.fontFamily,
        AppTypography.editorialSerifFamily,
      );
      expect(
        textTheme.headlineSmall?.fontFamily,
        AppTypography.editorialSerifFamily,
      );
      expect(
        textTheme.titleLarge?.fontFamily,
        AppTypography.editorialSerifFamily,
      );
    });

    testWidgets('caption style supports dense metadata and CJK fallbacks', (
      tester,
    ) async {
      final style = AppTypography.caption(AppTypography.textTheme);

      expect(style.fontFamily, AppTypography.editorialSansFamily);
      expect(style.fontSize, 11.5);
      expect(style.fontWeight, FontWeight.w500);
      expect(style.letterSpacing, 0.4);
      expect(style.height, 1.35);
      expect(
        style.fontFamilyFallback,
        containsAll(['PingFang SC', 'Noto Sans SC', 'Microsoft YaHei']),
      );
    });

    testWidgets('editorial eyebrow style reduces fatigue for uppercase labels', (
      tester,
    ) async {
      final style = AppTypography.editorialEyebrow(AppTypography.textTheme);

      expect(style.fontFamily, AppTypography.editorialSansFamily);
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, 0.8);
      expect(style.height, 1.32);
    });

    testWidgets('editorial eyebrow falls back to bundled sans family', (
      tester,
    ) async {
      final style = AppTypography.editorialEyebrow(const TextTheme());

      expect(style.fontFamily, AppTypography.editorialSansFamily);
    });
  });
}
