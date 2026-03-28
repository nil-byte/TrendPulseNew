import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_typography.dart';
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
      animationDuration: const Duration(milliseconds: 220),
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
              expandedHeight: 168,
              forceElevated: innerBoxIsScrolled,
              leadingWidth: 64,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                expandedTitleScale: 1.04,
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 72,
                  bottom: AppSpacing.xl + 10,
                  end: AppSpacing.lg,
                ),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.reportOn.toUpperCase(),
                      style: AppTypography.editorialEyebrow(theme.textTheme)
                          .copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: keyword.isEmpty
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 156,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.6),
                                  border: Border.all(
                                    color: theme.colorScheme.outline,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.borderRadiusSm + 2,
                                  ),
                                ),
                              ),
                            )
                          : Hero(
                              tag: 'task-keyword-${widget.taskId}',
                              child: Material(
                                type: MaterialType.transparency,
                                child: Text(
                                  keyword.toUpperCase(),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
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
                      ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Column(
                  children: [
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.outline,
                    ),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: theme.colorScheme.primary,
                      indicatorWeight: 2,
                      labelColor: theme.colorScheme.onSurface,
                      unselectedLabelColor: theme.colorScheme.onSurface
                          .withValues(alpha: 0.62),
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.35,
                      ),
                      overlayColor: WidgetStatePropertyAll(
                        theme.colorScheme.primary.withValues(alpha: 0.06),
                      ),
                      tabs: [
                        Tab(text: l10n.report.toUpperCase()),
                        Tab(text: l10n.rawData.toUpperCase()),
                      ],
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.outline.withValues(alpha: 0.8),
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
