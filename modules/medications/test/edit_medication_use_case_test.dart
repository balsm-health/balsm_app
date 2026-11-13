import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medications/medications.dart';

/// Editing a medication (prescriptions.jsx AddMedSheet `initial`, "Edit
/// medication") replaces the row in place: same id, new fields, and the
/// append-only dose history stays attached. Invented names only.
void main() {
  const user = UserId.value('u-edit-test');
  late AppDatabase db;
  late DriftMedicationsDataSource dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final profile = await db.ensureSelfHealthProfile(user);
    dao = DriftMedicationsDataSource(db, () => profile);
  });
  tearDown(() => db.close());

  final original = Medication(
    id: MedicationId.value('med-edit'),
    userId: user,
    name: 'Testamol',
    doseAmount: '500 mg',
    scheduleType: ScheduleType.daily,
    scheduleConfig: const ScheduleConfig(times: ['08:00']),
    startDate: DateTime(2026, 11, 1),
  );

  test('replaces the medication under the same id', () async {
    await dao.put(original.id, original);
    final edited = original.copyWith(
      name: 'Placebex',
      doseAmount: '250 mg',
      scheduleConfig: const ScheduleConfig(times: ['08:00', '20:00']),
    );

    await EditMedicationUseCase(dao: dao)(edited);

    final all = await dao.findAll();
    expect(all, hasLength(1));
    final stored = all.single;
    expect(stored.id, original.id);
    expect(stored.name, 'Placebex');
    expect(stored.doseAmount, '250 mg');
    expect(stored.scheduleConfig.times, ['08:00', '20:00']);
    expect(stored.startDate, original.startDate);
  });

  test('keeps the dose history recorded before the edit', () async {
    await dao.put(original.id, original);
    final at = DateTime(2026, 11, 2, 8);
    await dao.insertDoseEvent(DoseEvent(
      id: DoseEventId.uuid(),
      medicationId: original.id,
      scheduledAt: at,
      recordedAt: at,
      outcome: DoseOutcome.taken,
    ));

    await EditMedicationUseCase(dao: dao)(original.copyWith(name: 'Placebex'));

    final events = await dao.getDoseEvents(original.id);
    expect(events, hasLength(1));
    expect(events.single.outcome, DoseOutcome.taken);
  });
}
