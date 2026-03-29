import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/subscription/data/subscription_model.dart';
import 'package:trendpulse/features/subscription/data/subscription_repository.dart';
import 'package:trendpulse/features/subscription/presentation/pages/subscription_page.dart';
import 'package:trendpulse/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class _PendingSubscriptionRepository extends SubscriptionRepository {
  final Completer<List<Subscription>> _never = Completer<List<Subscription>>();

  @override
  Future<List<Subscription>> getSubscriptions() => _never.future;
}

Widget _wrap(SubscriptionRepository repository) {
  return ProviderScope(
    overrides: [subscriptionRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: const SubscriptionPage(),
    ),
  );
}

void main() {
  testWidgets('subscription page loading state uses editorial card skeletons', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_PendingSubscriptionRepository()));
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
