import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_borders.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class MermaidMindmapCard extends StatelessWidget {
  final String mermaidMindmap;

  const MermaidMindmapCard({super.key, required this.mermaidMindmap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rootNode = _parseMermaidMindmap(mermaidMindmap);
    if (rootNode == null) {
      return _MermaidMindmapFallbackCard(
        mermaidMindmap: mermaidMindmap,
        title: l10n.reportMindmapFallbackTitle,
        message: l10n.reportMindmapFallbackBody,
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey('report-mermaid-mindmap'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outline,
          width: AppBorders.thin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  rootNode.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: theme.textTheme.displayLarge?.fontFamily,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(
                    alpha: AppOpacity.selectedWash,
                  ),
                  border: Border.all(
                    color: colorScheme.primary.withValues(
                      alpha: AppOpacity.hint,
                    ),
                  ),
                ),
                child: Text(
                  'MERMAID',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          if (rootNode.children.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ...rootNode.children.map(
              (child) => _MindmapNodeCard(node: child, depth: 0),
            ),
          ],
        ],
      ),
    );
  }
}

class _MermaidMindmapFallbackCard extends StatelessWidget {
  final String mermaidMindmap;
  final String title;
  final String message;

  const _MermaidMindmapFallbackCard({
    required this.mermaidMindmap,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const ValueKey('report-mermaid-mindmap-fallback'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outline,
          width: AppBorders.thin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: theme.textTheme.displayLarge?.fontFamily,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: AppOpacity.body),
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableText(
            mermaidMindmap,
            key: const ValueKey('report-mermaid-mindmap-raw'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MindmapNodeCard extends StatelessWidget {
  final _MindmapNode node;
  final int depth;

  const _MindmapNodeCard({required this.node, required this.depth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = depth == 0
        ? colorScheme.primaryContainer.withValues(alpha: AppOpacity.selectedWash)
        : colorScheme.surface;

    return Padding(
      padding: EdgeInsets.only(
        left: depth * AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            left: BorderSide(
              color: depth == 0 ? colorScheme.primary : colorScheme.outline,
              width: AppBorders.medium,
            ),
            top: BorderSide(
              color: colorScheme.outline.withValues(alpha: AppOpacity.divider),
              width: AppBorders.thin,
            ),
            right: BorderSide(
              color: colorScheme.outline.withValues(alpha: AppOpacity.divider),
              width: AppBorders.thin,
            ),
            bottom: BorderSide(
              color: colorScheme.outline.withValues(alpha: AppOpacity.divider),
              width: AppBorders.thin,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              node.label,
              style: (depth == 0
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.bodyLarge)
                  ?.copyWith(
                    fontWeight: depth == 0 ? FontWeight.w800 : FontWeight.w600,
                    height: 1.4,
                  ),
            ),
            if (node.children.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              ...node.children.map(
                (child) => _MindmapNodeCard(node: child, depth: depth + 1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

_MindmapNode? _parseMermaidMindmap(String source) {
  // The app intentionally renders only the narrow mindmap subset emitted
  // by the backend's build_mermaid_mindmap() contract.
  final lines = source
      .split('\n')
      .map((line) => line.replaceAll('\t', '  '))
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty || lines.first.trim() != 'mindmap') {
    return null;
  }

  _MindmapNode? root;
  final stack = <_NodeAtDepth>[];

  for (final rawLine in lines.skip(1)) {
    final trimmed = rawLine.trim();
    final label = _decodeMermaidLabel(trimmed);
    if (label.isEmpty) {
      continue;
    }

    final leadingSpaces = rawLine.length - rawLine.trimLeft().length;
    final depth = (leadingSpaces ~/ 2) - 1;
    final node = _MindmapNode(label);

    if (depth <= 0 || root == null) {
      root = node;
      stack
        ..clear()
        ..add(_NodeAtDepth(depth: 0, node: node));
      continue;
    }

    while (stack.isNotEmpty && stack.last.depth >= depth) {
      stack.removeLast();
    }

    final parent = stack.isEmpty ? root : stack.last.node;
    parent.children.add(node);
    stack.add(_NodeAtDepth(depth: depth, node: node));
  }

  return root;
}

String _decodeMermaidLabel(String label) {
  var normalized = label.replaceAll(RegExp(r':::.+$'), '').trim();
  if (normalized.startsWith('root((') && normalized.endsWith('))')) {
    normalized = normalized.substring(6, normalized.length - 2);
  }
  if (normalized.startsWith('"') && normalized.endsWith('"')) {
    normalized = normalized.substring(1, normalized.length - 1);
  }
  return normalized.trim();
}

class _MindmapNode {
  final String label;
  final List<_MindmapNode> children = [];

  _MindmapNode(this.label);
}

class _NodeAtDepth {
  final int depth;
  final _MindmapNode node;

  const _NodeAtDepth({required this.depth, required this.node});
}
