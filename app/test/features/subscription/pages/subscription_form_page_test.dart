import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_colors.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/core/theme/app_typography.dart';
import 'package:trendpulse/features/settings/data/notification_settings.dart';
import 'package:trendpulse/features/settings/data/notification_settings_repository.dart';
import 'package:trendpulse/features/settings/data/settings_repository.dart';
import 'package:trendpulse/features/settings/presentation/providers/settings_provider.dart';
import 'package:trendpulse/features/subscription/data/subscription_model.dart';
import 'package:trendpulse/features/subscription/data/subscription_request.dart';
import 'package:trendpulse/features/subscription/data/subscription_repository.dart';
import 'package:trendpulse/features/subscription/presentation/pages/subscription_form_page.dart';
import 'package:trendpulse/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

class _FakeNotificationSettingsRepository
    extends NotificationSettingsRepository {
  _FakeNotificationSettingsRepository({bool subscriptionNotifyDefault = true})
    : _settings = NotificationSettings(
        subscriptionNotifyDefault: subscriptionNotifyDefault,
      );

  NotificationSettings _settings;

  @override
  Future<NotificationSettings> getNotificationSettings() async => _settings;

  @override
  Future<NotificationSettings> updateNotificationSettings({
    required bool subscriptionNotifyDefault,
    required bool applyToExisting,
  }) async {
    _settings = NotificationSettings(
      subscriptionNotifyDefault: subscriptionNotifyDefault,
    );
    return _settings;
  }
}

class _PendingNotificationSettingsRepository
    extends NotificationSettingsRepository {
  final Completer<NotificationSettings> _never =
      Completer<NotificationSettings>();

  @override
  Future<NotificationSettings> getNotificationSettings() => _never.future;

  @override
  Future<NotificationSettings> updateNotificationSettings({
    required bool subscriptionNotifyDefault,
    required bool applyToExisting,
  }) async {
    return NotificationSettings(
      subscriptionNotifyDefault: subscriptionNotifyDefault,
    );
  }
}

class _FakeSubscriptionRepository extends SubscriptionRepository {
  _FakeSubscriptionRepository(this.subscription);

  final Subscription subscription;
  SubscriptionUpsertRequest? createdRequest;

  @override
  Future<Subscription> getSubscription(String id) async => subscription;

  @override
  Future<Subscription> createSubscription(
    SubscriptionUpsertRequest request,
  ) async {
    createdRequest = request;
    return subscription;
  }
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository(this.language);

  final String language;

  @override
  Future<String> getLanguage() async => language;

  @override
  Future<String> getReportLanguage({String? baseUrl}) async => language;

  @override
  Future<String> setReportLanguage(String language, {String? baseUrl}) async =>
      language;
}

Widget _wrap(
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  NotificationSettingsRepository? notificationSettingsRepository,
  SubscriptionRepository? subscriptionRepository,
}) {
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(
        _FakeSettingsRepository(locale.languageCode),
      ),
      notificationSettingsRepositoryProvider.overrideWithValue(
        notificationSettingsRepository ?? _FakeNotificationSettingsRepository(),
      ),
      initialLanguageProvider.overrideWithValue(locale.languageCode),
      initialLanguagePreloadedProvider.overrideWithValue(true),
      if (subscriptionRepository != null)
        subscriptionRepositoryProvider.overrideWithValue(
          subscriptionRepository,
        ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: theme ?? AppTheme.light,
      home: child,
    ),
  );
}

void main() {
  testWidgets(
    'subscription form waits for remote alert default before rendering new entry switch',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SubscriptionFormPage(),
          notificationSettingsRepository:
              _PendingNotificationSettingsRepository(),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    },
  );

  testWidgets(
    'subscription form uses remote low-score alert default for new subscriptions',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SubscriptionFormPage(),
          notificationSettingsRepository: _FakeNotificationSettingsRepository(
            subscriptionNotifyDefault: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('ENABLE LOW-SCORE ALERTS'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    },
  );

  testWidgets(
    'subscription form edit keeps subscription notify value over remote default',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SubscriptionFormPage(subId: 'sub-1'),
          notificationSettingsRepository: _FakeNotificationSettingsRepository(
            subscriptionNotifyDefault: true,
          ),
          subscriptionRepository: _FakeSubscriptionRepository(
            const Subscription(
              id: 'sub-1',
              keyword: 'AI Watch',
              contentLanguage: 'en',
              interval: 'daily',
              maxItems: 50,
              sources: ['reddit'],
              isActive: true,
              notify: false,
              createdAt: '2026-03-28T12:00:00Z',
              updatedAt: '2026-03-28T12:00:00Z',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    },
  );

  testWidgets(
    'subscription form sends remote low-score alert default in new subscription request',
    (tester) async {
      final repository = _FakeSubscriptionRepository(
        const Subscription(
          id: 'sub-created',
          keyword: 'AI Watch',
          contentLanguage: 'en',
          interval: 'daily',
          maxItems: 50,
          sources: ['reddit'],
          isActive: true,
          notify: true,
          createdAt: '2026-03-28T12:00:00Z',
          updatedAt: '2026-03-28T12:00:00Z',
        ),
      );

      await tester.pumpWidget(
        _wrap(
          const SubscriptionFormPage(),
          notificationSettingsRepository: _FakeNotificationSettingsRepository(
            subscriptionNotifyDefault: true,
          ),
          subscriptionRepository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'AI Watch');
      await tester.dragUntilVisible(
        find.text('SAVE SUBSCRIPTION'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.tap(find.text('SAVE SUBSCRIPTION'));
      await tester.pumpAndSettle();

      expect(repository.createdRequest, isNotNull);
      expect(repository.createdRequest!.contentLanguage, 'en');
      expect(repository.createdRequest!.toJson(), containsPair('content_language', 'en'));
      expect(repository.createdRequest!.toJson().containsKey('language'), isFalse);
      expect(
        repository.createdRequest!.toJson().containsKey('report_language'),
        isFalse,
      );
      expect(repository.createdRequest!.notify, isTrue);
    },
  );

  testWidgets(
    'subscription form defers segmented, switch, and primary button styling to theme',
    (tester) async {
      await tester.pumpWidget(_wrap(const SubscriptionFormPage()));
      await tester.pumpAndSettle();

      final segmentedButtons = tester.widgetList<SegmentedButton<String>>(
        find.byWidgetPredicate((widget) => widget is SegmentedButton<String>),
      );
      expect(segmentedButtons, isNotEmpty);
      for (final segmented in segmentedButtons) {
        expect(segmented.style, isNull);
      }

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsNothing);

      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.thumbColor, isNull);
      expect(toggle.trackColor, isNull);
      expect(toggle.trackOutlineColor, isNull);

      final filledButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(filledButton.style, isNull);
    },
  );

  testWidgets(
    'subscription interval selector keeps accessible tap targets and button semantics',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(_wrap(const SubscriptionFormPage()));
      await tester.pumpAndSettle();

      final dailySegment = find.byKey(
        const ValueKey('subscription-interval-daily'),
      );
      final weeklySegment = find.byKey(
        const ValueKey('subscription-interval-weekly'),
      );

      expect(dailySegment, findsOneWidget);
      expect(weeklySegment, findsOneWidget);
      expect(tester.getSize(dailySegment).height, greaterThanOrEqualTo(48));

      expect(
        tester.getSemantics(dailySegment),
        matchesSemantics(
          label: 'Daily',
          hasTapAction: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          isButton: true,
          isFocusable: true,
        ),
      );
      expect(
        tester.getSemantics(weeklySegment),
        matchesSemantics(
          label: 'Weekly',
          hasTapAction: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: false,
          isButton: true,
          isFocusable: true,
        ),
      );

      semanticsHandle.dispose();
    },
  );

  testWidgets('subscription source chips avoid harsh onSurface fill', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SubscriptionFormPage()));
    await tester.pumpAndSettle();

    final pageContext = tester.element(find.byType(SubscriptionFormPage));
    final theme = Theme.of(pageContext);
    final chip = tester.widget<FilterChip>(find.byType(FilterChip).first);

    expect(chip.selectedColor, isNot(theme.colorScheme.onSurface));
  });

  testWidgets(
    'subscription source chips inherit the bundled editorial sans family',
    (tester) async {
      await tester.pumpWidget(_wrap(const SubscriptionFormPage()));
      await tester.pumpAndSettle();

      final chip = tester.widget<FilterChip>(find.byType(FilterChip).first);

      expect(chip.labelStyle?.fontFamily, AppTypography.editorialSansFamily);
    },
  );

  testWidgets(
    'subscription X source chip uses a readable dark foreground in dark theme',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const SubscriptionFormPage(), theme: AppTheme.dark),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('X'));
      await tester.pumpAndSettle();

      final xChip = tester.widgetList<FilterChip>(find.byType(FilterChip)).last;

      expect(xChip.selected, isTrue);
      expect(xChip.labelStyle?.color, AppColors.lightInk);
    },
  );

  testWidgets('subscription keyword field uses editorial square borders', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const SubscriptionFormPage()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SubscriptionFormPage));
    final decoration = Theme.of(context).inputDecorationTheme;
    final border = decoration.enabledBorder! as OutlineInputBorder;

    expect(decoration.filled, isTrue);
    expect(border.borderRadius, BorderRadius.zero);
  });

  testWidgets('subscription form localizes editorial labels in Chinese', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const SubscriptionFormPage(), locale: const Locale('zh')),
    );
    await tester.pumpAndSettle();

    expect(find.text('新建条目'), findsOneWidget);
    expect(find.text('关注主题'), findsOneWidget);
    expect(find.text('输入关键词...'), findsOneWidget);
    expect(find.text('频率'), findsOneWidget);
    expect(find.text('每小时'), findsOneWidget);
    expect(find.text('每6小时'), findsOneWidget);
    expect(find.text('1H'), findsNothing);
    expect(find.text('NEW ENTRY'), findsNothing);
    expect(find.text('SUBJECT OF INQUIRY'), findsNothing);
  });
}
