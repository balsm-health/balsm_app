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

/// `home.jsx` DayRecordsScreen — a reading is deleted from its ⋮ menu, by
/// swiping it, or with Select; each asks first, then stores at once.
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
      child: AppScope(
        state: state,
        // The app sets direction above the navigator (shell.dart), so dialogs
        // and menus follow it too.
        child: MaterialApp(
          builder: (_, child) => Directionality(textDirection: state.dir, child: child!),
          home: DayRecordsScreen(checkIn: checkIn),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (recorder, state);
  }

  Finder value(String text) => find.textContaining(text, findRichText: true);

  Future<void> openMenu(WidgetTester tester, PatientAppState s, String label) async {
    await tester
        .tap(find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == s.strings.checkin.rec_more(label)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.strings.checkin.rec_delete));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester, PatientAppState s) async {
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text(s.strings.checkin.rec_delete_short)));
    await tester.pumpAndSettle();
  }

  testWidgets('a quick BP log shows no pain row', (tester) async {
    final (_, s) = await pump(tester, bpOnly);
    expect(find.text(s.strings.profile.m_pain), findsNothing);
    expect(value('118/76'), findsOne);
  });

  testWidgets('the menu asks first, then stores the delete at once', (tester) async {
    final (recorder, s) = await pump(tester, bpOnly);
    await openMenu(tester, s, s.strings.profile.m_bp);

    final c = s.strings.checkin;
    expect(find.text(c.rec_del_title(s.strings.profile.m_bp.toLowerCase())), findsOne);
    expect(recorder.stored, isEmpty);
    await confirm(tester, s);

    expect(value('118/76'), findsNothing);
    expect(find.text(c.rec_deleted(s.strings.profile.m_bp)), findsOne);
    expect(recorder.stored.single.vitals.systolic, isNull);
    expect(recorder.stored.single.vitals.glucoseFasting, 95);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text(c.rec_deleted(s.strings.profile.m_bp)), findsNothing);
  });

  testWidgets('Cancel keeps the reading and stores nothing', (tester) async {
    final (recorder, s) = await pump(tester, bpOnly);
    await openMenu(tester, s, s.strings.profile.m_bp);
    await tester.tap(find.text(s.strings.common.cancel));
    await tester.pumpAndSettle();

    expect(value('118/76'), findsOne);
    expect(recorder.stored, isEmpty);
  });

  testWidgets('a short swipe reveals Delete; a long one asks at once', (tester) async {
    final (recorder, s) = await pump(tester, bpOnly);
    final c = s.strings.checkin;

    await tester.drag(find.text(s.strings.profile.m_glucose), const Offset(-70, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(c.rec_delete_short));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOne);
    await tester.tap(find.text(s.strings.common.cancel));
    await tester.pumpAndSettle();

    await tester.drag(find.text(s.strings.profile.m_bp), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await confirm(tester, s);
    expect(recorder.stored.single.vitals.systolic, isNull);
    expect(recorder.stored.single.vitals.glucoseFasting, 95);
  });

  testWidgets('Select deletes several readings in one store and empties the day', (tester) async {
    final (recorder, s) = await pump(tester, bpOnly);
    final c = s.strings.checkin;
    await tester.tap(find.text(c.rec_select));
    await tester.pumpAndSettle();
    await tester.tap(find.text(c.rec_select_all));
    await tester.pumpAndSettle();
    expect(find.text(c.rec_selected(2)), findsOne);

    await tester.tap(find.text(c.rec_delete_n(c.rec_count(2))));
    await tester.pumpAndSettle();
    expect(find.text(c.rec_del_title(c.rec_count(2))), findsOne);
    await confirm(tester, s);

    expect(find.text(c.day_empty), findsOne);
    expect(recorder.stored.single.isEmpty, isTrue);
  });

  testWidgets('in Arabic the row swipes the other way', (tester) async {
    final (recorder, s) = await pump(tester, bpOnly, ar: true);
    await tester.drag(find.text(s.strings.profile.m_bp), const Offset(300, 0));
    await tester.pumpAndSettle();
    await confirm(tester, s);
    expect(find.text(s.strings.checkin.rec_deleted(s.strings.profile.m_bp)), findsOne);
    expect(recorder.stored.single.vitals.systolic, isNull);
  });
}
