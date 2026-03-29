import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/theme/app_motion.dart';
import 'package:trendpulse/core/theme/app_opacity.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_typography.dart';
import 'package:trendpulse/core/widgets/editorial_divider.dart';
import 'package:trendpulse/features/detail/presentation/providers/detail_provider.dart';
import 'package:trendpulse/features/detail/presentation/widgets/raw_data_tab.dart';
import 'package:trendpulse/features/detail/presentation/widgets/report_tab.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class DetailPage extends ConsumerStatefulWidget {
  final String taskId;

  const DetailPage({super.key, required this.taskId});

  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      animationDuration: AppMotion.normal,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final keyword = taskAsync.valueOrNull?.keyword ?? '';

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              forceElevated: innerBoxIsScrolled,
              leadingWidth: 64,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              titleSpacing: 0,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.reportOn.toUpperCase(),
                    style: AppTypography.editorialEyebrow(theme.textTheme)
                        .copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: AppOpacity.primary,
                      ),
                    ),
                  ),
                  keyword.isEmpty
                      ? Container(
                          width: 156,
                          height: 18,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: AppOpacity.body),
                            border: Border.all(
                              color: theme.colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusXs,
                            ),
                          ),
                        )
                      : Hero(
                          tag: 'task-keyword-${widget.taskId}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(
                              keyword.toUpperCase(),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontFamily: theme
                                    .textTheme
                                    .displayLarge
                                    ?.fontFamily,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                height: 1.18,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Column(
                  children: [
                    const EditorialDivider.thick(topSpace: 0, bottomSpace: 0),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: theme.colorScheme.primary,
                      indicatorWeight: 2,
                      labelColor: theme.colorScheme.onSurface,
                      unselectedLabelColor: theme.colorScheme.onSurface
                          .withValues(alpha: AppOpacity.bodyStrong),
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.35,
                      ),
                      overlayColor: WidgetStatePropertyAll(
                        theme.colorScheme.primary.withValues(
                          alpha: AppOpacity.selectedWash,
                        ),
                      ),
                      tabs: [
                        Tab(text: l10n.report.toUpperCase()),
                        Tab(text: l10n.rawData.toUpperCase()),
                      ],
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.outline.withValues(
                        alpha: AppOpacity.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            ReportTab(taskId: widget.taskId),
            RawDataTab(taskId: widget.taskId),
          ],
        ),
      ),
    );
  }
}
