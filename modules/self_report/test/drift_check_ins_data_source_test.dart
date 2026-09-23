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
        painSites: {
          PainSite(Muscle.chest),
          PainSite(Muscle.bk_lower),
        },
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
    expect(got.painSites, {
      PainSite(Muscle.chest),
      PainSite(Muscle.bk_lower),
    });
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
      painSites: const {},
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
      painSites: const {},
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

  test('same region on two tissues round-trips as two sites', () async {
    final c = CheckIn(
      id: CheckInId.value('chk-layers'),
      healthProfileId: profile,
      recordedAt: DateTime.utc(2026, 8, 24, 9),
      painLevel: const PainLevel(4),
      painSites: {
        PainSite(Muscle.l_knee),
        PainSite(Joint.l_knee),
      },
      symptoms: const {},
      vitals: Vitals.empty,
    );
    await ds.put(c.id, c);
    final got = await ds.find(c.id);
    expect(got!.painSites, c.painSites);
  });

  group('symptom detail', () {
    CheckIn withDetail(String id, Map<SymptomId, SymptomDetail> details) => CheckIn(
          id: CheckInId.value(id),
          healthProfileId: profile,
          recordedAt: DateTime.utc(2026, 7, 24, 9),
          painLevel: const PainLevel(0),
          painSites: const {},
          symptoms: details.keys.toSet(),
          symptomDetails: details,
          vitals: Vitals.empty,
        );

    test('urine colour, volume and blood round-trip', () async {
      final c = withDetail('chk-u', {
        SymptomId.urine: const SymptomDetail(urineColor: UrineColor.dark, urineMl: 250, blood: true),
      });
      await ds.put(c.id, c);

      final got = await ds.find(c.id);
      final detail = got!.symptomDetails[SymptomId.urine]!;
      expect(detail.urineColor, UrineColor.dark);
      expect(detail.urineMl, 250);
      expect(detail.blood, isTrue);
    });

    test('stool records blood alone', () async {
      final c = withDetail('chk-s', {SymptomId.stool: const SymptomDetail(blood: true)});
      await ds.put(c.id, c);

      final detail = (await ds.find(c.id))!.symptomDetails[SymptomId.stool]!;
      expect(detail.blood, isTrue);
      expect(detail.urineColor, isNull);
      expect(detail.urineMl, isNull);
    });

    test('a symptom with nothing observed carries no detail', () async {
      final c = withDetail('chk-plain', {SymptomId.urine: const SymptomDetail()});
      await ds.put(c.id, c);

      final got = await ds.find(c.id);
      expect(got!.symptoms, contains(SymptomId.urine));
      // An empty detail is not an observation, so it must not read back as one.
      expect(got.symptomDetails, isEmpty);
    });

    test('details attach to their own symptom only', () async {
      final c = withDetail('chk-mix', {
        SymptomId.urine: const SymptomDetail(urineMl: 100),
        SymptomId.stool: const SymptomDetail(blood: true),
      });
      await ds.put(c.id, c);

      final got = await ds.find(c.id);
      expect(got!.symptomDetails[SymptomId.urine]!.urineMl, 100);
      expect(got.symptomDetails[SymptomId.urine]!.blood, isFalse);
      expect(got.symptomDetails[SymptomId.stool]!.blood, isTrue);
      expect(got.symptomDetails[SymptomId.stool]!.urineMl, isNull);
    });

    test('an unknown stored colour degrades to none rather than throwing', () {
      expect(UrineColor.fromId('chartreuse'), isNull);
      expect(UrineColor.fromId(null), isNull);
    });

    test('only urine and stool ask for detail', () {
      expect(SymptomId.urine.hasDetail, isTrue);
      expect(SymptomId.stool.hasDetail, isTrue);
      expect(SymptomId.headache.hasDetail, isFalse);
      // Colour and volume are urine's alone.
      expect(SymptomId.urine.asksUrineDetail, isTrue);
      expect(SymptomId.stool.asksUrineDetail, isFalse);
    });
  });
}
