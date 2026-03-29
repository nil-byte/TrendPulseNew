import 'package:flutter/material.dart';

/// Editorial hierarchy is expressed through surface steps, not drop shadows.
abstract final class AppElevations {
  static const double flat = 0;

  static Color level0(ColorScheme colorScheme) => colorScheme.surface;

  static Color level1(ColorScheme colorScheme, bool isDark) {
    return isDark ? colorScheme.surfaceContainerHigh : level0(colorScheme);
  }
}
