import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

void main() {
  late AppDatabase db;
  late DriftCheckInsDataSource ds;
  late UpdateCheckInUseCase update;
  const profile = HealthProfileId.value('hp-1');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    ds = DriftCheckInsDataSource(db, () => profile);
    update = UpdateCheckInUseCase(dao: ds);
  });
  tearDown(() => db.close());

  CheckIn entry(String id) => CheckIn(
        id: CheckInId.value(id),
        healthProfileId: profile,
        recordedAt: DateTime.utc(2026, 7, 24, 9),
        mood: Mood.good,
        painLevel: const PainLevel(5),
        painSites: {PainSite(Muscle.chest)},
        symptoms: {SymptomId.headache},
        vitals: const Vitals(systolic: 118, diastolic: 76, glucoseFasting: 95),
      );

  test('removing one reading keeps the rest of the check-in', () async {
    final c = entry('chk-1');
    await ds.put(c.id, c);

    expect(await update(c.without(CheckInMetric.bloodPressure)), isTrue);

    final got = (await ds.find(c.id))!;
    expect(got.vitals.systolic, isNull);
    expect(got.vitals.diastolic, isNull);
    expect(got.vitals.glucoseFasting, 95);
    expect(got.mood, Mood.good);
  });

  test('removing pain clears the marked sites too', () async {
    final c = entry('chk-1').without(CheckInMetric.pain);
    expect(c.reportsPain, isFalse);
    expect(c.painSites, isEmpty);
  });

  test('a check-in emptied reading by reading is deleted', () async {
    final keep = entry('chk-keep');
    var c = entry('chk-drop');
    await ds.put(keep.id, keep);
    await ds.put(c.id, c);
    for (final m in [
      CheckInMetric.mood,
      CheckInMetric.bloodPressure,
      CheckInMetric.glucose,
      CheckInMetric.pain,
      CheckInMetric.symptoms,
    ]) {
      c = c.without(m);
    }

    expect(c.isEmpty, isTrue);
    expect(await update(c), isFalse);
    expect(await ds.find(c.id), isNull);
    expect((await ds.findAll()).map((x) => x.id), [keep.id]);
  });
}
