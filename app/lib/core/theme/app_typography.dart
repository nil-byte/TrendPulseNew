import 'package:flutter/material.dart';

/// TrendPulse Type Scale — aligned to Material Design 3 (2024)
///
/// MD3 baseline (sp)           → TrendPulse value
/// displayLarge   57           → 52  (editorial display, serif)
/// displayMedium  45           → 40
/// displaySmall   36           → 32
/// headlineLarge  32           → 28
/// headlineMedium 28           → 24
/// headlineSmall  24           → 20
/// titleLarge     22           → 20
/// titleMedium    16           → 15
/// titleSmall     14           → 13
/// bodyLarge      16           → 15
/// bodyMedium     14           → 13
/// bodySmall      12           → 11.5
/// labelLarge     14           → 13
/// labelMedium    12           → 11.5
/// labelSmall     11           → 10.5
abstract final class AppTypography {
  static const String editorialSansFamily = 'EditorialSans';
  static const String editorialSerifFamily = 'EditorialSerif';

  static const List<String> _sansFallback = [
    'PingFang SC',
    'Noto Sans SC',
    'Microsoft YaHei',
  ];

  /// Eyebrow / overline label — uppercase section headers, tight tracking
  static TextStyle editorialEyebrow(TextTheme textTheme) {
    return (textTheme.labelMedium ?? const TextStyle()).copyWith(
      fontFamily: editorialSansFamily,
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      height: 1.32,
    );
  }

  /// Caption — secondary meta text beneath cards / images
  static TextStyle caption(TextTheme textTheme) {
    return (textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontFamily: editorialSansFamily,
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      height: 1.35,
      fontFamilyFallback: _sansFallback,
    );
  }

  /// Data number — percentages, counts, scores; tabular figures, equal-width
  static TextStyle dataNumber(
    TextTheme t, {
    double fontSize = 24,
    FontWeight weight = FontWeight.w800,
  }) {
    return (t.displaySmall ?? const TextStyle()).copyWith(
      fontFamily: editorialSansFamily,
      fontSize: fontSize,
      fontWeight: weight,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: -0.5,
      height: 1.1,
    );
  }

  static TextTheme get textTheme {
    final baseTheme = Typography.material2021().black.apply(
      fontFamily: editorialSansFamily,
    );

    return baseTheme.copyWith(
      // ── Display ────────────────────────────────────────────────────────────
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 52,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.12,
        fontFeatures: const [FontFeature('lnum')],
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.16,
        fontFeatures: const [FontFeature('lnum')],
      ),
      displaySmall: baseTheme.displaySmall?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.22,
        fontFeatures: const [FontFeature('lnum')],
      ),
      // ── Headline ───────────────────────────────────────────────────────────
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.25,
        fontFeatures: const [FontFeature('lnum')],
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.29,
        fontFeatures: const [FontFeature('lnum')],
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.33,
        fontFeatures: const [FontFeature('lnum')],
      ),
      // ── Title ──────────────────────────────────────────────────────────────
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.27,
        fontFeatures: const [FontFeature('lnum')],
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.12,
        height: 1.4,
        fontFeatures: const [FontFeature('lnum')],
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.43,
        fontFeatures: const [FontFeature('lnum')],
      ),
      // ── Body ───────────────────────────────────────────────────────────────
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.6,
        fontFamilyFallback: _sansFallback,
        fontFeatures: const [FontFeature('lnum')],
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.18,
        height: 1.5,
        fontFamilyFallback: _sansFallback,
        fontFeatures: const [FontFeature('lnum')],
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.45,
        fontFamilyFallback: _sansFallback,
        fontFeatures: const [FontFeature('lnum')],
      ),
      // ── Label ──────────────────────────────────────────────────────────────
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.25,
        height: 1.38,
        fontFeatures: const [FontFeature('lnum')],
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        height: 1.34,
        fontFeatures: const [FontFeature('lnum')],
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
        height: 1.35,
        fontFeatures: const [FontFeature('lnum')],
      ),
    );
  }
}
