import 'package:deletion/deletion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// FR-031 / FR-513: the pre-confirm screen is a compliance artifact — it must
/// list exhaustively and accurately what is kept, deleted from Balsm's servers,
/// and wiped from the phone.
///
/// Care team used to be device-only, so naming it under "Wiped" alone was true.
/// Now that it is mirrored to Balsm's database it belongs in BOTH columns, and a
/// screen that still says only "wiped" is a false statement to the patient at
/// the moment they are deciding.
void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: DeleteAccountScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('care team is named under both Deleted and Wiped', (tester) async {
    await pump(tester);

    final deleted = find.ancestor(
      of: find.text('Deleted'),
      matching: find.byType(Column),
    );
    final wiped = find.ancestor(
      of: find.text('Wiped'),
      matching: find.byType(Column),
    );

    expect(
      find.descendant(of: deleted.first, matching: find.textContaining('Care team')),
      findsOneWidget,
      reason: 'care team now leaves Balsm servers too, so it must appear under Deleted',
    );
    expect(
      find.descendant(of: wiped.first, matching: find.textContaining('Care team')),
      findsOneWidget,
      reason: 'care team is still wiped from the device',
    );
  });

  testWidgets('the three disclosure columns are all present', (tester) async {
    await pump(tester);

    expect(find.text('Retained'), findsOneWidget);
    expect(find.text('Deleted'), findsOneWidget);
    expect(find.text('Wiped'), findsOneWidget);
  });
}
