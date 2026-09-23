import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// `put` writes the whole aggregate — head row AND child collections.
///
/// Reads have always hydrated allergies, conditions and contacts; writes used
/// to go through addAllergy/removeAllergy/… instead. That asymmetry is gone,
/// so these pin what replaced it: children round-trip, ids survive an edit,
/// and a child dropped from the value is deleted (last-write-wins).
void main() {
  late AppDatabase db;
  late HealthProfilesDataSource dao;
  const user = UserId.value('u-agg');

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.ensureSelfHealthProfile(user);
    dao = DriftProfileDataSource(db: db, activeUser: () => user);
  });
  tearDown(() => db.close());

  Future<HealthProfile> load() async => (await dao.getProfile(user))!;

  Allergy allergy(String name, {AllergyId? id, HealthProfileId? profile}) => Allergy(
        id: id ?? AllergyId.uuid(),
        healthProfileId: profile ?? const HealthProfileId.value('hp'),
        name: name,
        severity: 'mild',
        isControlledSubstance: false,
        createdAt: DateTime.now().toUtc(),
      );

  test('children round-trip through put', () async {
    var p = await load();
    p = p.copyWith(allergies: [allergy('Penicillin', profile: p.id)]);
    await dao.put(p.id, p);

    final back = await load();
    expect(back.allergies.map((a) => a.name), ['Penicillin']);
  });

  test('a child dropped from the value is deleted', () async {
    var p = await load();
    p = p.copyWith(allergies: [allergy('Penicillin', profile: p.id), allergy('Aspirin', profile: p.id)]);
    await dao.put(p.id, p);
    expect((await load()).allergies, hasLength(2));

    final keep = (await load()).allergies.where((a) => a.name == 'Aspirin').toList();
    await dao.put(p.id, p.copyWith(allergies: keep));

    expect((await load()).allergies.map((a) => a.name), ['Aspirin']);
  });

  test('an edit keeps the child id rather than minting a new row', () async {
    var p = await load();
    p = p.copyWith(allergies: [allergy('Penicilin', profile: p.id)]);
    await dao.put(p.id, p);

    final stored = (await load()).allergies.single;
    await dao.put(
      p.id,
      p.copyWith(allergies: [
        Allergy(
          id: stored.id,
          healthProfileId: stored.healthProfileId,
          name: 'Penicillin',
          severity: stored.severity,
          isControlledSubstance: stored.isControlledSubstance,
          createdAt: stored.createdAt,
        ),
      ]),
    );

    final after = await load();
    expect(after.allergies, hasLength(1), reason: 'an edit must not add a second row');
    expect(after.allergies.single.id, stored.id);
    expect(after.allergies.single.name, 'Penicillin');
  });

  test('putting an aggregate with no children clears them', () async {
    var p = await load();
    p = p.copyWith(allergies: [allergy('Penicillin', profile: p.id)]);
    await dao.put(p.id, p);

    await dao.put(p.id, p.copyWith(allergies: const []));
    expect((await load()).allergies, isEmpty);
  });

  test('each collection is independent', () async {
    var p = await load();
    p = p.copyWith(
      allergies: [allergy('Penicillin', profile: p.id)],
      conditions: [
        ChronicCondition(
          id: ChronicConditionId.uuid(),
          healthProfileId: p.id,
          name: 'Hypertension',
          createdAt: DateTime.now().toUtc(),
        ),
      ],
    );
    await dao.put(p.id, p);

    // Dropping every allergy must leave the conditions alone.
    final stored = await load();
    await dao.put(p.id, stored.copyWith(allergies: const []));

    final after = await load();
    expect(after.allergies, isEmpty);
    expect(after.conditions.map((c) => c.name), ['Hypertension']);
  });
}
