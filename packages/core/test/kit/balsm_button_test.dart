import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget button(double textScale) => MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: BalsmButton(
                  label: 'A long action label that needs more than one line at large text sizes',
                  variant: BalsmButtonVariant.danger,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('a long label wraps instead of overflowing at large system text', (tester) async {
    await tester.pumpWidget(button(2));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BalsmButton)).height, greaterThan(56));
  });

  testWidgets('keeps its 56 dp height at normal text size', (tester) async {
    await tester.pumpWidget(button(1));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BalsmButton)).height, greaterThanOrEqualTo(56));
  });
}
