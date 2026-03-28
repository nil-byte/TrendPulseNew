import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/widgets/empty_widget.dart';
import 'package:trendpulse/core/widgets/error_widget.dart';
import 'package:trendpulse/core/widgets/loading_widget.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/features/analysis/presentation/providers/analysis_provider.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/heat_index_card.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/key_insight_card.dart';
import 'package:trendpulse/features/analysis/presentation/widgets/sentiment_gauge.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  final _keywordController = TextEditingController();
  String _language = 'en';

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  void _onAnalyze() {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return;
    ref.read(analysisControllerProvider.notifier).createTask(
          keyword: keyword,
          language: _language,
        );
  }

  @override
  Widget build(BuildContext context) {
    final analysisState = ref.watch(analysisControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SearchSection(
              controller: _keywordController,
              language: _language,
              onLanguageChanged: (v) => setState(() => _language = v),
              onAnalyze: _onAnalyze,
              isLoading: analysisState.status == AnalysisStatus.loading ||
                  analysisState.status == AnalysisStatus.polling,
            ),
            const SizedBox(height: 24),
            _buildBody(analysisState, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AnalysisState state, ThemeData theme) {
    switch (state.status) {
      case AnalysisStatus.idle:
        return const EmptyWidget(
          message: 'Enter a topic to start analysis',
          icon: Icons.search_rounded,
        );
      case AnalysisStatus.loading:
      case AnalysisStatus.polling:
        return Column(
          children: [
            _PollingStatusBanner(task: ref.watch(currentTaskProvider)),
            const SizedBox(height: 16),
            const LoadingWidget(itemCount: 3, itemHeight: 100),
          ],
        );
      case AnalysisStatus.failed:
        return AppErrorWidget(
          message: state.errorMessage ?? 'Something went wrong',
          onRetry: _onAnalyze,
        );
      case AnalysisStatus.completed:
        if (state.report == null) {
          return const EmptyWidget(message: 'No report data available');
        }
        return _ResultsSection(report: state.report!);
    }
  }
}

class _SearchSection extends StatelessWidget {
  final TextEditingController controller;
  final String language;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onAnalyze;
  final bool isLoading;

  const _SearchSection({
    required this.controller,
    required this.language,
    required this.onLanguageChanged,
    required this.onAnalyze,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Analyze a topic...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onAnalyze(),
          ),
        ),
        const SizedBox(width: 12),
        _LanguageDropdown(
          value: language,
          onChanged: onLanguageChanged,
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: isLoading ? null : onAnalyze,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Analyze'),
        ),
      ],
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _LanguageDropdown({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'en', child: Text('EN')),
            DropdownMenuItem(value: 'zh', child: Text('ZH')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _PollingStatusBanner extends StatelessWidget {
  final AnalysisTask? task;

  const _PollingStatusBanner({required this.task});

  String get _statusLabel {
    if (task == null) return 'Starting...';
    switch (task!.status) {
      case 'pending':
        return 'Queued — waiting to start...';
      case 'collecting':
        return 'Collecting data from sources...';
      case 'analyzing':
        return 'Analyzing sentiment & trends...';
      default:
        return 'Processing...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _statusLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsSection extends StatelessWidget {
  final AnalysisReport report;

  const _ResultsSection({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricsRow(report: report),
        const SizedBox(height: 24),
        if (report.summary.isNotEmpty) ...[
          Text(
            report.summary,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (report.keyInsights.isNotEmpty) ...[
          Text('Key Insights', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ...report.keyInsights
              .take(5)
              .map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: KeyInsightCard(insight: i),
                  )),
          const SizedBox(height: 12),
        ],
        Text('Sentiment Distribution', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _SentimentDistributionBar(report: report),
      ],
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
        if (constraints.maxWidth < 500) {
          return Column(
            children: [
              HeatIndexCard(heatIndex: report.heatIndex),
              const SizedBox(height: 16),
              SentimentGauge(score: report.sentimentScore),
              const SizedBox(height: 16),
              _DataVolumeCard(count: report.totalPosts),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: HeatIndexCard(heatIndex: report.heatIndex)),
            const SizedBox(width: 16),
            Expanded(
                child: SentimentGauge(score: report.sentimentScore)),
            const SizedBox(width: 16),
            Expanded(child: _DataVolumeCard(count: report.totalPosts)),
          ],
        );
      },
    );
  }
}

class _DataVolumeCard extends StatelessWidget {
  final int count;

  const _DataVolumeCard({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count.toString(),
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.seed,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Data Volume',
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

class _SentimentDistributionBar extends StatelessWidget {
  final AnalysisReport report;

  const _SentimentDistributionBar({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = report.positiveRatio;
    final negative = report.negativeRatio;
    final neutral = report.neutralRatio;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (positive > 0)
                      Expanded(
                        flex: (positive * 100).round(),
                        child: Container(color: AppColors.positive),
                      ),
                    if (neutral > 0)
                      Expanded(
                        flex: (neutral * 100).round(),
                        child: Container(color: AppColors.neutral),
                      ),
                    if (negative > 0)
                      Expanded(
                        flex: (negative * 100).round(),
                        child: Container(color: AppColors.negative),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LegendItem(
                  color: AppColors.positive,
                  label: 'Positive',
                  value: '${(positive * 100).round()}%',
                  theme: theme,
                ),
                _LegendItem(
                  color: AppColors.neutral,
                  label: 'Neutral',
                  value: '${(neutral * 100).round()}%',
                  theme: theme,
                ),
                _LegendItem(
                  color: AppColors.negative,
                  label: 'Negative',
                  value: '${(negative * 100).round()}%',
                  theme: theme,
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
  final ThemeData theme;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(width: 6),
        Text(
          '$label $value',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
