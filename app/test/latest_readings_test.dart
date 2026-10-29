import 'package:app/balsm_app/screens/home_widgets.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

/// Home "latest readings": each reading comes from the newest check-in that
/// logged it, so a later mood- or pain-only check-in keeps the vitals.
void main() {
  const profile = HealthProfileId.value('hp-1');

  CheckIn checkIn(int hour, {Vitals vitals = Vitals.empty, Mood? mood, PainLevel pain = PainLevel.none}) => CheckIn(
        id: CheckInId.value('chk-$hour'),
        healthProfileId: profile,
        recordedAt: DateTime.utc(2026, 7, 24, hour),
        mood: mood,
        painLevel: pain,
        painSites: const {},
        symptoms: const {},
        vitals: vitals,
      );

  test('a mood-only check-in keeps the vitals logged before it', () {
    final r = LatestReadings.from([
      checkIn(11, mood: Mood.good),
      checkIn(10, vitals: const Vitals(systolic: 120, diastolic: 80, glucoseFasting: 95, spo2: 98)),
    ]);
    expect((r.systolic, r.diastolic, r.glucose, r.spo2), (120, 80, 95, 98));
    expect(r.mood, Mood.good);
    expect(r.pain, isNull);
  });

  test('a pain-only check-in keeps the vitals and the earlier mood', () {
    final r = LatestReadings.from([
      checkIn(12, pain: const PainLevel(4)),
      checkIn(11, mood: Mood.low),
      checkIn(10, vitals: const Vitals(systolic: 135, diastolic: 88, spo2: 96)),
    ]);
    expect((r.systolic, r.diastolic, r.spo2), (135, 88, 96));
    expect(r.mood, Mood.low);
    expect(r.pain?.value, 4);
  });

  test('each reading is the newest one logged', () {
    final r = LatestReadings.from([
      checkIn(12, vitals: const Vitals(glucoseRandom: 150)),
      checkIn(11, vitals: const Vitals(systolic: 118, diastolic: 76)),
      checkIn(10, vitals: const Vitals(systolic: 140, diastolic: 90, glucoseFasting: 99, spo2: 97)),
    ]);
    expect((r.systolic, r.diastolic, r.glucose, r.spo2), (118, 76, 150, 97));
  });

  test('a half-entered blood pressure is skipped for the last full one', () {
    final r = LatestReadings.from([
      checkIn(11, vitals: const Vitals(systolic: 125)),
      checkIn(10, vitals: const Vitals(systolic: 120, diastolic: 80)),
    ]);
    expect((r.systolic, r.diastolic), (120, 80));
  });

  test('nothing logged leaves every reading empty', () {
    final r = LatestReadings.from([checkIn(10)]);
    expect([r.systolic, r.diastolic, r.glucose, r.spo2, r.mood, r.pain], everyElement(isNull));
  });
}
