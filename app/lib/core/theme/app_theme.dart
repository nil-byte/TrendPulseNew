import 'package:flutter/material.dart';

import 'app_borders.dart';
import 'app_colors.dart';
import 'app_elevations.dart';
import 'app_opacity.dart';
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
    onPrimary: AppColors.cream,
    primaryContainer: AppColors.copperContainer,
    onPrimaryContainer: const Color(0xFF4B2C21),
    secondary: AppColors.brass,
    onSecondary: AppColors.cream,
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
    onPrimary: AppColors.cream,
    primaryContainer: AppColors.copperContainerDark,
    onPrimaryContainer: const Color(0xFFF9DDCF),
    secondary: AppColors.brassDark,
    onSecondary: AppColors.cream,
    secondaryContainer: AppColors.brassContainerDark,
    onSecondaryContainer: const Color(0xFFEAD9BF),
    tertiary: AppColors.mossDark,
    onTertiary: const Color(0xFF1B2315),
    surface: AppColors.darkWalnut,
    onSurface: AppColors.darkIvory,
    surfaceContainerLowest: AppColors.darkEspresso,
    surfaceContainerLow: const Color(0xFF302D2A),
    surfaceContainer: const Color(0xFF3A3633),
    surfaceContainerHigh: AppColors.darkSurfaceRaised,
    surfaceContainerHighest: const Color(0xFF524D47),
    surfaceDim: const Color(0xFF252220),
    surfaceBright: const Color(0xFF504B46),
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
    const editorialRadius = BorderRadius.zero;
    final chipShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
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
        elevation: AppElevations.flat,
        shape: RoundedRectangleBorder(
          borderRadius: editorialRadius,
          side: BorderSide(color: colorScheme.outline, width: AppBorders.thin),
        ),
        color: AppElevations.level1(colorScheme, isDark),
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
        indicatorShape: const RoundedRectangleBorder(borderRadius: editorialRadius),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: AppOpacity.secondary),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: isSelected ? 0.45 : 0.25,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: AppOpacity.muted),
        ),
        border: OutlineInputBorder(
          borderRadius: editorialRadius,
          borderSide: BorderSide(color: colorScheme.outline, width: AppBorders.thin),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: editorialRadius,
          borderSide: BorderSide(color: colorScheme.outline, width: AppBorders.thin),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: editorialRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: AppBorders.medium),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.surfaceContainerHigh,
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: AppOpacity.disabled),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: baseLabelStyle.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.25,
          ),
          shape: const RoundedRectangleBorder(borderRadius: editorialRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          disabledForegroundColor: colorScheme.onSurface.withValues(alpha: AppOpacity.disabled),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: baseLabelStyle.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.25,
          ),
          shape: const RoundedRectangleBorder(borderRadius: editorialRadius),
          side: BorderSide(color: colorScheme.outline, width: AppBorders.thin),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary;
            }
            return colorScheme.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.cream;
            }
            return colorScheme.onSurface;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return BorderSide(
              color: selected
                  ? colorScheme.primary
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
              return colorScheme.primary.withValues(alpha: AppOpacity.soft);
            }
            if (states.contains(WidgetState.hovered)) {
              return colorScheme.primary.withValues(alpha: AppOpacity.hover);
            }
            return null;
          }),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: editorialRadius),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: AppOpacity.disabled);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.outlineVariant.withValues(alpha: AppOpacity.disabled);
          }
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
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
        side: BorderSide(color: colorScheme.outline, width: AppBorders.thin),
        shape: chipShape,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.surface,
        ),
        actionTextColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.outlineVariant,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: AppOpacity.overlay),
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
