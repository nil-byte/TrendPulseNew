import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/history/data/history_item.dart';
import 'package:trendpulse/features/history/data/history_repository.dart';
import 'package:trendpulse/features/history/presentation/pages/history_page.dart';
import 'package:trendpulse/features/history/presentation/providers/history_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class _PendingHistoryRepository extends HistoryRepository {
  final Completer<List<HistoryItem>> _never = Completer<List<HistoryItem>>();

  @override
  Future<List<HistoryItem>> getHistory() => _never.future;
}

Widget _wrap(HistoryRepository repository) {
  return ProviderScope(
    overrides: [historyRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: const HistoryPage(),
    ),
  );
}

void main() {
  testWidgets('history page loading state uses editorial card skeletons', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_PendingHistoryRepository()));
    await tester.pump();

    final shimmer = tester.widget<ShimmerLoading>(find.byType(ShimmerLoading));

    expect(shimmer.cardSkeleton, isTrue);
    expect(
      shimmer.padding,
      const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.sm,
      ),
    );
  });
}
