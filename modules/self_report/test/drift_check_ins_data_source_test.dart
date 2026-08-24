import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

void main() {
  late AppDatabase db;
  late DriftCheckInsDataSource ds;
  const profile = HealthProfileId.value('hp-1');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    ds = DriftCheckInsDataSource(db, () => profile);
  });
  tearDown(() => db.close());

  CheckIn sample(String id) => CheckIn(
        id: CheckInId.value(id),
        healthProfileId: profile,
        recordedAt: DateTime.utc(2026, 7, 24, 9),
        mood: Mood.good,
        painLevel: const PainLevel(6),
        painRegions: {BodyRegion.chest, BodyRegion.bkLower},
        symptoms: {SymptomId.headache, SymptomId.nausea},
        vitals: const Vitals(systolic: 120, diastolic: 80, glucoseFasting: 95),
        note: 'felt tired',
      );

  test('write → read round-trips mood, pain, regions, symptoms, vitals, note', () async {
    final c = sample('chk-1');
    await ds.put(c.id, c);

    final got = await ds.find(c.id);
    expect(got, isNotNull);
    expect(got!.mood, Mood.good);
    expect(got.painLevel.value, 6);
    expect(got.painRegions, {BodyRegion.chest, BodyRegion.bkLower});
    expect(got.symptoms.map((s) => s.id).toSet(), {'headache', 'nausea'});
    expect(got.vitals.systolic, 120);
    expect(got.vitals.diastolic, 80);
    expect(got.vitals.glucoseFasting, 95);
    expect(got.vitals.heartRate, isNull);
    expect(got.note, 'felt tired');
  });

  test('a quick-log entry with no mood round-trips as null, not a fabricated score', () async {
    final bpOnly = CheckIn(
      id: CheckInId.value('chk-bp'),
      healthProfileId: profile,
      recordedAt: DateTime.utc(2026, 7, 24, 18),
      painLevel: PainLevel.none,
      painRegions: const {},
      symptoms: const {},
      vitals: const Vitals(systolic: 118, diastolic: 76),
    );
    await ds.put(bpOnly.id, bpOnly);

    final got = await ds.find(bpOnly.id);
    expect(got!.mood, isNull);
    expect(got.vitals.systolic, 118);
    expect(got.vitals.diastolic, 76);
  });

  test('findAll returns newest-first and is profile-scoped', () async {
    final older = CheckIn(
      id: CheckInId.value('chk-old'),
      healthProfileId: profile,
      recordedAt: DateTime.utc(2026, 7, 20),
      mood: Mood.ok,
      painLevel: PainLevel.none,
      painRegions: const {},
      symptoms: const {},
      vitals: Vitals.empty,
    );
    await ds.put(older.id, older);
    await ds.put(CheckInId.value('chk-new'), sample('chk-new')); // 2026-07-24

    final all = await ds.findAll();
    expect(all.map((c) => c.id.value), ['chk-new', 'chk-old']); // newest first
    expect(all.length, 2);

    // Other profile sees nothing.
    final other = await ds.findAll(scope: const HealthProfileId.value('hp-2'));
    expect(other, isEmpty);
  });

  test('delete removes the entry and cascades child rows', () async {
    final c = sample('chk-del');
    await ds.put(c.id, c);
    await ds.delete(c.id);
    expect(await ds.find(c.id), isNull);
    final syms = await db.customSelect('SELECT COUNT(*) c FROM check_in_symptom').getSingle();
    expect(syms.read<int>('c'), 0);
  });

  test('mutations with no active profile throw NoActiveProfileException', () async {
    final signedOut = DriftCheckInsDataSource(db, () => null);
    expect(
      () => signedOut.put(CheckInId.value('x'), sample('x')),
      throwsA(isA<NoActiveProfileException>()),
    );
    expect(await signedOut.findAll(), isEmpty);
  });
}
