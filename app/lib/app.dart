import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/animations/page_transitions.dart';
import 'core/theme/app_theme.dart';
import 'features/analysis/presentation/pages/analysis_page.dart';
import 'features/detail/presentation/pages/detail_page.dart';
import 'features/history/presentation/pages/history_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'features/subscription/presentation/pages/subscription_form_page.dart';
import 'features/subscription/presentation/pages/subscription_page.dart';
import 'features/subscription/presentation/pages/subscription_tasks_page.dart';
import 'l10n/app_localizations.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _analysisShellKey = GlobalKey<NavigatorState>(debugLabel: 'analysis');
final _historyShellKey = GlobalKey<NavigatorState>(debugLabel: 'history');
final _subscriptionShellKey = GlobalKey<NavigatorState>(
  debugLabel: 'subscription',
);
final _settingsShellKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/analysis',
  routes: [
    // Top-level detail push (from analysis search)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/detail/:taskId',
      pageBuilder: (context, state) => slideUpTransitionPage(
        state: state,
        child: DetailPage(taskId: state.pathParameters['taskId']!),
      ),
    ),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _ScaffoldWithNav(navigationShell: navigationShell),
      branches: [
        // Tab 0: Analysis
        StatefulShellBranch(
          navigatorKey: _analysisShellKey,
          routes: [
            GoRoute(
              path: '/analysis',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AnalysisPage()),
            ),
          ],
        ),

        // Tab 1: History
        StatefulShellBranch(
          navigatorKey: _historyShellKey,
          routes: [
            GoRoute(
              path: '/history',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: HistoryPage()),
              routes: [
                GoRoute(
                  path: 'detail/:taskId',
                  pageBuilder: (context, state) => slideUpTransitionPage(
                    state: state,
                    child: DetailPage(taskId: state.pathParameters['taskId']!),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Tab 2: Subscription
        StatefulShellBranch(
          navigatorKey: _subscriptionShellKey,
          routes: [
            GoRoute(
              path: '/subscription',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SubscriptionPage()),
              routes: [
                GoRoute(
                  path: 'new',
                  pageBuilder: (context, state) => slideUpTransitionPage(
                    state: state,
                    child: const SubscriptionFormPage(),
                  ),
                ),
                GoRoute(
                  path: ':subId/edit',
                  pageBuilder: (context, state) => slideUpTransitionPage(
                    state: state,
                    child: SubscriptionFormPage(
                      subId: state.pathParameters['subId'],
                    ),
                  ),
                ),
                GoRoute(
                  path: ':subId/tasks',
                  pageBuilder: (context, state) => slideUpTransitionPage(
                    state: state,
                    child: SubscriptionTasksPage(
                      subId: state.pathParameters['subId']!,
                    ),
                  ),
                  routes: [
                    GoRoute(
                      path: 'detail/:taskId',
                      pageBuilder: (context, state) => slideUpTransitionPage(
                        state: state,
                        child: DetailPage(
                          taskId: state.pathParameters['taskId']!,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Tab 3: Settings
        StatefulShellBranch(
          navigatorKey: _settingsShellKey,
          routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SettingsPage()),
            ),
          ],
        ),
      ],
    ),
  ],
);

class _ScaffoldWithNav extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _ScaffoldWithNav({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.analytics_outlined),
            selectedIcon: const Icon(Icons.analytics),
            label: l10n.analysisTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n.historyTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.subscriptions_outlined),
            selectedIcon: const Icon(Icons.subscriptions),
            label: l10n.subscriptionTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settingsTab,
          ),
        ],
      ),
    );
  }
}

class TrendPulseApp extends ConsumerWidget {
  const TrendPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final language = ref.watch(defaultLanguageProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}
