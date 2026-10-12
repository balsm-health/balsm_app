import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// The profile's child collections, each through its own scoped source.
///
/// They were briefly written by `put` on the aggregate; that made a write of
/// one collection able to delete another, so each is its own source now with
/// the generic contract. These pin that the split actually isolates them.
void main() {
  late AppDatabase db;
  late HealthProfilesDataSource dao;
  late AllergiesDataSource allergies;
  late ChronicConditionsDataSource conditions;
  const user = UserId.value('u-children');
  late HealthProfileId profileId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.ensureSelfHealthProfile(user);
    dao = DriftProfileDataSource(db: db, activeUser: () => user);
    profileId = (await dao.getProfile(user))!.id;
    allergies = DriftAllergiesDataSource(db: db, activeProfile: () => profileId);
    conditions = DriftChronicConditionsDataSource(db: db, activeProfile: () => profileId);
  });
  tearDown(() => db.close());

  Allergy allergy(String name, {AllergyId? id}) => Allergy(
        id: id ?? AllergyId.uuid(),
        healthProfileId: profileId,
        name: name,
        severity: 'mild',
        isControlledSubstance: false,
        createdAt: DateTime.now().toUtc(),
      );

  test('put then findAll round-trips', () async {
    final a = allergy('Penicillin');
    await allergies.put(a.id, a);
    expect((await allergies.findAll()).map((x) => x.name), ['Penicillin']);
  });

  test('re-putting the same id edits rather than duplicating', () async {
    final a = allergy('Penicilin');
    await allergies.put(a.id, a);
    await allergies.put(a.id, allergy('Penicillin', id: a.id));

    final all = await allergies.findAll();
    expect(all, hasLength(1), reason: 'an edit must not add a second row');
    expect(all.single.name, 'Penicillin');
  });

  test('delete removes only its own row', () async {
    final a = allergy('Penicillin');
    final b = allergy('Aspirin');
    await allergies.put(a.id, a);
    await allergies.put(b.id, b);

    await allergies.delete(a.id);
    expect((await allergies.findAll()).map((x) => x.name), ['Aspirin']);
  });

  test('collections cannot disturb each other', () async {
    final a = allergy('Penicillin');
    await allergies.put(a.id, a);
    final c = ChronicCondition(
      id: ChronicConditionId.uuid(),
      healthProfileId: profileId,
      name: 'Hypertension',
      createdAt: DateTime.now().toUtc(),
    );
    await conditions.put(c.id, c);

    // The whole point of the split: clearing one leaves the other alone.
    await allergies.clear();
    expect(await allergies.findAll(), isEmpty);
    expect((await conditions.findAll()).map((x) => x.name), ['Hypertension']);
  });

  test('watchAll emits the current set', () async {
    final a = allergy('Penicillin');
    await allergies.put(a.id, a);
    expect(await allergies.watchAll().first, hasLength(1));
  });

  test('a read with no active profile is empty, and clear is a no-op', () async {
    final detached = DriftAllergiesDataSource(db: db, activeProfile: () => null);
    expect(await detached.findAll(), isEmpty);
    await detached.clear(); // must not throw — idempotent logout cleanup
  });
}
