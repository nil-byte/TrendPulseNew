import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:trendpulse/core/theme/app_spacing.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
              expandedHeight: 120,
              forceElevated: innerBoxIsScrolled,
              flexibleSpace: FlexibleSpaceBar(
                title: Hero(
                  tag: 'task-keyword-${widget.taskId}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      keyword,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 56,
                  bottom: AppSpacing.xxl + 4,
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: l10n.report),
                  Tab(text: l10n.rawData),
                ],
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
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
