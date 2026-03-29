import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/core/theme/app_colors.dart';

void main() {
  group('AppTheme', () {
    testWidgets('light theme uses Material 3', (tester) async {
      final theme = AppTheme.light;
      expect(theme.useMaterial3, isTrue);
    });

    testWidgets('light theme has correct brightness', (tester) async {
      expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    });

    testWidgets('dark theme has correct brightness', (tester) async {
      expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
    });

    testWidgets('card theme is flat for editorial style', (tester) async {
      expect(AppTheme.light.cardTheme.elevation, 0);
      expect(AppTheme.dark.cardTheme.elevation, 0);
    });

    testWidgets('dark cards use raised warm surfaces instead of base canvas', (
      tester,
    ) async {
      expect(AppTheme.light.cardTheme.color, const Color(0xFFFFFBF6));
      expect(AppTheme.dark.cardTheme.color, const Color(0xFF423D38));
    });

    testWidgets('app bar has zero elevation', (tester) async {
      expect(AppTheme.light.appBarTheme.elevation, 0);
      expect(AppTheme.dark.appBarTheme.elevation, 0);
    });

    testWidgets('divider uses editorial line weight', (tester) async {
      expect(AppTheme.light.dividerTheme.thickness, 1.0);
      expect(AppTheme.dark.dividerTheme.thickness, 1.0);
    });

    testWidgets('seed color uses warm copper tone', (tester) async {
      expect(AppColors.seed, const Color(0xFFB86A4F));
    });

    testWidgets('light theme uses warm editorial surfaces', (tester) async {
      final colorScheme = AppTheme.light.colorScheme;

      expect(colorScheme.primary, const Color(0xFFB86A4F));
      expect(colorScheme.surface, const Color(0xFFFFFBF6));
      expect(colorScheme.surfaceContainerLowest, const Color(0xFFF7F0E6));
      expect(colorScheme.outline, const Color(0xFFD6C5B4));
    });

    testWidgets('dark theme uses softened warm dark surfaces', (tester) async {
      final colorScheme = AppTheme.dark.colorScheme;

      expect(colorScheme.primary, const Color(0xFFD89A78));
      expect(colorScheme.surface, const Color(0xFF343130));
      expect(colorScheme.surfaceContainerLowest, const Color(0xFF2B2826));
      expect(colorScheme.outline, const Color(0xFF6B6058));
    });

    testWidgets('dark theme shadow stays softened instead of opaque black', (
      tester,
    ) async {
      expect(AppTheme.dark.colorScheme.shadow, const Color(0x33000000));
    });

    testWidgets('filled buttons use warm primary backgrounds', (tester) async {
      final lightStyle = AppTheme.light.filledButtonTheme.style!;
      final darkStyle = AppTheme.dark.filledButtonTheme.style!;

      expect(
        lightStyle.backgroundColor?.resolve(<WidgetState>{}),
        const Color(0xFFB86A4F),
      );
      expect(
        darkStyle.backgroundColor?.resolve(<WidgetState>{}),
        const Color(0xFFD89A78),
      );
    });

    testWidgets('filled buttons keep a readable light foreground in both themes', (
      tester,
    ) async {
      final lightStyle = AppTheme.light.filledButtonTheme.style!;
      final darkStyle = AppTheme.dark.filledButtonTheme.style!;

      expect(
        lightStyle.foregroundColor?.resolve(<WidgetState>{}),
        const Color(0xFFFFF8F4),
      );
      expect(
        darkStyle.foregroundColor?.resolve(<WidgetState>{}),
        const Color(0xFFFFF8F4),
      );
    });

    testWidgets(
      'segmented buttons use primary fill and readable light foreground when selected',
      (tester) async {
        final lightStyle = AppTheme.light.segmentedButtonTheme.style!;
        final darkStyle = AppTheme.dark.segmentedButtonTheme.style!;
        const selectedState = <WidgetState>{WidgetState.selected};

        expect(
          lightStyle.backgroundColor?.resolve(selectedState),
          AppTheme.light.colorScheme.primary,
        );
        expect(
          darkStyle.backgroundColor?.resolve(selectedState),
          AppTheme.dark.colorScheme.primary,
        );
        expect(
          lightStyle.foregroundColor?.resolve(selectedState),
          const Color(0xFFFFF8F4),
        );
        expect(
          darkStyle.foregroundColor?.resolve(selectedState),
          const Color(0xFFFFF8F4),
        );
      },
    );

    testWidgets('chip theme uses tinted selected backgrounds', (tester) async {
      expect(
        AppTheme.light.chipTheme.selectedColor,
        const Color(0xFFE9C8B8),
      );
      expect(
        AppTheme.dark.chipTheme.selectedColor,
        const Color(0xFF6A4536),
      );
    });
  });

  group('TrendPulseColors ThemeExtension', () {
    testWidgets('light theme registers TrendPulseColors', (tester) async {
      final colors = AppTheme.light.extension<TrendPulseColors>();
      expect(colors, isNotNull);
      expect(colors, equals(TrendPulseColors.light));
    });

    testWidgets('dark theme registers TrendPulseColors', (tester) async {
      final colors = AppTheme.dark.extension<TrendPulseColors>();
      expect(colors, isNotNull);
      expect(colors, equals(TrendPulseColors.dark));
    });

    testWidgets(
      'light TrendPulseColors provides expected sentiment colors',
      (tester) async {
      const colors = TrendPulseColors.light;
      expect(colors.positive, const Color(0xFF6F7C5F));
      expect(colors.negative, const Color(0xFFB85C42));
      expect(colors.neutral, const Color(0xFF8D7B6A));
    });

    testWidgets('light TrendPulseColors provides expected source colors', (tester) async {
      const colors = TrendPulseColors.light;
      expect(colors.reddit, const Color(0xFFFF4500));
      expect(colors.youtube, const Color(0xFFFF0033));
      expect(colors.xPlatform, const Color(0xFF14171A));
    });

    testWidgets(
      'dark TrendPulseColors provides softened warm accents',
      (tester) async {
        const colors = TrendPulseColors.dark;

        expect(colors.positive, const Color(0xFFA1B38A));
        expect(colors.negative, const Color(0xFFD4917A));
        expect(colors.neutral, const Color(0xFFB8A99A));
        expect(colors.reddit, const Color(0xFFFF6D3A));
        expect(colors.youtube, const Color(0xFFFF4D5E));
        expect(colors.xPlatform, const Color(0xFFE7E0D8));
        expect(colors.surfaceHighlight, const Color(0xFF423D38));
        expect(colors.subtleBackground, const Color(0xFF2B2826));
    });

    testWidgets('trendPulseColors extension getter works', (tester) async {
      final colors = AppTheme.light.trendPulseColors;
      expect(colors.positive, const Color(0xFF6F7C5F));
    });

    testWidgets(
      'trendPulseColors falls back by brightness when extension is absent',
      (tester) async {
        final lightTheme = ThemeData(brightness: Brightness.light);
        final darkTheme = ThemeData(brightness: Brightness.dark);

        expect(lightTheme.trendPulseColors, TrendPulseColors.light);
        expect(darkTheme.trendPulseColors, TrendPulseColors.dark);
      },
    );
  });
}
