import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/day_records_screen.dart';
import 'package:app/balsm_app/screens/metric_log.dart';
import 'package:app/balsm_app/vault/memory_file_store.dart';
import 'package:app/balsm_app/widgets/num_pad.dart';
import 'package:app/balsm_app/screens/checkin_shared.dart';
import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:self_report/self_report.dart';

/// home-base-mc.jsx `DayRecordsScreen` + quicklog.jsx `QuickLogSheet` `edit`:
/// a logged reading opens in its quick-log form, prefilled, and saving stores
/// the edit over it.
///
/// The readings are invented by the test; nothing here is real patient data.
void main() {
  const profile = HealthProfileId.value('hp-1');
  final at = DateTime(2026, 7, 24, 9);

  CheckIn checkIn({Vitals vitals = Vitals.empty, Mood? mood, Set<SymptomId> symptoms = const {}, String? note}) =>
      CheckIn(
        id: const CheckInId.value('chk-1'),
        healthProfileId: profile,
        recordedAt: at,
        mood: mood,
        painLevel: PainLevel.none,
        painSites: const {},
        symptoms: symptoms,
        vitals: vitals,
        note: note,
      );

  Future<(PatientAppState, DriftCheckInsDataSource)> pump(WidgetTester tester, CheckIn entry, {bool ar = false}) async {
    final state = PatientAppState();
    if (ar) state.setLang(LanguageCode.ar);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final ds = DriftCheckInsDataSource(db, () => profile);
    await ds.put(entry.id, entry);
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        userFileStoreProvider.overrideWithValue(MemoryUserFileStore()),
        checkInsDataSourceProvider.overrideWithValue(ds),
      ],
      child: AppScope(
        state: state,
        child: MaterialApp(
          builder: (_, child) => Directionality(textDirection: state.dir, child: child!),
          home: DayRecordsScreen(checkIns: [entry]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (state, ds);
  }

  Finder value(String text) => find.textContaining(text, findRichText: true);

  Future<void> key(WidgetTester tester, String label) async {
    final k = find.descendant(of: find.byType(NumPad), matching: find.text(label));
    await tester.ensureVisible(k);
    await tester.tap(k);
    await tester.pump();
  }

  testWidgets('tapping a reading opens its form prefilled, and Save stores the edit', (tester) async {
    final (s, ds) = await pump(tester, checkIn(vitals: const Vitals(systolic: 118, diastolic: 76), note: 'Kept note'));
    await tester.tap(find.text(s.strings.profile.m_bp));
    await tester.pumpAndSettle();

    expect(find.text(s.strings.checkin.ql_edit_title(s.strings.profile.m_bp)), findsOne);
    expect(find.text('118'), findsOne);
    expect(find.text('76'), findsOne);
    expect(find.text('Kept note'), findsOne);
    // Opened on an edit, there is no list to step back to: the only Back is
    // the day screen's own, under the sheet.
    expect(find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == s.strings.common.a11y_back), findsOne);

    // The diastolic box is active: clear it and type a new value.
    final del = find.byIcon(LucideIcons.delete);
    await tester.ensureVisible(del);
    await tester.tap(del);
    await tester.tap(del);
    await tester.pump();
    await key(tester, '8');
    await key(tester, '4');
    await tester.tap(find.widgetWithIcon(RoundBtn, LucideIcons.check));
    await tester.pumpAndSettle();

    expect(find.text(s.strings.checkin.ql_edit_title(s.strings.profile.m_bp)), findsNothing);
    expect(value('118/84'), findsOne);
    final stored = (await ds.findAll()).single;
    expect(stored.id, const CheckInId.value('chk-1'), reason: 'the edit replaces the reading');
    expect(stored.vitals.diastolic, 84);
    expect(stored.note, 'Kept note');
  });

  testWidgets('the ⋮ menu offers Edit above Delete', (tester) async {
    final (s, _) = await pump(tester, checkIn(mood: Mood.low));
    await tester.tap(find.byWidgetPredicate(
        (w) => w is RoundBtn && w.semanticLabel == s.strings.common.del_options(s.strings.profile.m_mood)));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.rec_delete), findsOne);
    await tester.tap(find.text(s.strings.common.a11y_edit));
    await tester.pumpAndSettle();

    expect(find.text(s.strings.checkin.ql_edit_title(s.strings.profile.m_mood)), findsOne);
    final cells = tester.widgetList<MoodCell>(find.byType(MoodCell)).toList();
    expect(cells[Mood.low.score - 1].selected, isTrue, reason: 'the stored mood is selected');
  });

  testWidgets('closing without a change stores nothing', (tester) async {
    final (s, ds) = await pump(tester, checkIn(vitals: const Vitals(spo2: 97)));
    await tester.tap(find.text(s.strings.profile.m_o2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(s.strings.common.cancel));
    await tester.tap(find.text(s.strings.common.cancel));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.ql_edit_title(s.strings.profile.m_o2)), findsNothing);
    expect((await ds.findAll()).single.vitals.spo2, 97);
  });

  testWidgets('each symptom has its own row that opens its form', (tester) async {
    final (s, _) = await pump(tester, checkIn(symptoms: {SymptomId.headache}));
    final label = symptomLabel(s, SymptomId.headache);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.ql_edit_title(label)), findsOne);
  });

  testWidgets('the edit form lays out in Arabic', (tester) async {
    final (s, _) = await pump(tester, checkIn(vitals: const Vitals(glucoseRandom: 140)), ar: true);
    await tester.tap(find.text(s.strings.profile.m_glucose));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.checkin.ql_edit_title(s.strings.profile.m_glucose)), findsOne);
    expect(find.text('140'), findsOne);
    expect(find.byType(MetricLog), findsOne);
    expect(tester.takeException(), isNull);
  });
}
