import 'dart:io';

import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medications/medications.dart';
import 'package:prescriptions/prescriptions.dart';
import 'package:profile/profile.dart';
import 'package:records/records.dart';
import 'package:self_report/self_report.dart';
import 'package:vaccinations/vaccinations.dart';

/// Upgrading from v0.8.0: opens a database written by the v0.8 app itself
/// (`fixtures/v0_8_database.sql`, dumped from a v0.8 build's data sources)
/// with this build and checks every row is still found by the data sources
/// that now partition by person (`health_profile_id`). All data synthetic.
void main() {
  const userA = UserId.value('user-a');
  const userB = UserId.value('user-b');
  late File file;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('balsm_v0_8_upgrade');
    addTearDown(() => dir.delete(recursive: true));
    file = File('${dir.path}/balsm.db');
  });

  /// Opens [file] with this build. The first open restores the v0.8 dump
  /// into it, as an installed v0.8 app leaves it (drift `user_version` 1).
  Future<AppDatabase> open() async {
    final seed = !file.existsSync();
    final dump = seed ? File('test/migration/fixtures/v0_8_database.sql').readAsStringSync() : '';
    final db = AppDatabase(NativeDatabase(file, setup: (raw) {
      if (!seed) return;
      raw.execute(dump);
      raw.execute('PRAGMA user_version = 1');
    }));
    addTearDown(db.close);
    return db;
  }

  Future<List<String>> rows(AppDatabase db, String sql) async =>
      (await db.customSelect(sql).get()).map((r) => r.data.values.map((v) => '$v').join('|')).toList();

  test('each account keeps one self profile, and it is the active one', () async {
    final db = await open();

    final self = await db.resolveActiveHealthProfile(userA);
    final profiles = DriftProfileDataSource(db: db, activeUser: () => userA);
    final profile = (await profiles.getProfile(userA))!;

    expect(profile.id, self);
    expect(profile.isSelf, isTrue);
    expect((profile.bloodType, profile.weightKg, profile.heightCm), (BloodType.oPositive, 70.0, 170.0));
    expect(await rows(db, 'SELECT user_id, is_self, kind, status FROM health_profile ORDER BY user_id'),
        ['user-a|1|self|active', 'user-b|1|self|active']);
    expect((await profiles.findMembers()).map((m) => m.id), [self], reason: 'no member is invented');
  });

  test('every v0.8 entry is found under the account holder\'s profile', () async {
    final db = await open();
    final self = await db.resolveActiveHealthProfile(userA);
    HealthProfileId? active() => self;

    final records = await DriftRecordsDataSource(db, active).findAll();
    final rx = await DriftPrescriptionsDataSource(db, active).findAll();
    final meds = DriftMedicationsDataSource(db, active);
    final checkIns = await DriftCheckInsDataSource(db, active).findAll();

    expect(records.map((r) => r.id.value), unorderedEquals(['rec-early', 'rec-1']));
    expect(rx.map((p) => (p.id.value, p.items.length)), [('rx-1', 1)]);
    expect((await meds.findAll()).map((m) => m.id.value), unorderedEquals(['med-1', 'med-legacy']),
        reason: 'a medication saved before it carried a profile is anchored to self');
    expect((await meds.getDoseEvents(const MedicationId.value('med-1'))).map((e) => e.outcome), [DoseOutcome.taken]);
    expect(checkIns.single.symptoms, {SymptomId.headache});
    expect(checkIns.single.vitals.systolic, 120);
    expect((await DriftAllergiesDataSource(db: db, activeProfile: active).findAll()).single.name, 'Test allergy');
    expect((await DriftChronicConditionsDataSource(db: db, activeProfile: active).findAll()).single.name,
        'Test condition');
    expect((await DriftEmergencyContactsDataSource(db: db, activeProfile: active).findAll()).single.isPrimary, isTrue);
  });

  test('the other account on the device keeps its own entries, and only those', () async {
    final db = await open();
    final b = await db.resolveActiveHealthProfile(userB);

    expect((await DriftRecordsDataSource(db, () => b).findAll()).map((r) => r.id.value), ['rec-b']);
    expect((await DriftPrescriptionsDataSource(db, () => b).findAll()).map((p) => p.id.value), ['rx-b']);
    expect(await DriftMedicationsDataSource(db, () => b).findAll(), isEmpty);
    expect(await rows(db, 'SELECT COUNT(*) FROM prescription WHERE health_profile_id IS NULL'), ['0']);
    expect(await rows(db, 'SELECT COUNT(*) FROM medications WHERE health_profile_id IS NULL'), ['0']);
    expect(await rows(db, 'SELECT COUNT(*) FROM health_record WHERE health_profile_id IS NULL'), ['0']);
  });

  test('the new family features write to an upgraded database', () async {
    final db = await open();
    final self = await db.resolveActiveHealthProfile(userA);
    final profiles = DriftProfileDataSource(db: db, activeUser: () => userA);
    final child = HealthProfile.createMember(
      id: const HealthProfileId.value('hp-member'),
      userId: userA,
      kind: ProfileKind.dependent,
      displayName: 'Test Member',
      now: DateTime.utc(2026, 11, 1),
      dateOfBirth: DateTime.utc(2020, 1, 1),
      sex: Sex.female,
      relationship: Relationship.child,
    ).value;

    await profiles.createMember(child);
    expect(await db.setActiveHealthProfile(userA, child.id), isTrue);
    final vaccinations = DriftVaccinationsDataSource(db: db, activeProfile: () => child.id, activeUser: () => userA);
    final dose = VaccinationRecord(
      id: const VaccinationRecordId.value('vac-1'),
      vaccine: 'Test vaccine',
      doseNumber: 1,
      administeredOn: DateTime.utc(2021, 1, 1),
      createdAt: DateTime.utc(2026, 11, 1),
    );
    await vaccinations.put(dose.id, dose);

    expect(await db.resolveActiveHealthProfile(userA), child.id);
    expect((await vaccinations.findAll()).map((v) => v.id.value), ['vac-1']);
    expect(await DriftRecordsDataSource(db, () => child.id).findAll(), isEmpty,
        reason: 'the account holder\'s v0.8 records stay theirs');
    expect(await db.selfHealthProfileId(userA), self);
  });

  test('reopening changes nothing: a member is never promoted to self', () async {
    var db = await open();
    final self = await db.resolveActiveHealthProfile(userA);
    await DriftProfileDataSource(db: db, activeUser: () => userA).createMember(HealthProfile.createMember(
      id: const HealthProfileId.value('hp-member'),
      userId: userA,
      kind: ProfileKind.dependent,
      displayName: 'Test Member',
      now: DateTime.utc(2026, 11, 1),
    ).value);
    final before = await rows(db, 'SELECT id, is_self, kind FROM health_profile ORDER BY rowid');
    await db.close();

    db = await open();

    expect(await rows(db, 'SELECT id, is_self, kind FROM health_profile ORDER BY rowid'), before);
    expect(await db.selfHealthProfileId(userA), self);
  });
}
