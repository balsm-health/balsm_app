import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/records_screen.dart';
import 'package:core/core.dart' show UserId, currentUserIdProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:records/records.dart';

/// `UX Enhancement Screens.html` — "Records · bulk select": long-press enters
/// selection, a tinted bar counts what is picked, and the bin acts on all of
/// them at once.
void main() {
  RecordDocument doc(String id, String title) => RecordDocument(
        id: RecordDocumentId.value(id),
        userId: const UserId.value('u-1'),
        type: RecordType.lab,
        title: title,
        takenAt: DateTime.utc(2026, 6, 12),
        createdAt: DateTime.utc(2026, 6, 12),
      );

  Future<PatientAppState> pump(WidgetTester tester, List<RecordDocument> records) async {
    final state = PatientAppState();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        recordListProvider.overrideWith((ref) => Stream.value(records)),
        // Bulk delete is scoped to the signed-in user; without one it is a
        // no-op by design.
        currentUserIdProvider.overrideWithValue(const UserId.value('u-1')),
      ],
      child: AppScope(
        state: state,
        child: const MaterialApp(home: Scaffold(body: RecordsScreen())),
      ),
    ));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('the list browses normally until a long press', (tester) async {
    final s = await pump(tester, [doc('r1', 'CBC blood panel')]);
    expect(find.text(s.strings.records.records), findsOne);
    expect(find.text(s.strings.records.rec_n_selected('1')), findsNothing);
  });

  testWidgets('long press selects that record and opens the bar', (tester) async {
    final s = await pump(tester, [doc('r1', 'CBC blood panel'), doc('r2', 'Chest X-ray')]);
    await tester.longPress(find.text('CBC blood panel'));
    await tester.pumpAndSettle();

    expect(find.text(s.strings.records.rec_n_selected('1')), findsOne);
    // The browsing title gives way to the count.
    expect(find.text(s.strings.records.records), findsNothing);
  });

  testWidgets('tapping adds and removes from the selection', (tester) async {
    final s = await pump(tester, [doc('r1', 'CBC blood panel'), doc('r2', 'Chest X-ray')]);
    await tester.longPress(find.text('CBC blood panel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chest X-ray'));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.records.rec_n_selected('2')), findsOne);

    await tester.tap(find.text('Chest X-ray'));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.records.rec_n_selected('1')), findsOne);
  });

  testWidgets('closing the bar returns to browsing', (tester) async {
    final s = await pump(tester, [doc('r1', 'CBC blood panel')]);
    await tester.longPress(find.text('CBC blood panel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.records.records), findsOne);
  });

  testWidgets('deleting asks first — bulk PHI deletion is irreversible', (tester) async {
    final s = await pump(tester, [doc('r1', 'CBC blood panel')]);
    await tester.longPress(find.text('CBC blood panel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.records.rec_delete_1_title), findsOne);
    expect(find.text(s.strings.records.rec_delete_n_body), findsOne);

    // Backing out leaves the selection untouched and deletes nothing.
    await tester.tap(find.text(s.strings.common.cancel));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.records.rec_n_selected('1')), findsOne);
    expect(find.text('CBC blood panel'), findsOne);
  });
}
