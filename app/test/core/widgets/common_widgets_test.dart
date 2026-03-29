import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/animations/shimmer_loading.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/core/widgets/loading_widget.dart';
import 'package:trendpulse/core/widgets/error_widget.dart';
import 'package:trendpulse/core/widgets/empty_widget.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

Widget _wrapLocalized(
  Widget child, {
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}

void main() {
  group('LoadingWidget', () {
    testWidgets('renders ShimmerLoading placeholders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingWidget())),
      );
      expect(find.byType(LoadingWidget), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsOneWidget);
    });

    testWidgets('respects itemCount parameter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingWidget(itemCount: 5))),
      );
      expect(find.byType(LoadingWidget), findsOneWidget);
      expect(find.byType(ShimmerLoading), findsOneWidget);
    });

    testWidgets('uses square skeleton placeholders by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShimmerLoading(itemCount: 1))),
      );

      final placeholders = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ShimmerLoading),
          matching: find.byType(Container),
        ),
      );
      final placeholder = placeholders.firstWhere(
        (container) => container.constraints?.minHeight == 120,
      );
      final decoration = placeholder.decoration! as BoxDecoration;

      expect(decoration.borderRadius, BorderRadius.circular(0));
    });

    testWidgets('supports editorial card skeleton placeholders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ShimmerLoading(itemCount: 1, cardSkeleton: true)),
        ),
      );

      final shimmer = tester.widget<ShimmerLoading>(find.byType(ShimmerLoading));
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ShimmerLoading),
          matching: find.byType(Container),
        ),
      );

      expect(shimmer.cardSkeleton, isTrue);
      expect(
        containers.any(
          (container) =>
              container.constraints?.minWidth == 24 &&
              container.constraints?.maxWidth == 24 &&
              container.constraints?.minHeight == 24 &&
              container.constraints?.maxHeight == 24,
        ),
        isTrue,
      );
      expect(
        containers.any(
          (container) =>
              container.constraints?.minWidth == 48 &&
              container.constraints?.maxWidth == 48 &&
              container.constraints?.minHeight == 18 &&
              container.constraints?.maxHeight == 18,
        ),
        isTrue,
      );
    });

    testWidgets('card skeleton honors height, outline, and radius parameters', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerLoading(
              itemCount: 1,
              itemHeight: 160,
              borderRadius: 12,
              showOutline: false,
              cardSkeleton: true,
            ),
          ),
        ),
      );

      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ShimmerLoading),
          matching: find.byType(Container),
        ),
      );
      final skeleton = containers.firstWhere(
        (container) => container.constraints?.minHeight == 160,
      );
      final decoration = skeleton.decoration! as BoxDecoration;

      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(decoration.border, isNull);
    });
  });

  group('AppErrorWidget', () {
    testWidgets('displays error message', (tester) async {
      await tester.pumpWidget(
        _wrapLocalized(const AppErrorWidget(message: 'Something went wrong')),
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry is provided', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        _wrapLocalized(
          AppErrorWidget(
            message: 'Error',
            onRetry: () => retried = true,
          ),
        ),
      );
      expect(find.text('RETRY'), findsOneWidget);
      await tester.tap(find.text('RETRY'));
      expect(retried, isTrue);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(
        _wrapLocalized(const AppErrorWidget(message: 'Error')),
      );
      expect(find.text('RETRY'), findsNothing);
    });

    testWidgets('localizes title and default retry label in Chinese', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapLocalized(
          AppErrorWidget(
            message: '请求失败',
            onRetry: () {},
          ),
          locale: const Locale('zh'),
        ),
      );

      expect(find.text('系统错误'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('SYSTEM ERROR'), findsNothing);
      expect(find.text('RETRY'), findsNothing);
    });
  });

  group('EmptyWidget', () {
    testWidgets('displays message with editorial ornament', (tester) async {
      await tester.pumpWidget(
        _wrapLocalized(const EmptyWidget(message: 'No data available')),
      );
      expect(find.text('No data available'), findsOneWidget);
      expect(find.text('•  •  •'), findsOneWidget);
      expect(find.text('———  ·  ———'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsNothing);
    });

    testWidgets('keeps editorial ornament even when a legacy icon is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapLocalized(
          const EmptyWidget(message: 'Empty', icon: Icons.search_off),
        ),
      );
      expect(find.text('•  •  •'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsNothing);
    });

    testWidgets('localizes the default empty title in Chinese', (tester) async {
      await tester.pumpWidget(
        _wrapLocalized(
          const EmptyWidget(message: '这里还没有内容'),
          locale: const Locale('zh'),
        ),
      );

      expect(find.text('暂无内容'), findsOneWidget);
      expect(find.text('NO CONTENT'), findsNothing);
    });
  });
}
