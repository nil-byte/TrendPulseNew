import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color seed = Color(0xFF2196F3);
}

@immutable
class TrendPulseColors extends ThemeExtension<TrendPulseColors> {
  const TrendPulseColors({
    required this.positive,
    required this.negative,
    required this.neutral,
    required this.reddit,
    required this.youtube,
    required this.xPlatform,
    required this.surfaceHighlight,
    required this.subtleBackground,
  });

  final Color positive;
  final Color negative;
  final Color neutral;
  final Color reddit;
  final Color youtube;
  final Color xPlatform;
  final Color surfaceHighlight;
  final Color subtleBackground;

  static const light = TrendPulseColors(
    positive: Color(0xFF10B981),
    negative: Color(0xFFEF4444),
    neutral: Color(0xFF94A3B8),
    reddit: Color(0xFFFF4500),
    youtube: Color(0xFFFF0000),
    xPlatform: Color(0xFF1DA1F2),
    surfaceHighlight: Color(0xFFF1F5F9),
    subtleBackground: Color(0xFFF8FAFC),
  );

  static const dark = TrendPulseColors(
    positive: Color(0xFF34D399),
    negative: Color(0xFFF87171),
    neutral: Color(0xFF94A3B8),
    reddit: Color(0xFFFF6633),
    youtube: Color(0xFFFF4444),
    xPlatform: Color(0xFF60C5F7),
    surfaceHighlight: Color(0xFF334155),
    subtleBackground: Color(0xFF0F172A),
  );

  @override
  TrendPulseColors copyWith({
    Color? positive,
    Color? negative,
    Color? neutral,
    Color? reddit,
    Color? youtube,
    Color? xPlatform,
    Color? surfaceHighlight,
    Color? subtleBackground,
  }) {
    return TrendPulseColors(
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      neutral: neutral ?? this.neutral,
      reddit: reddit ?? this.reddit,
      youtube: youtube ?? this.youtube,
      xPlatform: xPlatform ?? this.xPlatform,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      subtleBackground: subtleBackground ?? this.subtleBackground,
    );
  }

  @override
  TrendPulseColors lerp(TrendPulseColors? other, double t) {
    if (other is! TrendPulseColors) return this;
    return TrendPulseColors(
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      reddit: Color.lerp(reddit, other.reddit, t)!,
      youtube: Color.lerp(youtube, other.youtube, t)!,
      xPlatform: Color.lerp(xPlatform, other.xPlatform, t)!,
      surfaceHighlight: Color.lerp(
        surfaceHighlight,
        other.surfaceHighlight,
        t,
      )!,
      subtleBackground: Color.lerp(
        subtleBackground,
        other.subtleBackground,
        t,
      )!,
    );
  }
}

extension TrendPulseColorsExtension on ThemeData {
  TrendPulseColors get trendPulseColors =>
      extension<TrendPulseColors>() ?? TrendPulseColors.light;
}
