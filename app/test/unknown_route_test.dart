import 'package:app/balsm_app/shell.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// BALSM-APP-Y: a route the OS pushes straight into Flutter's default
/// Navigator channel (a universal/app link the platform also forwards
/// through `pushRouteInformation`) must not crash the app just because the
/// shell has no named-route table for it.
void main() {
  testWidgets('an unrecognized pushed route is swallowed, not a crash', (tester) async {
    await tester.pumpWidget(MaterialApp(
      onUnknownRoute: handleUnknownRoute,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).pushNamed('/?type=lab'),
          child: const Text('trigger'),
        ),
      ),
    ));

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('trigger'), findsOneWidget, reason: 'the underlying screen must still be showing');
  });
}
