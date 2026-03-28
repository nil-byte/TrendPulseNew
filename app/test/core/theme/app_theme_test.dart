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

    test('card theme has zero elevation', () {
      expect(AppTheme.light.cardTheme.elevation, 0);
      expect(AppTheme.dark.cardTheme.elevation, 0);
    });

    test('app bar has zero elevation', () {
      expect(AppTheme.light.appBarTheme.elevation, 0);
      expect(AppTheme.dark.appBarTheme.elevation, 0);
    });

    test('divider is ultra-thin', () {
      expect(AppTheme.light.dividerTheme.thickness, 0.5);
    });

    test('seed color is blue', () {
      expect(AppColors.seed, const Color(0xFF2563EB));
    });
  });
}
