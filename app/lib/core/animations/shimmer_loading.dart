import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const ShimmerLoading({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 120,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      highlightColor: isDark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.15)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => Container(
          height: itemHeight,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
