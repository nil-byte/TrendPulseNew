import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_borders.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';

/// 杂志风专属的排版分割线
///
/// 颜色语义：
/// - 普通版（默认）：使用 `outline`（低对比，呼吸感，适合内容区间隔）
/// - `.thick` 版：使用 `onSurface`（高对比重音线，适合大区块标题下方）
/// - `doubleLine`：外线 `onSurface`，内线 `outline`（双强度，报头专用）
class EditorialDivider extends StatelessWidget {
  final double thickness;
  final double topSpace;
  final double bottomSpace;
  final bool _isThick;

  const EditorialDivider({
    super.key,
    this.thickness = AppBorders.thin,
    this.topSpace = AppSpacing.md,
    this.bottomSpace = AppSpacing.md,
  }) : _isThick = false;

  /// 粗重音线（用于报头下方或大区块分割）
  const EditorialDivider.thick({
    super.key,
    this.thickness = AppBorders.accent,
    this.topSpace = AppSpacing.lg,
    this.bottomSpace = AppSpacing.lg,
  }) : _isThick = true;

  /// 双实线（经典报纸排版元素）
  /// 外线使用 onSurface（强调），内线使用 outline（呼吸）
  static Widget doubleLine({
    double topSpace = AppSpacing.lg,
    double bottomSpace = AppSpacing.lg,
  }) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: topSpace),
            Divider(
              thickness: AppBorders.thick,
              height: AppBorders.thick,
              color: cs.onSurface,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Divider(
              thickness: AppBorders.thin,
              height: AppBorders.thin,
              color: cs.outline,
            ),
            SizedBox(height: bottomSpace),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: topSpace),
        Divider(
          thickness: thickness,
          height: thickness,
          color: _isThick ? cs.onSurface : cs.outline,
        ),
        SizedBox(height: bottomSpace),
      ],
    );
  }
}
