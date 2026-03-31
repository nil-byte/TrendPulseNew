import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_borders.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';

class AnalysisEditorialSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final bool configExpanded;
  final String searchHint;
  final VoidCallback onSearch;
  final VoidCallback onToggleConfig;

  const AnalysisEditorialSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.configExpanded,
    required this.searchHint,
    required this.onSearch,
    required this.onToggleConfig,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.onSurface, width: AppBorders.thick),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: theme.textTheme.displayLarge?.fontFamily,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: theme.textTheme.displayLarge?.fontFamily,
                  color: colors.onSurface.withValues(alpha: AppOpacity.divider),
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
          Container(
            width: AppBorders.thick,
            height: 56.0,
            color: colors.onSurface,
          ),
          IconButton(
            onPressed: onToggleConfig,
            icon: Icon(
              configExpanded ? Icons.close : Icons.tune_rounded,
              color: colors.onSurface,
            ),
            style: IconButton.styleFrom(
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
          ),
          Container(
            width: AppBorders.thick,
            height: 56.0,
            color: colors.onSurface,
          ),
          Semantics(
            button: true,
            child: InkWell(
              onTap: isSearching ? null : onSearch,
              child: Container(
                width: 56,
                height: 56.0,
                color: colors.primary,
                alignment: Alignment.center,
                child: isSearching
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimary,
                        ),
                      )
                    : Icon(
                        Icons.arrow_forward_rounded,
                        color: colors.onPrimary,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
