import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:trendpulse/core/theme/app_borders.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';

class ShimmerLoading extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool showOutline;
  final bool cardSkeleton;

  const ShimmerLoading({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 120,
    this.borderRadius = 0,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    this.showOutline = true,
    this.cardSkeleton = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outlineColor = colorScheme.onSurface.withValues(
      alpha: isDark ? AppOpacity.low : AppOpacity.soft,
    );

    return Shimmer.fromColors(
      baseColor: isDark
          ? colorScheme.surfaceContainerHighest.withValues(
              alpha: AppOpacity.loadingBase,
            )
          : colorScheme.surfaceContainerHighest.withValues(
              alpha: AppOpacity.divider,
            ),
      highlightColor: isDark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: AppOpacity.focus)
          : colorScheme.surfaceContainerHighest.withValues(alpha: AppOpacity.quiet),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, __) => cardSkeleton
            ? _CardSkeleton(
                outlineColor: outlineColor,
                colorScheme: colorScheme,
                itemHeight: itemHeight,
                borderRadius: borderRadius,
                showOutline: showOutline,
              )
            : Container(
                height: itemHeight,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: showOutline
                      ? Border.all(color: outlineColor, width: AppBorders.medium)
                      : null,
                ),
              ),
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  final Color outlineColor;
  final ColorScheme colorScheme;
  final double itemHeight;
  final double borderRadius;
  final bool showOutline;

  const _CardSkeleton({
    required this.outlineColor,
    required this.colorScheme,
    required this.itemHeight,
    required this.borderRadius,
    required this.showOutline,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = colorScheme.surfaceContainer;

    return Container(
      constraints: BoxConstraints(minHeight: itemHeight),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: showOutline
            ? Border.all(color: outlineColor, width: AppBorders.medium)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 24, height: 24, color: barColor),
              const SizedBox(width: AppSpacing.sm),
              Container(width: 60, height: 12, color: barColor),
              const Spacer(),
              Container(width: 48, height: 18, color: barColor),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          Container(width: double.infinity, height: 16, color: barColor),
          const SizedBox(height: AppSpacing.sm),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.75,
            child: Container(height: 14, color: barColor),
          ),
          const SizedBox(height: AppSpacing.smd),
          Row(
            children: [
              Container(width: 80, height: 11, color: barColor),
              const Spacer(),
              Container(width: 56, height: 11, color: barColor),
            ],
          ),
        ],
      ),
    );
  }
}
