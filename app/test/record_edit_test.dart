import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/records_detail.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:records/records.dart';

/// records-mc.jsx `AddRecordSheet` `initial`: the pencil on the record detail
/// opens the full add-record sheet on the record — title, type, date, time and
/// tags filled in, attachment kept — and saving stores the edit, which the
/// detail then shows.
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
      tags: const ['Tag one'],
      filePath: 'vault/r-1.pdf',
      fileType: 'PDF',
      takenAt: DateTime(2026, 6, 12, 14, 30),
      createdAt: DateTime(2026, 6, 12),
    );
    final container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue(user),
        currentProfileIdProvider.overrideWithValue(profile),
      ],
    );
    addTearDown(container.dispose);
    await container.read(recordsDataSourceProvider).put(id, record);

    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: AppScope(
          state: state,
          child: MaterialApp(
            builder: (_, child) => Directionality(textDirection: state.dir, child: child!),
            home: RecordDetailScreen(record: record),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (state, db, profile);
  }

  Finder roundBtn(String label) => find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == label);

  Future<void> openEdit(WidgetTester tester, PatientAppState s) async {
    await tester.tap(roundBtn(s.strings.common.a11y_edit));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester, PatientAppState s) async {
    final button = find.text(s.strings.records.rec_save_changes);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the add-record sheet opens on the record, filled in', (tester) async {
    final (s, _, _) = await pump(tester);
    final r = s.strings.records;
    await openEdit(tester, s);

    expect(find.text(r.rec_edit_title(r.rec_lab_one)), findsOne);
    expect(find.widgetWithText(TextField, 'Test record'), findsOne);
    expect(find.text('Tag one'), findsWidgets);
    expect(find.text(r.rec_save_changes), findsOne);
    expect(find.text(s.strings.settings.add_record), findsNothing);
  });

  testWidgets('saving stores the edit, says so, and the detail shows it', (tester) async {
    final (s, db, profile) = await pump(tester);
    final r = s.strings.records;
    await openEdit(tester, s);

    await tester.enterText(find.widgetWithText(TextField, 'Test record'), 'Edited record');
    await save(tester, s);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(r.rec_changes_saved), findsOne);
    expect(find.text(r.rec_added_h), findsNothing, reason: 'an edit has no subtitle');

    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text(r.rec_changes_saved), findsNothing, reason: 'the sheet closes after saving');
    expect(find.text('Edited record'), findsOne);

    final stored = await DriftRecordsDataSource(db, () => profile).find(id);
    expect(stored!.title, 'Edited record');
    expect(stored.tags, ['Tag one']);
    expect(stored.takenAt, DateTime(2026, 6, 12, 14, 30));
    expect(stored.filePath, 'vault/r-1.pdf', reason: 'the attachment is kept');
  });

  testWidgets('Back leads to the type picker to change the type', (tester) async {
    final (s, db, profile) = await pump(tester);
    final r = s.strings.records;
    await openEdit(tester, s);

    await tester.tap(roundBtn(s.strings.common.a11y_back).last);
    await tester.pumpAndSettle();
    expect(find.text(r.rec_pick_type), findsOne);
    await tester.tap(find.text(r.rec_scan_one).last);
    await tester.pumpAndSettle();
    expect(find.text(r.rec_edit_title(r.rec_scan_one)), findsOne);

    await save(tester, s);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final stored = await DriftRecordsDataSource(db, () => profile).find(id);
    expect(stored!.type, RecordType.scan);
    expect(stored.title, 'Test record');
  });

  testWidgets('a blank name falls back to the type, as a new record does', (tester) async {
    final (s, db, profile) = await pump(tester);
    await openEdit(tester, s);
    await tester.enterText(find.widgetWithText(TextField, 'Test record'), '   ');
    await save(tester, s);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final stored = await DriftRecordsDataSource(db, () => profile).find(id);
    expect(stored!.title, s.strings.records.rec_lab_one);
  });

  testWidgets('the sheet lays out in Arabic', (tester) async {
    final (s, _, _) = await pump(tester, ar: true);
    await openEdit(tester, s);
    expect(find.text(s.strings.records.rec_edit_title(s.strings.records.rec_lab_one)), findsOne);
    expect(tester.takeException(), isNull);
  });
}
