import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const String editorialSansFamily = 'EditorialSans';
  static const String editorialSerifFamily = 'EditorialSerif';

  static const List<String> _sansFallback = [
    'PingFang SC',
    'Noto Sans SC',
    'Microsoft YaHei',
  ];

  static TextStyle editorialEyebrow(TextTheme textTheme) {
    return (textTheme.labelMedium ?? const TextStyle()).copyWith(
      fontFamily: editorialSansFamily,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      height: 1.32,
    );
  }

  static TextStyle caption(TextTheme textTheme) {
    return (textTheme.labelSmall ?? const TextStyle()).copyWith(
      fontFamily: editorialSansFamily,
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.4,
      height: 1.35,
      fontFamilyFallback: _sansFallback,
    );
  }

  /// 数据数字专用样式（百分比、参与数、分数等）
  /// 强制使用 EditorialSans + tabularFigures，确保数字等宽对齐
  static TextStyle dataNumber(
    TextTheme t, {
    double fontSize = 28,
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
    // Warm editorial: UI uses a readable sans, display moments keep the serif.
    final baseTheme = Typography.material2021().black.apply(
      fontFamily: editorialSansFamily,
    );

    return baseTheme.copyWith(
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 57,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.12,
      ),
      displayMedium: baseTheme.displayMedium?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 45,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.16,
      ),
      displaySmall: baseTheme.displaySmall?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.22,
      ),
      headlineLarge: baseTheme.headlineLarge?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineMedium: baseTheme.headlineMedium?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.29,
      ),
      headlineSmall: baseTheme.headlineSmall?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.33,
      ),
      titleLarge: baseTheme.titleLarge?.copyWith(
        fontFamily: editorialSerifFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.27,
      ),
      titleMedium: baseTheme.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.12,
        height: 1.44,
      ),
      titleSmall: baseTheme.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.47,
      ),
      bodyLarge: baseTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.65,
        fontFamilyFallback: _sansFallback,
      ),
      bodyMedium: baseTheme.bodyMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.18,
        height: 1.55,
        fontFamilyFallback: _sansFallback,
      ),
      bodySmall: baseTheme.bodySmall?.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        height: 1.5,
        fontFamilyFallback: _sansFallback,
      ),
      labelLarge: baseTheme.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.25,
        height: 1.42,
      ),
      labelMedium: baseTheme.labelMedium?.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        height: 1.38,
      ),
      labelSmall: baseTheme.labelSmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
        height: 1.4,
      ),
    );
  }
}
