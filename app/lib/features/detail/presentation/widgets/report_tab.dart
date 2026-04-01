import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/animations/staggered_list.dart';
import 'package:trendpulse/core/theme/app_borders.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_typography.dart';
import 'package:trendpulse/core/network/error_message_resolver.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/core/widgets/error_widget.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/detail/presentation/providers/detail_provider.dart';
import 'package:trendpulse/features/detail/presentation/widgets/mermaid_mindmap_card.dart';
import 'package:trendpulse/features/detail/presentation/widgets/status_card.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class ReportTab extends ConsumerWidget {
  final String taskId;

  const ReportTab({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskDetailProvider(taskId));
    final l10n = AppLocalizations.of(context)!;

    return taskAsync.when(
      loading: () => const ShimmerLoading(
        itemCount: 4,
        itemHeight: 100,
        cardSkeleton: true,
      ),
      error: (e, _) => _RefreshableErrorContent(
        message: resolveUserErrorMessage(e, l10n),
        onRetry: () => ref.invalidate(taskDetailProvider(taskId)),
        onRefresh: () async {
          ref.invalidate(taskDetailProvider(taskId));
          await ref.read(taskDetailProvider(taskId).future);
        },
      ),
      data: (task) {
        if (task.isFailed) {
          if (kDebugMode && task.errorMessage != null) {
            debugPrint('[TaskFailed:$taskId] ${task.errorMessage}');
          }
          return _ErrorContent(
            message: l10n.reportAnalysisFailedMessage,
            onRetry: () =>
                ref.read(taskDetailProvider(taskId).notifier).refresh(),
          );
        }
        if (task.isInProgress) {
          return _InProgressContent(task: task);
        }
        return _CompletedContent(taskId: taskId, task: task);
      },
    );
  }
}

class _InProgressContent extends StatelessWidget {
  final AnalysisTask task;

  const _InProgressContent({required this.task});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        StatusCard(task: task),
        const SizedBox(height: AppSpacing.lg),
        const ShimmerLoading(
          itemCount: 3,
          itemHeight: 100,
          padding: EdgeInsets.zero,
          cardSkeleton: true,
        ),
      ],
    );
  }
}

class _CompletedContent extends ConsumerWidget {
  final String taskId;
  final AnalysisTask task;

  const _CompletedContent({required this.taskId, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(taskReportProvider(taskId));
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return reportAsync.when(
      loading: () => const ShimmerLoading(
        itemCount: 4,
        itemHeight: 100,
        cardSkeleton: true,
      ),
      error: (e, _) => _RefreshableErrorContent(
        message: resolveUserErrorMessage(e, l10n),
        onRetry: () => ref.invalidate(taskReportProvider(taskId)),
        onRefresh: () async {
          ref.invalidate(taskReportProvider(taskId));
          await ref.read(taskReportProvider(taskId).future);
        },
      ),
      data: (report) {
        if (report == null) {
          return const ShimmerLoading(
            itemCount: 3,
            itemHeight: 100,
            cardSkeleton: true,
          );
        }
        final mermaidMindmap = report.mermaidMindmap?.trim();
        return RefreshIndicator(
          color: theme.colorScheme.onSurface,
          backgroundColor: theme.colorScheme.surface,
          onRefresh: () async {
            ref.invalidate(taskReportProvider(taskId));
            await ref.read(taskReportProvider(taskId).future);
          },
          child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (task.isPartial) ...[
              StatusCard(task: task),
              const SizedBox(height: AppSpacing.lg),
            ],
            _MetricsRow(report: report, task: task),
            const EditorialDivider.thick(
              topSpace: AppSpacing.xl,
              bottomSpace: AppSpacing.lg,
            ),

            _SectionHeader(title: l10n.executiveSummary),
            const EditorialDivider(
              topSpace: AppSpacing.xs,
              bottomSpace: AppSpacing.md,
            ),

            StaggeredListItem(
              index: 0,
              child: _EditorialSummary(text: report.summary),
            ),

            const EditorialDivider.thick(
              topSpace: AppSpacing.xl,
              bottomSpace: AppSpacing.lg,
            ),

            _SectionHeader(title: l10n.keyInsights),
            const EditorialDivider(
              topSpace: AppSpacing.xs,
              bottomSpace: AppSpacing.md,
            ),

            ...List.generate(report.keyInsights.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: StaggeredListItem(
                  index: i + 1,
                  child: _EditorialInsightBlock(
                    index: i + 1,
                    insight: report.keyInsights[i],
                  ),
                ),
              );
            }),

            if (mermaidMindmap != null && mermaidMindmap.isNotEmpty) ...[
              const EditorialDivider.thick(
                topSpace: AppSpacing.lg,
                bottomSpace: AppSpacing.lg,
              ),
              _SectionHeader(title: l10n.reportMindmap),
              const EditorialDivider(
                topSpace: AppSpacing.xs,
                bottomSpace: AppSpacing.md,
              ),
              StaggeredListItem(
                index: report.keyInsights.length + 2,
                child: MermaidMindmapCard(mermaidMindmap: mermaidMindmap),
              ),
            ],

            const EditorialDivider.thick(
              topSpace: AppSpacing.lg,
              bottomSpace: AppSpacing.lg,
            ),

            _SectionHeader(title: l10n.sentimentDistribution),
            const EditorialDivider(
              topSpace: AppSpacing.xs,
              bottomSpace: AppSpacing.md,
            ),

            StaggeredListItem(
              index: report.keyInsights.length +
                  ((mermaidMindmap != null && mermaidMindmap.isNotEmpty) ? 3 : 2),
              child: _SentimentDistributionBar(report: report),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
        );
      },
    );
  }
}

class _EditorialSummary extends StatelessWidget {
  final String text;

  const _EditorialSummary({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (text.isEmpty) return const SizedBox.shrink();

    final firstChar = text.substring(0, 1);
    final restText = text.substring(1);

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.6,
        ),
        children: [
          TextSpan(
            text: firstChar,
            style: theme.textTheme.displayLarge?.copyWith(
              fontFamily: theme.textTheme.displayLarge?.fontFamily,
              fontWeight: FontWeight.w900,
              height: 1.0,
              color: theme.colorScheme.onSurface,
            ),
          ),
          TextSpan(text: restText),
        ],
      ),
    );
  }
}

class _EditorialInsightBlock extends StatelessWidget {
  final int index;
  final KeyInsight insight;

  const _EditorialInsightBlock({required this.index, required this.insight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.outline, width: 2.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.insightLabel(index.toString().padLeft(2, '0')).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: theme.colorScheme.onSurface.withValues(
                alpha: AppOpacity.body,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            insight.text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: theme.textTheme.displayLarge?.fontFamily,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final AnalysisReport report;
  final AnalysisTask task;

  const _MetricsRow({required this.report, required this.task});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sentimentScore = task.sentimentScore ?? report.sentimentScore;
    final postCount = task.postCount ?? report.totalPosts;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _EditorialMetric(
            label: l10n.sentimentIndex,
            value: sentimentScore.round().toString(),
            suffix: '/100',
            isHero: true,
          ),
        ),
        Container(
          width: 1.0,
          height: 80,
          color: Theme.of(context).colorScheme.outline,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EditorialMetric(
                label: l10n.heatShort,
                value: report.heatIndex.round().toString(),
              ),
              const EditorialDivider(
                topSpace: AppSpacing.sm,
                bottomSpace: AppSpacing.sm,
              ),
              _EditorialMetric(
                label: l10n.volumeShort,
                value: postCount.toString(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorialMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final bool isHero;

  const _EditorialMetric({
    required this.label,
    required this.value,
    this.suffix,
    this.isHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: isHero
                    ? theme.textTheme.displayLarge?.copyWith(
                        fontFamily: theme.textTheme.displayLarge?.fontFamily,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2.0,
                      )
                    : theme.textTheme.headlineMedium?.copyWith(
                        fontFamily: theme.textTheme.displayLarge?.fontFamily,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
              ),
              if (suffix != null)
                Text(
                  suffix!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: AppOpacity.mutedSoft,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.titleMedium?.copyWith(
        fontFamily: theme.textTheme.displayLarge?.fontFamily,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _SentimentDistributionBar extends StatelessWidget {
  final AnalysisReport report;

  const _SentimentDistributionBar({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tpColors = theme.trendPulseColors;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline,
          width: AppBorders.thin,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: (report.positiveRatio * 100).round().clamp(1, 100),
                child: Container(height: 24, color: tpColors.positive),
              ),
              Expanded(
                flex: (report.neutralRatio * 100).round().clamp(1, 100),
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: theme.colorScheme.outline,
                        width: AppBorders.thin,
                      ),
                    ),
                  ),
                  child: CustomPaint(
                    painter: _NeutralStripePainter(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: AppOpacity.decorative,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: (report.negativeRatio * 100).round().clamp(1, 100),
                child: Container(height: 24, color: tpColors.negative),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _LegendItem(
                color: tpColors.positive,
                label: l10n.positive,
                value: '${(report.positiveRatio * 100).round()}%',
              ),
              _LegendItem(
                color: theme.colorScheme.surface,
                borderColor: theme.colorScheme.onSurface,
                label: l10n.neutral,
                value: '${(report.neutralRatio * 100).round()}%',
                striped: true,
              ),
              _LegendItem(
                color: tpColors.negative,
                label: l10n.negative,
                value: '${(report.negativeRatio * 100).round()}%',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color? borderColor;
  final String label;
  final String value;
  final bool striped;

  const _LegendItem({
    required this.color,
    this.borderColor,
    required this.label,
    required this.value,
    this.striped = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  border: borderColor != null
                      ? Border.all(color: borderColor!, width: 1.0)
                      : null,
                ),
                child: striped
                    ? CustomPaint(
                        painter: _NeutralStripePainter(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.18,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: AppTypography.dataNumber(
            theme.textTheme,
            fontSize: 22,
            weight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ErrorContent extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _ErrorContent({this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final resolvedMessage = message?.trim();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.reportAnalysisFailedTitle.toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: theme.textTheme.displayLarge?.fontFamily,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            if (resolvedMessage != null && resolvedMessage.isNotEmpty) ...[
              const EditorialDivider(
                topSpace: AppSpacing.sm,
                bottomSpace: AppSpacing.sm,
              ),
              Text(
                resolvedMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshableErrorContent extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;

  const _RefreshableErrorContent({
    required this.message,
    required this.onRetry,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.onSurface,
      backgroundColor: Theme.of(context).colorScheme.surface,
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: AppErrorWidget(
              message: message,
              onRetry: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeutralStripePainter extends CustomPainter {
  final Color color;

  const _NeutralStripePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const spacing = 8.0;

    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NeutralStripePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

