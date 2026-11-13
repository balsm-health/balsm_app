import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/records_detail.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:records/records.dart';

/// records-mc.jsx `EditRecordSheet`: the pencil on the record detail opens a
/// sheet to rename the record, change its type and date; saving stores it and
/// the detail shows the edit.
///
/// The record is invented by the test; nothing here is real patient data.
void main() {
  const user = UserId.value('u-1');
  const id = RecordDocumentId.value('r-1');

  Future<(PatientAppState, AppDatabase, HealthProfileId)> pump(WidgetTester tester, {bool ar = false}) async {
    final state = PatientAppState();
    if (ar) state.setLang(LanguageCode.ar);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final profile = await db.ensureSelfHealthProfile(user);
    final record = RecordDocument(
      id: id,
      userId: user,
      type: RecordType.lab,
      title: 'Test record',
      takenAt: DateTime(2026, 6, 12),
      createdAt: DateTime(2026, 6, 12),
    );
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserIdProvider.overrideWithValue(user),
      currentProfileIdProvider.overrideWithValue(profile),
    ]);
    addTearDown(container.dispose);
    await container.read(recordsDataSourceProvider).put(id, record);

    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: AppScope(
        state: state,
        child: MaterialApp(
          builder: (_, child) => Directionality(textDirection: state.dir, child: child!),
          home: RecordDetailScreen(record: record),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (state, db, profile);
  }

  Finder roundBtn(String label) => find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == label);

  testWidgets('saving the sheet stores the edit and the detail shows it', (tester) async {
    final (s, db, profile) = await pump(tester);
    final r = s.strings.records;
    expect(find.text('Test record'), findsOne);

    await tester.tap(roundBtn(s.strings.common.a11y_edit));
    await tester.pumpAndSettle();
    expect(find.text(r.rec_edit), findsOne);

    await tester.enterText(find.byType(TextField), 'Edited record');
    await tester.tap(find.text(r.rec_scan_one));
    await tester.pump();
    await tester.tap(find.text(r.rec_save_changes));
    await tester.pumpAndSettle();

    expect(find.text(r.rec_edit), findsNothing, reason: 'the sheet closes on save');
    expect(find.text('Edited record'), findsOne);
    expect(find.text(r.rec_scan_one), findsOne, reason: 'the type badge follows the edit');

    final stored = await DriftRecordsDataSource(db, () => profile).find(id);
    expect(stored!.title, 'Edited record');
    expect(stored.type, RecordType.scan);
  });

  testWidgets('an empty name cannot be saved', (tester) async {
    final (s, _, _) = await pump(tester);
    final r = s.strings.records;
    await tester.tap(roundBtn(s.strings.common.a11y_edit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    final save = tester.widget<PButton>(find.widgetWithText(PButton, r.rec_save_changes));
    expect(save.onTap, isNull);
  });

  testWidgets('the sheet lays out in Arabic', (tester) async {
    final (s, _, _) = await pump(tester, ar: true);
    await tester.tap(roundBtn(s.strings.common.a11y_edit));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.records.rec_edit), findsOne);
    expect(tester.takeException(), isNull);
  });
}
