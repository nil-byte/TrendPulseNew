import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/widgets/loading_widget.dart';
import 'package:trendpulse/core/widgets/error_widget.dart';
import 'package:trendpulse/core/widgets/empty_widget.dart';

void main() {
  group('LoadingWidget', () {
    testWidgets('renders shimmer placeholders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingWidget())),
      );
      expect(find.byType(LoadingWidget), findsOneWidget);
    });

    testWidgets('respects itemCount parameter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingWidget(itemCount: 5))),
      );
      expect(find.byType(LoadingWidget), findsOneWidget);
    });
  });

  group('AppErrorWidget', () {
    testWidgets('displays error message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppErrorWidget(message: 'Something went wrong')),
        ),
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry is provided', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorWidget(
              message: 'Error',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppErrorWidget(message: 'Error')),
        ),
      );
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('EmptyWidget', () {
    testWidgets('displays message and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyWidget(message: 'No data available')),
        ),
      );
      expect(find.text('No data available'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('uses custom icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyWidget(message: 'Empty', icon: Icons.search_off),
          ),
        ),
      );
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });
  });
}
