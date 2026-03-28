import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/app.dart';

void main() {
  testWidgets('App renders with navigation bar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TrendPulseApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Analysis'), findsWidgets);
    expect(find.text('History'), findsWidgets);
    expect(find.text('Subscription'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
