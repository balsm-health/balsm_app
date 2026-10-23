import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/kit.dart';
import 'package:app/balsm_app/widgets/med_plan_form.dart';
import 'package:material_ui/material_ui.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medications/medications.dart';

/// What the Add medication / Add prescription form turns into. The Meds tab's
/// "to take" list is computed from this, so each frequency option must map to
/// the schedule agreed for it.
void main() {
  final user = UserId.value('u');
  final now = DateTime(2026, 10, 5, 10, 30); // added mid-morning

  MedPlanDraft draft(String freq, {String n = '2', String unit = 'hours'}) => MedPlanDraft()
    ..name.text = 'Med'
    ..freqType = freq
    ..freqN.text = n
    ..freqUnit = unit
    ..syncTimes();

  List<String> today(Medication m) => [for (final at in dosesOn(m, now)) '${at.hour}:${at.minute}'];

  test('starts at midnight, so this morning\'s dose is still listed', () {
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
    d.times = ['07:00', '14:00', '21:00'];
    d.syncTimes(); // same count — the patient's edit survives
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
    final m = draft('every_x', n: '2', unit: 'days').toMedication(user, now: now);
    expect(m.scheduleType, ScheduleType.everyDays);
    expect(today(m), ['8:0']);
    expect(dosesOn(m, DateTime(2026, 10, 6)), isEmpty);
    expect(dosesOn(m, DateTime(2026, 10, 7)), hasLength(1));
  });

  test('other → daily, keeping the patient\'s words', () {
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

  testWidgets('in the sheet, picking "Times per day" shows the dose-time chips', (tester) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = PatientAppState();
    final d = MedPlanDraft();
    addTearDown(d.dispose);
    await tester.pumpWidget(AppScope(
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
    ));
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
