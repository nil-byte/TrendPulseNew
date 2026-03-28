import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/animations/number_ticker.dart';
import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/animations/staggered_list.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/heat_index_card.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/key_insight_card.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/sentiment_gauge.dart';
import 'package:trendpulse/features/detail/presentation/providers/detail_provider.dart';
import 'package:trendpulse/features/detail/presentation/widgets/status_card.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class ReportTab extends ConsumerWidget {
  final String taskId;

  const ReportTab({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskDetailProvider(taskId));

    return taskAsync.when(
      loading: () => const ShimmerLoading(itemCount: 4, itemHeight: 100),
      error: (e, _) => _ErrorContent(
        message: e.toString(),
        onRetry: () => ref.invalidate(taskDetailProvider(taskId)),
      ),
      data: (task) {
        if (task.isFailed) {
          return _ErrorContent(
            message: task.errorMessage,
            onRetry: () =>
                ref.read(taskDetailProvider(taskId).notifier).refresh(),
          );
        }
        if (task.isInProgress) {
          return _InProgressContent(task: task);
        }
        return _CompletedContent(taskId: taskId);
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
        ),
      ],
    );
  }
}

class _CompletedContent extends ConsumerWidget {
  final String taskId;

  const _CompletedContent({required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(taskReportProvider(taskId));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return reportAsync.when(
      loading: () => const ShimmerLoading(itemCount: 4, itemHeight: 100),
      error: (e, _) => _ErrorContent(
        message: e.toString(),
        onRetry: () => ref.invalidate(taskReportProvider(taskId)),
      ),
      data: (report) {
        if (report == null) {
          return const ShimmerLoading(itemCount: 3, itemHeight: 100);
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _MetricsRow(report: report),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(title: l10n.summary),
            const SizedBox(height: AppSpacing.sm),
            StaggeredListItem(
              index: 0,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    report.summary,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(title: l10n.keyInsights),
            const SizedBox(height: AppSpacing.sm),
            ...List.generate(report.keyInsights.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: StaggeredListItem(
                  index: i + 1,
                  child: KeyInsightCard(insight: report.keyInsights[i]),
                ),
              );
            }),
            const SizedBox(height: AppSpacing.lg),
            _SectionHeader(title: l10n.sentimentDistribution),
            const SizedBox(height: AppSpacing.sm),
            StaggeredListItem(
              index: report.keyInsights.length + 2,
              child: _SentimentDistributionBar(report: report),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        );
      },
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final AnalysisReport report;

  const _MetricsRow({required this.report});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Row(
            children: [
              Expanded(child: SentimentGauge(score: report.sentimentScore)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: HeatIndexCard(heatIndex: report.heatIndex)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _DataVolumeCard(report: report)),
            ],
          );
        }
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: SentimentGauge(score: report.sentimentScore)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: HeatIndexCard(heatIndex: report.heatIndex)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _DataVolumeCard(report: report),
          ],
        );
      },
    );
  }
}

class _DataVolumeCard extends StatelessWidget {
  final AnalysisReport report;

  const _DataVolumeCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NumberTicker(
              targetValue: report.totalPosts.toDouble(),
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.dataVolume,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(AppSpacing.borderRadiusSm),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    Expanded(
                      flex: (report.positiveRatio * 100).round().clamp(1, 100),
                      child: Container(color: tpColors.positive),
                    ),
                    Expanded(
                      flex: (report.neutralRatio * 100).round().clamp(1, 100),
                      child: Container(color: tpColors.neutral),
                    ),
                    Expanded(
                      flex: (report.negativeRatio * 100).round().clamp(1, 100),
                      child: Container(color: tpColors.negative),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LegendItem(
                  color: tpColors.positive,
                  label: l10n.positive,
                  value: '${(report.positiveRatio * 100).round()}%',
                ),
                _LegendItem(
                  color: tpColors.neutral,
                  label: l10n.neutral,
                  value: '${(report.neutralRatio * 100).round()}%',
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
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label $value',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
    final tpColors = theme.trendPulseColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: tpColors.negative,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.statusFailed,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
