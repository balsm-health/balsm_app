import 'package:core/core.dart' show noProviderRetry;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:medications/src/presentation/screens/add_medication_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    // Tall enough that the whole form is built at once.
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(
        retry: noProviderRetry,
        child: MaterialApp(home: AddMedicationScreen()),
      ),
    );
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save medication'));
    await tester.pump();
  }

  testWidgets('saving without a name flags the name and clears once typed', (tester) async {
    await pump(tester);
    await save(tester);
    expect(find.text('Name is required'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'x');
    await save(tester);
    expect(find.text('Name is required'), findsNothing);
  });

  testWidgets('the day picker shows only for a schedule that is not daily', (tester) async {
    await pump(tester);
    expect(find.text('M'), findsNothing);
    await tester.tap(find.text('Weekly'));
    await tester.pump();
    expect(find.text('M'), findsOneWidget);
  });
}
