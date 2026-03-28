import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/app.dart';

void main() {
  testWidgets('App renders Analysis tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TrendPulseApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Analysis'), findsWidgets);
  });
}
