import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';

class AnalysisSourceChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final String status;
  final bool enabled;
  final String? reason;
  final Key? tapTargetKey;
  final ValueChanged<bool>? onSelected;

  const AnalysisSourceChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.status,
    required this.enabled,
    this.reason,
    this.tapTargetKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDegraded = status == 'degraded';
    final effectiveAlpha = enabled ? 1.0 : 0.48;
    final textColor = selected
        ? AppColors.onBrandFill(color)
        : colors.onSurface.withValues(alpha: effectiveAlpha);
    final borderRadius = BorderRadius.circular(AppSpacing.radiusPill);
    final shapeBorder = RoundedRectangleBorder(
      borderRadius: borderRadius,
      side: BorderSide(
        color: selected
            ? color.withValues(alpha: effectiveAlpha)
            : colors.outline.withValues(alpha: effectiveAlpha),
        width: selected ? 1.5 : 1.0,
      ),
    );
    final labelStyle = (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
      color: textColor,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    Widget button = Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      child: ConstrainedBox(
        key: tapTargetKey,
        constraints: const BoxConstraints(minHeight: 48),
        child: Material(
          color: selected
              ? color.withValues(alpha: effectiveAlpha)
              : Colors.transparent,
          shape: shapeBorder,
          child: InkWell(
            onTap: enabled ? () => onSelected?.call(!selected) : null,
            customBorder: shapeBorder,
            child: ExcludeSemantics(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDegraded) ...[
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: textColor,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                    ],
                    Text(label, style: labelStyle),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final tooltipMessage = reason?.trim();
    if (tooltipMessage != null && tooltipMessage.isNotEmpty) {
      button = Tooltip(message: tooltipMessage, child: button);
    }
    return button;
  }
}
