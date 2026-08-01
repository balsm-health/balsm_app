import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens on the initial month and returns the selected date', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              picked = await showBalsmDatePicker(
                context,
                initial: DateTime(2020, 6, 15),
                firstDate: DateTime(2020, 1, 1),
                lastDate: DateTime(2020, 12, 31),
                title: 'Pick a date',
                confirmLabel: 'OK',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('June 2020'), findsOneWidget);

    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(picked, DateTime(2020, 6, 20));
  });

  testWidgets('a day after lastDate is not selectable', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              picked = await showBalsmDatePicker(
                context,
                initial: DateTime(2020, 6, 10),
                firstDate: DateTime(2020, 6, 1),
                lastDate: DateTime(2020, 6, 15),
                title: 'Pick a date',
                confirmLabel: 'OK',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Day 20 is after lastDate (15) → tapping it must not change the selection.
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(picked, DateTime(2020, 6, 10), reason: 'disabled day must not override the initial selection');
  });
}
