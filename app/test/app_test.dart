import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/app.dart';

void main() {
  testWidgets('App renders with navigation bar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TrendPulseApp()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('ANALYSIS'), findsWidgets);
    expect(find.text('HISTORY'), findsWidgets);
    expect(find.text('SUBSCRIPTION'), findsWidgets);
    expect(find.text('SETTINGS'), findsWidgets);
  });
}
