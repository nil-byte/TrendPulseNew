import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/theme/app_spacing.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';
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

class _StaticSubscriptionRepository extends SubscriptionRepository {
  _StaticSubscriptionRepository(this.subscriptions);

  final List<Subscription> subscriptions;

  @override
  Future<List<Subscription>> getSubscriptions() async => subscriptions;
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository({required bool inAppNotify})
    : _inAppNotify = inAppNotify;

  final bool _inAppNotify;

  @override
  Future<bool> getInAppNotify() async => _inAppNotify;
}

Widget _wrap(
  SubscriptionRepository repository, {
  SettingsRepository? settingsRepository,
  bool initialInAppNotify = true,
}) {
  return ProviderScope(
    overrides: [
      subscriptionRepositoryProvider.overrideWithValue(repository),
      settingsRepositoryProvider.overrideWithValue(
        settingsRepository ?? _FakeSettingsRepository(inAppNotify: true),
      ),
      initialInAppNotifyProvider.overrideWithValue(initialInAppNotify),
    ],
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

  testWidgets(
    'subscription page shows unread alert badge on subscription card',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _StaticSubscriptionRepository([
            const Subscription(
              id: 'sub-1',
              keyword: 'AI Watch',
              contentLanguage: 'en',
              interval: 'daily',
              maxItems: 50,
              sources: ['reddit', 'youtube'],
              isActive: true,
              notify: true,
              createdAt: '2026-03-28T12:00:00Z',
              updatedAt: '2026-03-28T12:00:00Z',
              unreadAlertCount: 3,
              latestUnreadAlertTaskId: 'task-1',
              latestUnreadAlertScore: 18,
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('subscription-alert-badge-sub-1')),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets(
    'subscription page still shows unread alert badge when in-app notifications are disabled',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          _StaticSubscriptionRepository([
            const Subscription(
              id: 'sub-1',
              keyword: 'AI Watch',
              contentLanguage: 'en',
              interval: 'daily',
              maxItems: 50,
              sources: ['reddit', 'youtube'],
              isActive: true,
              notify: true,
              createdAt: '2026-03-28T12:00:00Z',
              updatedAt: '2026-03-28T12:00:00Z',
              unreadAlertCount: 3,
              latestUnreadAlertTaskId: 'task-1',
              latestUnreadAlertScore: 18,
            ),
          ]),
          settingsRepository: _FakeSettingsRepository(inAppNotify: false),
          initialInAppNotify: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('subscription-alert-badge-sub-1')),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
    },
  );
}
