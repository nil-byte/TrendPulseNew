import 'package:flutter/material.dart';

abstract final class AppColors {
  // Warm editorial foundation
  static const Color seed = Color(0xFFB86A4F);

  static const Color copper = Color(0xFFB86A4F);
  static const Color copperLight = Color(0xFFD89A78);
  static const Color copperContainer = Color(0xFFE9C8B8);
  static const Color copperContainerDark = Color(0xFF6A4536);

  static const Color brass = Color(0xFF9E7A52);
  static const Color brassDark = Color(0xFFC4A26C);
  static const Color brassContainer = Color(0xFFE5D6BC);
  static const Color brassContainerDark = Color(0xFF564330);

  static const Color moss = Color(0xFF6F7C5F);
  static const Color mossDark = Color(0xFFA1B38A);

  static const Color lightPaper = Color(0xFFFFFBF6);
  static const Color lightLinen = Color(0xFFF7F0E6);
  static const Color lightSurfaceRaised = Color(0xFFF0E4D5);
  static const Color lightInk = Color(0xFF2F2925);
  static const Color lightInkMuted = Color(0xFF6F6257);
  static const Color lightOutline = Color(0xFFD6C5B4);
  static const Color lightOutlineVariant = Color(0xFFE7DBCF);

  static const Color darkEspresso = Color(0xFF181310);
  static const Color darkWalnut = Color(0xFF241D1A);
  static const Color darkSurfaceRaised = Color(0xFF332924);
  static const Color darkIvory = Color(0xFFF3E8DA);
  static const Color darkIvoryMuted = Color(0xFFCDBFAF);
  static const Color darkOutline = Color(0xFF655548);
  static const Color darkOutlineVariant = Color(0xFF4C4037);
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

  // Warm editorial light
  static const light = TrendPulseColors(
    positive: AppColors.moss,
    negative: Color(0xFFB85C42),
    neutral: Color(0xFF8D7B6A),
    reddit: Color(0xFFCC784C),
    youtube: Color(0xFFC96B62),
    xPlatform: Color(0xFF5F534A),
    surfaceHighlight: AppColors.lightSurfaceRaised,
    subtleBackground: AppColors.lightLinen,
  );

  // Warm editorial dark
  static const dark = TrendPulseColors(
    positive: AppColors.mossDark,
    negative: Color(0xFFE39A7C),
    neutral: Color(0xFFBCAA9B),
    reddit: Color(0xFFE0A06E),
    youtube: Color(0xFFD98C84),
    xPlatform: Color(0xFFE3D7C9),
    surfaceHighlight: AppColors.darkSurfaceRaised,
    subtleBackground: AppColors.darkEspresso,
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
      extension<TrendPulseColors>() ??
      (brightness == Brightness.dark
          ? TrendPulseColors.dark
          : TrendPulseColors.light);
}
