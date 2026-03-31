import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_borders.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_typography.dart';
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
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              rootNode.label,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: theme.textTheme.displayLarge?.fontFamily,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: AppBorders.thin,
            color: colorScheme.outline,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
          ),
          if (rootNode.children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < rootNode.children.length; i++)
                    _MindmapNodeCard(
                      node: rootNode.children[i],
                      depth: 0,
                      sectionIndex: i,
                    ),
                ],
              ),
            ),
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
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: AppBorders.thick, color: colorScheme.outline),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: theme.textTheme.displayLarge?.fontFamily,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
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
          ),
        ],
      ),
    );
  }
}

class _MindmapNodeCard extends StatelessWidget {
  final _MindmapNode node;
  final int depth;
  final int sectionIndex;

  const _MindmapNodeCard({
    required this.node,
    required this.depth,
    this.sectionIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (depth == 0) {
      final ordinal = (sectionIndex + 1).toString().padLeft(2, '0');
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  ordinal,
                  style: AppTypography.dataNumber(
                    theme.textTheme,
                    fontSize: 11,
                    weight: FontWeight.w700,
                  ).copyWith(
                    color: colorScheme.primary.withValues(alpha: AppOpacity.secondary),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    node.label.toUpperCase(),
                    style: AppTypography.editorialEyebrow(theme.textTheme).copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Divider(
              height: 1,
              thickness: AppBorders.thin,
              color: colorScheme.outline.withValues(alpha: AppOpacity.subtle),
            ),
            if (node.children.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              ...node.children.map(
                (child) => _MindmapNodeCard(node: child, depth: depth + 1),
              ),
            ],
          ],
        ),
      );
    }

    if (depth == 1) {
      return Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          top: AppSpacing.xs,
          bottom: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: AppSpacing.sm),
                  child: Text(
                    '\u2013',
                    style: TextStyle(
                      color: colorScheme.primary.withValues(alpha: AppOpacity.hint),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    node.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: AppOpacity.body),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (node.children.isNotEmpty)
              ...node.children.map(
                (child) => _MindmapNodeCard(node: child, depth: depth + 1),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xl,
        top: AppSpacing.xxs,
        bottom: AppSpacing.xxs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: AppSpacing.xs),
                child: Text(
                  '\u2014',
                    style: TextStyle(
                      color: colorScheme.outline.withValues(alpha: AppOpacity.muted),
                      fontSize: 10,
                      height: 1.4,
                    ),
                ),
              ),
              Expanded(
                child: Text(
                  node.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: AppOpacity.mutedSoft),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (node.children.isNotEmpty)
            ...node.children.map(
              (child) => _MindmapNodeCard(node: child, depth: depth + 1),
            ),
        ],
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
