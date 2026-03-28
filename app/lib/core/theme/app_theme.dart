import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light => _buildTheme(
    colorScheme: _lightColorScheme,
    trendPulseColors: TrendPulseColors.light,
    isDark: false,
  );

  static ThemeData get dark => _buildTheme(
    colorScheme: _darkColorScheme,
    trendPulseColors: TrendPulseColors.dark,
    isDark: true,
  );

  static ColorScheme get _lightColorScheme => ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.copper,
    onPrimary: const Color(0xFFFFF8F4),
    primaryContainer: AppColors.copperContainer,
    onPrimaryContainer: const Color(0xFF4B2C21),
    secondary: AppColors.brass,
    onSecondary: const Color(0xFFFFF8F4),
    secondaryContainer: AppColors.brassContainer,
    onSecondaryContainer: const Color(0xFF3C2F24),
    tertiary: AppColors.moss,
    onTertiary: const Color(0xFFF6F2EA),
    surface: AppColors.lightPaper,
    onSurface: AppColors.lightInk,
    surfaceContainerLowest: AppColors.lightLinen,
    surfaceContainerLow: const Color(0xFFF9F4EC),
    surfaceContainer: const Color(0xFFF5EBDF),
    surfaceContainerHigh: const Color(0xFFF1E4D6),
    surfaceContainerHighest: const Color(0xFFE9D8C7),
    surfaceDim: const Color(0xFFECE1D4),
    surfaceBright: const Color(0xFFFFFCF8),
    outline: AppColors.lightOutline,
    outlineVariant: AppColors.lightOutlineVariant,
    shadow: const Color(0x14000000),
    surfaceTint: AppColors.copper,
  );

  static ColorScheme get _darkColorScheme => ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.copperLight,
    onPrimary: const Color(0xFF2C1810),
    primaryContainer: AppColors.copperContainerDark,
    onPrimaryContainer: const Color(0xFFF9DDCF),
    secondary: AppColors.brassDark,
    onSecondary: const Color(0xFF2A2016),
    secondaryContainer: AppColors.brassContainerDark,
    onSecondaryContainer: const Color(0xFFEAD9BF),
    tertiary: AppColors.mossDark,
    onTertiary: const Color(0xFF1B2315),
    surface: AppColors.darkWalnut,
    onSurface: AppColors.darkIvory,
    surfaceContainerLowest: AppColors.darkEspresso,
    surfaceContainerLow: const Color(0xFF201917),
    surfaceContainer: const Color(0xFF2A221E),
    surfaceContainerHigh: const Color(0xFF312825),
    surfaceContainerHighest: const Color(0xFF3B302C),
    surfaceDim: const Color(0xFF16100E),
    surfaceBright: const Color(0xFF382F2B),
    outline: AppColors.darkOutline,
    outlineVariant: AppColors.darkOutlineVariant,
    shadow: const Color(0x33000000),
    surfaceTint: AppColors.copperLight,
  );

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required TrendPulseColors trendPulseColors,
    required bool isDark,
  }) {
    final textTheme = AppTypography.textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );
    final controlRadius = BorderRadius.circular(AppSpacing.borderRadiusXl + 4);
    final fieldRadius = BorderRadius.circular(AppSpacing.borderRadiusXl);
    final cardRadius = BorderRadius.circular(AppSpacing.borderRadiusXl + 2);
    final chipShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusFull),
      side: BorderSide(color: colorScheme.outline),
    );
    final baseLabelStyle =
        textTheme.labelLarge ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      canvasColor: colorScheme.surface,
      extensions: [trendPulseColors],
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: colorScheme.outline,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: colorScheme.outline, width: 1),
        ),
        color: colorScheme.surface,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarThemeData(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          fontFamily: textTheme.displayLarge?.fontFamily,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer.withValues(
          alpha: isDark ? 0.92 : 1,
        ),
        indicatorShape: RoundedRectangleBorder(borderRadius: controlRadius),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.68),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: isSelected ? 0.45 : 0.25,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.52),
        ),
        border: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colorScheme.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colorScheme.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 18,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.surfaceContainerHigh,
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: baseLabelStyle.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.25,
          ),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: baseLabelStyle.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.25,
          ),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          side: BorderSide(color: colorScheme.outline, width: 1),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primaryContainer;
            }
            return colorScheme.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onPrimaryContainer;
            }
            return colorScheme.onSurface;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return BorderSide(
              color: selected
                  ? colorScheme.primary.withValues(alpha: isDark ? 0.7 : 0.45)
                  : colorScheme.outline,
              width: selected ? 1.2 : 1,
            );
          }),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
          ),
          textStyle: WidgetStatePropertyAll(
            baseLabelStyle.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
            ),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return colorScheme.primary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.hovered)) {
              return colorScheme.primary.withValues(alpha: 0.05);
            }
            return null;
          }),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: controlRadius),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.24);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.outlineVariant.withValues(alpha: 0.36);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: isDark ? 0.72 : 0.42);
          }
          return colorScheme.outline;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: colorScheme.surfaceContainerLow,
        labelStyle: baseLabelStyle.copyWith(
          color: colorScheme.onSurface,
          letterSpacing: 0.2,
        ),
        secondaryLabelStyle: baseLabelStyle.copyWith(
          color: colorScheme.onPrimaryContainer,
          letterSpacing: 0.2,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        side: BorderSide(color: colorScheme.outline, width: 1),
        shape: chipShape,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        actionTextColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: controlRadius,
          side: BorderSide(color: colorScheme.outline),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.outlineVariant,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        trackHeight: 3,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.outlineVariant,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
    );
  }
}
