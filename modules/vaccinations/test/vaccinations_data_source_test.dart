import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vaccinations/vaccinations.dart';

/// `vaccination_record` persistence, partitioned by health profile.
/// Synthetic ids and vaccine names only.
void main() {
  const alice = UserId.value('u-alice');
  const bob = UserId.value('u-bob');
  const child = HealthProfileId.value('hp-alice-child');
  const closed = HealthProfileId.value('hp-alice-closed');
  final now = DateTime(2026, 11, 3);
  late AppDatabase db;
  late HealthProfileId aliceSelf;
  late HealthProfileId bobSelf;
  HealthProfileId? active;
  UserId? user;
  late DriftVaccinationsDataSource ds;

  VaccinationRecord dose(String id, {String vaccine = 'Test Vaccine', int n = 1, DateTime? on, DateTime? next}) =>
      VaccinationRecord(
        id: VaccinationRecordId.value(id),
        vaccine: vaccine,
        doseNumber: n,
        administeredOn: on ?? DateTime.utc(2026, 10, 1),
        nextDueOn: next,
        clinic: 'Test Clinic',
        createdAt: DateTime.utc(2026, 10, 1, 12),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    aliceSelf = await db.ensureSelfHealthProfile(alice);
    bobSelf = await db.ensureSelfHealthProfile(bob);
    await db.customStatement("INSERT INTO health_profile (id, user_id, is_self, kind, updated_at) "
        "VALUES ('${child.value}', '${alice.value}', 0, 'dependent', 0)");
    await db.customStatement("INSERT INTO health_profile (id, user_id, is_self, kind, status, updated_at) "
        "VALUES ('${closed.value}', '${alice.value}', 0, 'dependent', 'closed', 0)");
    active = aliceSelf;
    user = alice;
    ds = DriftVaccinationsDataSource(
      db: db,
      activeProfile: () => active,
      activeUser: () => user,
      clock: () => DateTime.utc(2026, 11, 3),
    );
  });

  tearDown(() => db.close());

  test('round-trips a dose through the active profile, dates as calendar days', () async {
    final d = dose('v1', next: DateTime.utc(2026, 12, 1));
    await ds.put(d.id, d);
    final back = (await ds.find(d.id))!;
    expect(back.vaccine, 'Test Vaccine');
    expect(back.doseNumber, 1);
    expect(back.administeredOn, DateTime.utc(2026, 10, 1));
    expect(back.nextDueOn, DateTime.utc(2026, 12, 1));
    expect(back.clinic, 'Test Clinic');
    final stored = await db.customSelect('SELECT administered_on, next_due_on FROM vaccination_record').getSingle();
    expect(stored.data, {'administered_on': '2026-10-01', 'next_due_on': '2026-12-01'});
  });

  test('each person has their own log, newest dose first', () async {
    await ds.put(const VaccinationRecordId.value('a1'), dose('a1', on: DateTime.utc(2026, 1, 1)));
    await ds.put(const VaccinationRecordId.value('c1'), dose('c1', on: DateTime.utc(2026, 2, 1)), scope: child);
    await ds.put(const VaccinationRecordId.value('c2'), dose('c2', n: 2, on: DateTime.utc(2026, 6, 1)), scope: child);

    expect([for (final r in await ds.findAll()) r.id.value], ['a1']);
    expect([for (final r in await ds.findAll(scope: child)) r.id.value], ['c2', 'c1']);
    active = child;
    expect([for (final r in await ds.findAll()) r.id.value], ['c2', 'c1'], reason: 'null scope follows the active');
    expect(await ds.find(const VaccinationRecordId.value('a1')), isNull);
  });

  test('refuses another account\'s person and a closed profile', () async {
    await expectLater(
        ds.put(const VaccinationRecordId.value('x'), dose('x'), scope: bobSelf), throwsA(isA<StorageWriteException>()));
    await expectLater(
        ds.put(const VaccinationRecordId.value('y'), dose('y'), scope: closed), throwsA(isA<StorageWriteException>()));
    user = null;
    await expectLater(ds.put(const VaccinationRecordId.value('z'), dose('z')), throwsA(isA<NoActiveUserException>()));
    active = null;
    await expectLater(
        ds.put(const VaccinationRecordId.value('z'), dose('z')), throwsA(isA<NoActiveProfileException>()));
    expect(await ds.findAll(), isEmpty);
  });

  test('delete is soft: the row stays, stamped, and reads leave it out', () async {
    await ds.put(const VaccinationRecordId.value('d1'), dose('d1'));
    await ds.delete(const VaccinationRecordId.value('d1'));
    expect(await ds.exists(const VaccinationRecordId.value('d1')), isFalse);
    final raw = await db.customSelect("SELECT deleted_at FROM vaccination_record WHERE id = 'd1'").getSingle();
    expect(raw.read<int>('deleted_at'), DateTime.utc(2026, 11, 3).millisecondsSinceEpoch);
    // A put with the same id cannot revive a deleted row.
    await ds.put(const VaccinationRecordId.value('d1'), dose('d1', vaccine: 'Changed'));
    expect(await ds.findAll(), isEmpty);
  });

  test('watchAll re-emits after each write and delete', () async {
    final seen = <List<String>>[];
    final sub = ds.watchAll(scope: child).listen((l) => seen.add([for (final r in l) r.id.value]));
    await pumpEventQueue();
    await ds.put(const VaccinationRecordId.value('w1'), dose('w1'), scope: child);
    await pumpEventQueue();
    await ds.delete(const VaccinationRecordId.value('w1'), scope: child);
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, [
      <String>[],
      ['w1'],
      <String>[],
    ]);
  });

  test('RecordVaccinationUseCase validates, then files the dose under the person', () async {
    final use = RecordVaccinationUseCase(ds);
    final bad = await use(vaccine: '', doseNumber: 1, administeredOn: now, now: now, profileId: child);
    expect(bad.error, isA<ValidationFailure>());

    final ok = await use(
      vaccine: 'Test Vaccine',
      doseNumber: 2,
      administeredOn: DateTime(2026, 11, 1),
      nextDueOn: DateTime(2027, 1, 1),
      now: now,
      profileId: child,
    );
    expect(ok.isSuccess, isTrue);
    expect((await ds.findAll(scope: child)).single.doseNumber, 2);

    final refused = await use(vaccine: 'Test', doseNumber: 1, administeredOn: now, now: now, profileId: closed);
    expect(refused.error, isA<StorageFailure>());
  });

  test('clear wipes one profile; clearAll wipes every row', () async {
    await ds.put(const VaccinationRecordId.value('k1'), dose('k1'));
    await ds.put(const VaccinationRecordId.value('k2'), dose('k2'), scope: child);
    await ds.clear(scope: child);
    expect(await ds.findAll(scope: child), isEmpty);
    expect(await ds.findAll(), hasLength(1));
    await ds.clearAll();
    expect(await db.customSelect('SELECT * FROM vaccination_record').get(), isEmpty);
  });
}
