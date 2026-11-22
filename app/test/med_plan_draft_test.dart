import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/widgets/med_plan_form.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:medications/medications.dart';

/// What the Add medication / Add prescription form turns into. The Meds tab's
/// "to take" list is computed from this, so each frequency option must map to
/// the schedule agreed for it.
void main() {
  const user = UserId.value('u');
  final now = DateTime(2026, 10, 5, 10, 30); // added mid-morning

  MedPlanDraft draft(String freq, {String n = '2', String unit = 'hours'}) => MedPlanDraft()
    ..name.text = 'Med'
    ..freqType = freq
    ..freqN.text = n
    ..freqUnit = unit
    ..syncTimes();

  List<String> today(Medication m) => [for (final at in dosesOn(m, now)) '${at.hour}:${at.minute}'];

  test("starts at midnight, so this morning's dose is still listed", () {
    final m = draft('once').toMedication(user, now: now);
    expect(m.startDate, DateTime(2026, 10, 5));
    expect(today(m), ['8:0']);
  });

  test('one time → a single dose today, at the chosen half of the day', () {
    final m = (draft('once')..evening = true).toMedication(user, now: now);
    expect(m.scheduleType, ScheduleType.once);
    expect(today(m), ['20:0']);
    expect(dosesOn(m, DateTime(2026, 10, 6)), isEmpty);
  });

  test('3 times a day → auto-spread times, and an edited time is kept', () {
    final d = draft('per_day', n: '3');
    expect(d.timing, MedTiming.times);
    expect(d.times, ['08:00', '14:00', '20:00']);
    d
      ..times = ['07:00', '14:00', '21:00']
      ..syncTimes(); // same count — the patient's edit survives
    final m = d.toMedication(user, now: now);
    expect(m.scheduleType, ScheduleType.daily);
    expect(today(m), ['7:0', '14:0', '21:0']);
  });

  test('changing the count re-suggests the times', () {
    final d = draft('per_day', n: '3');
    d.freqN.text = '2';
    d.syncTimes();
    expect(d.times, ['08:00', '20:00']);
  });

  test('once a day uses Morning / Evening, not time chips', () {
    final d = draft('per_day', n: '1')..evening = true;
    expect(d.timing, MedTiming.halfOfDay);
    expect(today(d.toMedication(user, now: now)), ['20:0']);
  });

  test('every 8 hours → counted from the first dose', () {
    final d = draft('every_x', n: '8');
    expect(d.timing, MedTiming.firstDose);
    d.times = ['06:00'];
    final m = d.toMedication(user, now: now);
    expect(m.scheduleType, ScheduleType.everyHours);
    expect(m.scheduleConfig.interval, 8);
    expect(today(m), ['6:0', '14:0', '22:0']);
  });

  test('every 2 days → today, then every other day', () {
    final m = draft('every_x', unit: 'days').toMedication(user, now: now);
    expect(m.scheduleType, ScheduleType.everyDays);
    expect(today(m), ['8:0']);
    expect(dosesOn(m, DateTime(2026, 10, 6)), isEmpty);
    expect(dosesOn(m, DateTime(2026, 10, 7)), hasLength(1));
  });

  test("other → daily, keeping the patient's words", () {
    final d = draft('other')..freqOther.text = 'when needed';
    final m = d.toMedication(user, now: now);
    expect(m.scheduleType, ScheduleType.daily);
    expect(m.scheduleConfig.frequencyNote, 'when needed');
    expect(today(m), hasLength(1));
  });

  test('for 7 days → stops after the 7th day', () {
    final d = draft('once')
      ..freqType = 'per_day'
      ..freqN.text = '1'
      ..durType = 'period'
      ..durN.text = '7';
    final m = d.toMedication(user, now: now);
    expect(m.scheduleConfig.durationKind, DurationKind.period);
    expect(dosesOn(m, DateTime(2026, 10, 11)), hasLength(1));
    expect(dosesOn(m, DateTime(2026, 10, 12)), isEmpty);
  });

  test('a set period with no count stays ongoing rather than ending today', () {
    final m = (draft('once')..durType = 'period').toMedication(user, now: now);
    expect(m.endDate, isNull);
  });

  test('notes and dose are kept; blanks become null', () {
    final d = draft('once')
      ..dose.text = ' 500 mg '
      ..notes.text = '  ';
    final m = d.toMedication(user, now: now);
    expect(m.doseAmount, '500 mg');
    expect(m.notes, isNull);
  });

  group('Edit medication (fromMedication)', () {
    Medication stored(ScheduleType type, ScheduleConfig cfg, {DateTime? end}) => Medication(
          id: const MedicationId.value('med-stored'),
          userId: user,
          name: 'Testamol',
          doseAmount: '500 mg',
          scheduleType: type,
          scheduleConfig: cfg,
          startDate: DateTime(2026, 9),
          endDate: end,
          isControlled: true,
          notes: 'with food',
        );

    test('fills the form from the medication', () {
      final d =
          MedPlanDraft.fromMedication(stored(ScheduleType.daily, const ScheduleConfig(times: ['07:00', '19:00'])));
      addTearDown(d.dispose);
      expect((d.name.text, d.dose.text, d.notes.text), ('Testamol', '500 mg', 'with food'));
      expect((d.freqType, d.freqN.text, d.timing), ('per_day', '2', MedTiming.times));
      expect(d.times, ['07:00', '19:00']);
      expect(d.durType, 'ongoing');
    });

    test('maps every schedule back to its form option', () {
      MedPlanDraft of(ScheduleType t, ScheduleConfig c, {DateTime? end}) =>
          MedPlanDraft.fromMedication(stored(t, c, end: end));
      final once = of(ScheduleType.once, const ScheduleConfig(times: ['20:00']));
      expect((once.freqType, once.evening), ('once', true));
      final hours = of(ScheduleType.everyHours, const ScheduleConfig(times: ['06:00'], interval: 8));
      expect((hours.freqType, hours.freqUnit, hours.freqN.text), ('every_x', 'hours', '8'));
      expect(hours.times, ['06:00']);
      final days = of(ScheduleType.everyDays, const ScheduleConfig(times: ['08:00'], interval: 2));
      expect((days.freqType, days.freqUnit, days.freqN.text), ('every_x', 'days', '2'));
      final other = of(ScheduleType.daily, const ScheduleConfig(times: ['08:00'], frequencyNote: 'when needed'));
      expect((other.freqType, other.freqOther.text), ('other', 'when needed'));
      final period = of(
        ScheduleType.daily,
        const ScheduleConfig(times: ['08:00'], durationKind: DurationKind.period),
        end: DateTime(2026, 9, 8),
      );
      expect((period.durType, period.durN.text, period.durUnit), ('period', '7', 'days'));
    });

    test('saving keeps the id, start date and controlled flag; changed fields change', () {
      final med = stored(ScheduleType.daily, const ScheduleConfig(times: ['08:00']));
      final d = MedPlanDraft.fromMedication(med)
        ..name.text = 'Placebex'
        ..dose.text = '250 mg';
      final m = d.toMedication(user, now: now);
      expect(m.id, med.id);
      expect(m.startDate, med.startDate);
      expect(m.isControlled, isTrue);
      expect((m.name, m.doseAmount), ('Placebex', '250 mg'));
    });

    test('an untouched schedule is kept as stored, even one the form cannot express', () {
      final med =
          stored(ScheduleType.weekly, const ScheduleConfig(times: ['10:00'], days: [1]), end: DateTime(2026, 12));
      final m = (MedPlanDraft.fromMedication(med)..name.text = 'Placebex').toMedication(user, now: now);
      expect(m.scheduleType, ScheduleType.weekly);
      expect(m.scheduleConfig.days, [1]);
      expect(m.endDate, DateTime(2026, 12));
    });

    test('a changed schedule is rebuilt from the form', () {
      final med = stored(ScheduleType.daily, const ScheduleConfig(times: ['08:00']));
      final d = MedPlanDraft.fromMedication(med)
        ..freqType = 'every_x'
        ..freqN.text = '8'
        ..freqUnit = 'hours'
        ..syncTimes();
      final m = d.toMedication(user, now: now);
      expect(m.scheduleType, ScheduleType.everyHours);
      expect(m.scheduleConfig.interval, 8);
      expect(m.startDate, med.startDate);
    });
  });

  testWidgets('in the sheet, picking "Times per day" shows the dose-time chips', (tester) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = PatientAppState();
    final d = MedPlanDraft();
    addTearDown(d.dispose);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showAppSheet<void>(
                    context,
                    builder: (_) => StatefulBuilder(
                      builder: (_, setState) => SingleChildScrollView(
                        child: MedPlanCard(draft: d, onChanged: () => setState(() {})),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final m = state.strings.meds;
    await tester.tap(find.text(m.freq_once));
    await tester.pumpAndSettle();
    await tester.tap(find.text(m.freq_per_day).last);
    await tester.pumpAndSettle();
    expect(find.text(m.med_dose_times), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
  });
}
