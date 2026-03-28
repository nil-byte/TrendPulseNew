import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color seed = Color(0xFF2563EB);

  // Light theme
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);

  // Dark theme
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);

  // Sentiment
  static const Color positive = Color(0xFF10B981);
  static const Color negative = Color(0xFFEF4444);
  static const Color neutral = Color(0xFF94A3B8);

  // Source platforms
  static const Color reddit = Color(0xFFFF4500);
  static const Color youtube = Color(0xFFFF0000);
  static const Color x = Color(0xFF1DA1F2);
}
