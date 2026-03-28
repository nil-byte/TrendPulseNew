import 'package:flutter/material.dart';

/// 杂志风专属的排版分割线
class EditorialDivider extends StatelessWidget {
  final double thickness;
  final double topSpace;
  final double bottomSpace;

  const EditorialDivider({
    super.key,
    this.thickness = 1.0,
    this.topSpace = 16.0,
    this.bottomSpace = 16.0,
  });

  /// 粗黑线（通常用于报头下方，或大区块分割）
  const EditorialDivider.thick({
    super.key,
    this.thickness = 4.0,
    this.topSpace = 24.0,
    this.bottomSpace = 24.0,
  });

  /// 双实线（经典报纸排版元素）
  static Widget doubleLine({
    double topSpace = 24.0,
    double bottomSpace = 24.0,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: topSpace),
        const Divider(thickness: 2.0, height: 2.0),
        const SizedBox(height: 2.0),
        const Divider(thickness: 1.0, height: 1.0),
        SizedBox(height: bottomSpace),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: topSpace),
        Divider(
          thickness: thickness,
          height: thickness,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        SizedBox(height: bottomSpace),
      ],
    );
  }
}
