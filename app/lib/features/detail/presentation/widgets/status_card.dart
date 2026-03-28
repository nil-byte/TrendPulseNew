import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/features/analysis/data/analysis_model.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class StatusCard extends StatefulWidget {
  final AnalysisTask task;

  const StatusCard({super.key, required this.task});

  @override
  State<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<StatusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final (icon, statusText) = _statusInfo(widget.task, l10n);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            FadeTransition(
              opacity: _pulseController.drive(Tween(begin: 0.4, end: 1.0)),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(
                    AppSpacing.borderRadiusMd,
                  ),
                ),
                child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _progressValue(widget.task),
                      minHeight: 4,
                      backgroundColor: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, String) _statusInfo(AnalysisTask task, AppLocalizations l10n) {
    if (task.isPending) {
      return (Icons.hourglass_top_rounded, l10n.statusPending);
    }
    if (task.isCollecting) {
      return (Icons.download_rounded, l10n.statusCollecting);
    }
    if (task.isAnalyzing) {
      return (Icons.psychology_rounded, l10n.statusAnalyzing);
    }
    return (Icons.check_circle_rounded, l10n.statusCompleted);
  }

  double? _progressValue(AnalysisTask task) {
    if (task.isPending) return null;
    if (task.isCollecting) return 0.4;
    if (task.isAnalyzing) return 0.75;
    return 1.0;
  }
}
