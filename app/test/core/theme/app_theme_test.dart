import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/core/theme/app_colors.dart';

void main() {
  group('AppTheme', () {
    test('light theme uses Material 3', () {
      final theme = AppTheme.light;
      expect(theme.useMaterial3, isTrue);
    });

    test('light theme has correct brightness', () {
      expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    });

    test('dark theme has correct brightness', () {
      expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
    });

    test('card theme has 0.5 elevation', () {
      expect(AppTheme.light.cardTheme.elevation, 0.5);
      expect(AppTheme.dark.cardTheme.elevation, 0.5);
    });

    test('app bar has zero elevation', () {
      expect(AppTheme.light.appBarTheme.elevation, 0);
      expect(AppTheme.dark.appBarTheme.elevation, 0);
    });

    test('divider is ultra-thin', () {
      expect(AppTheme.light.dividerTheme.thickness, 0.5);
    });

    test('seed color is blue', () {
      expect(AppColors.seed, const Color(0xFF2196F3));
    });
  });

  group('TrendPulseColors ThemeExtension', () {
    test('light theme registers TrendPulseColors', () {
      final colors = AppTheme.light.extension<TrendPulseColors>();
      expect(colors, isNotNull);
      expect(colors, equals(TrendPulseColors.light));
    });

    test('dark theme registers TrendPulseColors', () {
      final colors = AppTheme.dark.extension<TrendPulseColors>();
      expect(colors, isNotNull);
      expect(colors, equals(TrendPulseColors.dark));
    });

    test('light TrendPulseColors provides expected sentiment colors', () {
      const colors = TrendPulseColors.light;
      expect(colors.positive, const Color(0xFF10B981));
      expect(colors.negative, const Color(0xFFEF4444));
      expect(colors.neutral, const Color(0xFF94A3B8));
    });

    test('light TrendPulseColors provides expected source colors', () {
      const colors = TrendPulseColors.light;
      expect(colors.reddit, const Color(0xFFFF4500));
      expect(colors.youtube, const Color(0xFFFF0000));
      expect(colors.xPlatform, const Color(0xFF1DA1F2));
    });

    test('trendPulseColors extension getter works', () {
      final colors = AppTheme.light.trendPulseColors;
      expect(colors.positive, const Color(0xFF10B981));
    });
  });
}
