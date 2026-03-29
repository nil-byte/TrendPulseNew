import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/widgets/editorial_switch_row.dart';

void main() {
  testWidgets('editorial switch row toggles from row tap', (tester) async {
    bool value = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return EditorialSwitchRow(
                title: const Text('Enable Alerts'),
                value: value,
                onChanged: (next) => setState(() => value = next),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(Switch), findsOneWidget);
    expect(value, isFalse);

    await tester.tap(find.text('Enable Alerts'));
    await tester.pumpAndSettle();

    expect(value, isTrue);
  });
}
