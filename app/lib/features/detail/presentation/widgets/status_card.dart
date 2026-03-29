import 'package:flutter/material.dart';

import 'package:trendpulse/core/theme/app_borders.dart';
import 'package:trendpulse/core/theme/app_motion.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
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
      duration: AppMotion.pulse,
    );
    if (widget.task.isInProgress) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1;
    }
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
    final colorScheme = theme.colorScheme;

    final (icon, statusText) = _statusInfo(widget.task, l10n);
    final progress = _progressValue(widget.task);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.onSurface,
          width: AppBorders.medium,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.liveStatus.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                FadeTransition(
                  opacity: _pulseController.drive(
                    Tween(begin: AppOpacity.loadingBase, end: AppOpacity.full),
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colorScheme.onSurface,
                        width: AppBorders.medium,
                      ),
                    ),
                    child: Icon(icon, color: colorScheme.onSurface, size: 20),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    statusText.toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: theme.textTheme.displayLarge?.fontFamily,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              borderRadius: BorderRadius.zero,
              color: colorScheme.onSurface,
              backgroundColor: colorScheme.onSurface.withValues(
                alpha: AppOpacity.overlay,
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
    if (task.isPartial) {
      return (Icons.warning_amber_rounded, l10n.statusPartial);
    }
    if (task.isFailed) {
      return (Icons.error_outline_rounded, l10n.statusFailed);
    }
    if (task.isCompleted) {
      return (Icons.check_circle_rounded, l10n.statusCompleted);
    }
    return (Icons.hourglass_top_rounded, l10n.statusPending);
  }

  double? _progressValue(AnalysisTask task) {
    if (task.isPending) return null;
    if (task.isCollecting) return 0.4;
    if (task.isAnalyzing) return 0.75;
    if (task.isPartial || task.isCompleted || task.isFailed) return 1.0;
    return null;
  }
}
