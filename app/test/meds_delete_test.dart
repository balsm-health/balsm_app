import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/screens/meds_screen.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:medications/medications.dart';
import 'package:prescriptions/prescriptions.dart';

/// `home.jsx` MedsScreen — a medication is deleted from its dose row's ⋮
/// menu, by swiping the row, or with Select; each asks first.
///
/// The medications are invented by the test; nothing here is real patient data.
class _Recorder implements DeleteMedicationUseCase {
  final deleted = <MedicationId>[];

  @override
  MedicationsDataSource get dao => throw UnimplementedError();

  @override
  Future<void> call(MedicationId id) async => deleted.add(id);
}

void main() {
  const user = UserId.value('usr-1');
  Medication med(String id, String name) => Medication(
        id: MedicationId.value(id),
        userId: user,
        name: name,
        scheduleType: ScheduleType.daily,
        scheduleConfig: const ScheduleConfig(times: ['08:00', '20:00']),
        startDate: DateTime(2026, 1, 1),
      );
  final alpha = med('med-a', 'Testamol');
  final beta = med('med-b', 'Placebex');
  final today = DateTime.now();
  final doses = [
    TodayDose(medication: alpha, scheduledAt: DateTime(today.year, today.month, today.day, 8)),
    TodayDose(medication: beta, scheduledAt: DateTime(today.year, today.month, today.day, 9)),
    TodayDose(medication: alpha, scheduledAt: DateTime(today.year, today.month, today.day, 20)),
  ];

  Future<(_Recorder, PatientAppState)> pump(WidgetTester tester, {bool ar = false}) async {
    final recorder = _Recorder();
    final state = PatientAppState();
    if (ar) state.setLang(LanguageCode.ar);
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(user),
        todayDosesProvider.overrideWith((ref) async => doses),
        medicationListProvider.overrideWith((ref) => Stream.value([alpha, beta])),
        prescriptionListProvider.overrideWith((ref) => Stream.value(const <Prescription>[])),
        weekAdherenceProvider.overrideWith((ref) async => const WeekAdherence(scheduled: 0, taken: 0)),
        deleteMedicationUseCaseProvider(user).overrideWithValue(recorder),
      ],
      child: AppScope(
        state: state,
        child: MaterialApp(
          builder: (_, child) => Directionality(textDirection: state.dir, child: child!),
          home: const Scaffold(body: MedsScreen()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (recorder, state);
  }

  Future<void> confirm(WidgetTester tester, PatientAppState s) async {
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text(s.strings.common.del)));
    await tester.pumpAndSettle();
  }

  testWidgets('the ⋮ menu asks, then ends the medication', (tester) async {
    final (recorder, s) = await pump(tester);
    await tester.tap(
        find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == s.strings.common.del_options('Placebex')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.strings.common.del));
    await tester.pumpAndSettle();

    expect(find.text(s.strings.common.del_title('Placebex')), findsOne);
    expect(find.text(s.strings.meds.med_del_body_one), findsOne);
    await confirm(tester, s);

    expect(recorder.deleted, [beta.id]);
    expect(find.text(s.strings.common.del_done('Placebex')), findsOne);
  });

  testWidgets('Cancel ends nothing', (tester) async {
    final (recorder, s) = await pump(tester);
    await tester.drag(find.text('Placebex'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.strings.common.cancel));
    await tester.pumpAndSettle();
    expect(recorder.deleted, isEmpty);
  });

  testWidgets('Select all ends each medication once, though Testamol has two doses', (tester) async {
    final (recorder, s) = await pump(tester);
    final c = s.strings.common;
    await tester.tap(find.byWidgetPredicate((w) => w is RoundBtn && w.semanticLabel == c.del_select));
    await tester.pumpAndSettle();
    await tester.tap(find.text(c.del_select_all));
    await tester.pumpAndSettle();
    expect(find.text(c.del_selected(2)), findsOne);

    await tester.tap(find.text(c.del_n(s.strings.meds.med_count(2))));
    await tester.pumpAndSettle();
    expect(find.text(s.strings.meds.med_del_body_n), findsOne);
    await confirm(tester, s);

    expect(recorder.deleted, [alpha.id, beta.id]);
  });

  testWidgets('in Arabic the row swipes the other way and counts in Arabic', (tester) async {
    final (recorder, s) = await pump(tester, ar: true);
    expect(s.strings.meds.med_count(5), '5 أدوية');
    expect(s.strings.meds.med_count(11), '11 دواءً');
    await tester.drag(find.text('Testamol').first, const Offset(300, 0));
    await tester.pumpAndSettle();
    await confirm(tester, s);
    expect(recorder.deleted, [alpha.id]);
  });
}
