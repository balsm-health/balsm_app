import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/day_records_screen.dart';
import 'package:app/balsm_app/vault/memory_file_store.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:self_report/self_report.dart';

/// `home.jsx` DayRecordsScreen — each reading's ⋮ menu deletes it, with Undo
/// before anything is stored.
///
/// The readings are invented by the test; nothing here is real patient data.
class _Recorder implements UpdateCheckInUseCase {
  final stored = <CheckIn>[];

  @override
  CheckInsDataSource get dao => throw UnimplementedError();

  @override
  Future<bool> call(CheckIn edited) async {
    stored.add(edited);
    return !edited.isEmpty;
  }
}

void main() {
  final bpOnly = CheckIn(
    id: const CheckInId.value('chk-1'),
    healthProfileId: const HealthProfileId.value('hp-1'),
    recordedAt: DateTime.utc(2026, 7, 24, 9),
    painLevel: PainLevel.none,
    painSites: const {},
    symptoms: const {},
    vitals: const Vitals(systolic: 118, diastolic: 76, glucoseFasting: 95),
  );

  Future<(_Recorder, PatientAppState)> pump(WidgetTester tester, CheckIn checkIn, {bool ar = false}) async {
    final recorder = _Recorder();
    final state = PatientAppState();
    if (ar) state.setLang(LanguageCode.ar);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        userFileStoreProvider.overrideWithValue(MemoryUserFileStore()),
        updateCheckInUseCaseProvider.overrideWithValue(recorder),
      ],
      child: AppScope(state: state, child: MaterialApp(home: DayRecordsScreen(checkIn: checkIn))),
    ));
    await tester.pumpAndSettle();
    return (recorder, state);
  }

  Future<void> deleteReading(WidgetTester tester, PatientAppState s, String label) async {
    await tester
        .tap(find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == s.strings.checkin.rec_more(label)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.strings.checkin.rec_delete));
    await tester.pumpAndSettle();
  }

  testWidgets('a quick BP log shows no pain row', (tester) async {
    final (_, s) = await pump(tester, bpOnly);
    expect(find.text(s.strings.profile.m_pain), findsNothing);
    expect(find.textContaining('118/76', findRichText: true), findsOne);
  });

  testWidgets('delete hides the reading, and Undo brings it back unstored', (tester) async {
    final (recorder, s) = await pump(tester, bpOnly);
    await deleteReading(tester, s, s.strings.profile.m_bp);

    expect(find.textContaining('118/76', findRichText: true), findsNothing);
    expect(find.text(s.strings.checkin.rec_deleted(s.strings.profile.m_bp)), findsOne);

    await tester.tap(find.text(s.strings.common.undo));
    await tester.pump(const Duration(seconds: 6));
    expect(find.textContaining('118/76', findRichText: true), findsOne);
    expect(recorder.stored, isEmpty);
  });

  testWidgets('the edit is stored once the Undo toast closes', (tester) async {
    final (recorder, s) = await pump(tester, bpOnly);
    await deleteReading(tester, s, s.strings.profile.m_bp);
    await tester.pump(const Duration(seconds: 6));

    expect(find.text(s.strings.checkin.rec_deleted(s.strings.profile.m_bp)), findsNothing);
    expect(recorder.stored.single.vitals.systolic, isNull);
    expect(recorder.stored.single.vitals.glucoseFasting, 95);
  });

  testWidgets('deleting the last reading empties the day', (tester) async {
    final (recorder, s) = await pump(tester, bpOnly);
    await deleteReading(tester, s, s.strings.profile.m_bp);
    await deleteReading(tester, s, s.strings.profile.m_glucose);

    expect(find.text(s.strings.checkin.day_empty), findsOne);
    await tester.pump(const Duration(seconds: 6));
    // The first delete is stored when the second closes its Undo.
    expect(recorder.stored.length, 2);
    expect(recorder.stored.last.isEmpty, isTrue);
  });

  testWidgets('the menu and Undo lay out right to left in Arabic', (tester) async {
    final (recorder, s) = await pump(tester, bpOnly, ar: true);
    await deleteReading(tester, s, s.strings.profile.m_bp);
    expect(find.text(s.strings.checkin.rec_deleted(s.strings.profile.m_bp)), findsOne);
    await tester.pump(const Duration(seconds: 6));
    expect(recorder.stored.single.vitals.systolic, isNull);
  });
}
