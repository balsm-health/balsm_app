import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_report/self_report.dart';

/// Synthetic values only — nothing here is real patient data.
void main() {
  late AppDatabase db;
  late DriftCheckInsDataSource ds;
  late EditCheckInReadingUseCase edit;
  const profile = HealthProfileId.value('hp-1');
  final at = DateTime.utc(2026, 7, 24, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    ds = DriftCheckInsDataSource(db, () => profile);
    edit = EditCheckInReadingUseCase(dao: ds);
  });
  tearDown(() => db.close());

  CheckIn entry(
    String id, {
    Mood? mood,
    PainLevel painLevel = PainLevel.none,
    Set<PainSite> painSites = const {},
    Set<SymptomId> symptoms = const {},
    Map<SymptomId, SymptomDetail> details = const {},
    Vitals vitals = Vitals.empty,
    DateTime? recordedAt,
    String? note,
    String? photo,
  }) =>
      CheckIn(
        id: CheckInId.value(id),
        healthProfileId: profile,
        recordedAt: recordedAt ?? at,
        mood: mood,
        painLevel: painLevel,
        painSites: painSites,
        symptoms: symptoms,
        symptomDetails: details,
        vitals: vitals,
        note: note,
        photoRecordId: photo,
      );

  test('a quick-logged reading is replaced in place with its time and note', () async {
    final original = entry('chk-1', vitals: const Vitals(systolic: 120, diastolic: 80), note: 'Old note');
    await ds.put(original.id, original);
    final later = at.add(const Duration(hours: 2));

    final stored = await edit(
      original,
      CheckInMetric.bloodPressure,
      entry('draft', vitals: const Vitals(systolic: 131, diastolic: 84), recordedAt: later, note: 'New note'),
    );

    expect(stored.id, original.id);
    final back = (await ds.findAll()).single;
    expect(back.id, original.id, reason: 'an edit never adds a second entry');
    expect(back.vitals.systolic, 131);
    expect(back.vitals.diastolic, 84);
    expect(back.recordedAt, later);
    expect(back.note, 'New note');
  });

  test("editing one reading leaves the check-in's other readings alone", () async {
    final original = entry(
      'chk-1',
      mood: Mood.good,
      vitals: const Vitals(systolic: 118, diastolic: 76, glucoseFasting: 95),
      symptoms: {SymptomId.headache},
    );
    await ds.put(original.id, original);

    await edit(original, CheckInMetric.glucose, entry('draft', vitals: const Vitals(glucoseRandom: 140)));

    final back = (await ds.find(original.id))!;
    expect(back.vitals.glucoseFasting, isNull, reason: 'the glucose context moved with the edit');
    expect(back.vitals.glucoseRandom, 140);
    expect(back.vitals.systolic, 118);
    expect(back.vitals.diastolic, 76);
    expect(back.mood, Mood.good);
    expect(back.symptoms, {SymptomId.headache});
  });

  test('mood, pulse, SpO2 and weight take the edited value', () async {
    var c = entry('chk-1', mood: Mood.low, vitals: const Vitals(heartRate: 70, spo2: 97, weightKg: 70));
    c = c.withReading(CheckInMetric.mood, entry('d', mood: Mood.great));
    c = c.withReading(CheckInMetric.heartRate, entry('d', vitals: const Vitals(heartRate: 88)));
    c = c.withReading(CheckInMetric.spo2, entry('d', vitals: const Vitals(spo2: 95)));
    c = c.withReading(CheckInMetric.weight, entry('d', vitals: const Vitals(weightKg: 71.5)));
    expect(c.mood, Mood.great);
    expect(c.vitals.heartRate, 88);
    expect(c.vitals.spo2, 95);
    expect(c.vitals.weightKg, 71.5);
  });

  test('pain takes its score and marked sites from the edit', () async {
    final original = entry('chk-1', painLevel: const PainLevel(6), painSites: {const PainSite(Muscle.chest)});
    final edited = original.withReading(CheckInMetric.pain, entry('d', painLevel: const PainLevel(3)));
    expect(edited.painLevel, const PainLevel(3));
    expect(edited.painSites, isEmpty);
  });

  test('editing one symptom keeps the others and their details', () async {
    const urine = SymptomDetail(blood: true);
    final original = entry(
      'chk-1',
      symptoms: {SymptomId.headache, SymptomId.urine},
      details: {SymptomId.urine: urine},
      note: 'Kept note',
    );

    final edited = original.withReading(
      CheckInMetric.symptoms,
      entry('d', symptoms: {SymptomId.headache}, note: 'Kept note'),
      symptom: SymptomId.headache,
    );
    expect(edited.symptoms, {SymptomId.headache, SymptomId.urine});
    expect(edited.symptomDetails, {SymptomId.urine: urine});

    final detailEdited = original.withReading(
      CheckInMetric.symptoms,
      entry('d', symptoms: {SymptomId.urine}, details: {SymptomId.urine: const SymptomDetail(urineMl: 200)}),
      symptom: SymptomId.urine,
    );
    expect(detailEdited.symptomDetails[SymptomId.urine]!.urineMl, 200);
    expect(detailEdited.symptomDetails[SymptomId.urine]!.blood, isFalse);
  });

  test('the photo follows the edit, so a removed photo is unlinked', () async {
    final original = entry('chk-1', vitals: const Vitals(spo2: 97), photo: 'rec-photo');
    final kept = original.withReading(
      CheckInMetric.spo2,
      entry('d', vitals: const Vitals(spo2: 98), photo: original.photoRecordId),
    );
    expect(kept.photoRecordId, 'rec-photo');
    final removed = original.withReading(CheckInMetric.spo2, entry('d', vitals: const Vitals(spo2: 98)));
    expect(removed.photoRecordId, isNull);
  });
}
