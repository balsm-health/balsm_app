import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// The member medical profile form saves as one: blood type, allergy and
/// condition names, changing only the difference. Synthetic data only.
void main() {
  const user = UserId.value('u-medical');
  const memberId = HealthProfileId.value('hp-member');
  late AppDatabase db;
  late HealthProfilesDataSource ds;
  late SaveMedicalSummaryUseCase save;
  late AddAllergyUseCase addAllergy;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    ds = DriftProfileDataSource(db: db, activeUser: () => user);
    final selfId = await db.ensureSelfHealthProfile(user);
    final member = HealthProfile.createMember(
      id: memberId,
      userId: user,
      kind: ProfileKind.dependent,
      displayName: 'Test Member',
      now: DateTime.utc(2026, 11, 3),
      dateOfBirth: DateTime.utc(2019, 1, 1),
      sex: Sex.female,
    ).value;
    await ds.createMember(member);
    final bus = EventBus();
    final allergies = DriftAllergiesDataSource(db: db, activeProfile: () => selfId);
    final conditions = DriftChronicConditionsDataSource(db: db, activeProfile: () => selfId);
    addAllergy = AddAllergyUseCase(dao: ds, allergies: allergies, eventBus: bus);
    save = SaveMedicalSummaryUseCase(
      dao: ds,
      update: UpdateHealthProfileUseCase(dao: ds, eventBus: bus),
      addAllergy: addAllergy,
      removeAllergy: RemoveAllergyUseCase(dao: ds, allergies: allergies, eventBus: bus),
      addCondition: AddChronicConditionUseCase(dao: ds, conditions: conditions, eventBus: bus),
      removeCondition: RemoveChronicConditionUseCase(dao: ds, conditions: conditions, eventBus: bus),
    );
  });
  tearDown(() => db.close());

  test('writes the member, never self', () async {
    final r = await save.execute(
      userId: user,
      profileId: memberId,
      bloodType: BloodType.aNegative,
      allergies: ['Test allergen', ' ', 'test ALLERGEN'],
      conditions: ['Test condition'],
    );

    expect(r.isSuccess, isTrue);
    final m = (await ds.find(memberId))!;
    expect(m.bloodType, BloodType.aNegative);
    expect(m.allergies.map((a) => a.name), ['Test allergen']);
    expect(m.conditions.map((c) => c.name), ['Test condition']);
    final self = (await ds.getProfile(user))!;
    expect(self.bloodType, isNull);
    expect(self.allergies, isEmpty);
    expect(self.conditions, isEmpty);
  });

  test('changes only the difference and keeps a kept allergy as stored', () async {
    await addAllergy.execute(userId: user, profileId: memberId, name: 'Test kept', severity: 'severe');
    await addAllergy.execute(userId: user, profileId: memberId, name: 'Test dropped', severity: 'mild');
    final keptId = (await ds.find(memberId))!.allergies.firstWhere((a) => a.name == 'Test kept').id;

    final r = await save.execute(
      userId: user,
      profileId: memberId,
      bloodType: null,
      allergies: ['test kept', 'Test new'],
      conditions: const [],
    );

    expect(r.isSuccess, isTrue);
    final m = (await ds.find(memberId))!;
    expect(m.allergies.map((a) => a.name).toSet(), {'Test kept', 'Test new'});
    final kept = m.allergies.firstWhere((a) => a.name == 'Test kept');
    expect(kept.id, keptId);
    expect(kept.severity, 'severe');
  });

  test('clears the blood type when none is chosen', () async {
    await save.execute(
        userId: user, profileId: memberId, bloodType: BloodType.oPositive, allergies: const [], conditions: const []);
    await save.execute(userId: user, profileId: memberId, bloodType: null, allergies: const [], conditions: const []);

    expect((await ds.find(memberId))!.bloodType, isNull);
  });

  test('a closed member is not found', () async {
    await ds.closeMember(memberId, DateTime.utc(2026, 11, 4));

    final r = await save
        .execute(userId: user, profileId: memberId, bloodType: null, allergies: const ['Test'], conditions: const []);

    expect(r.isFailure, isTrue);
    expect(r.error, isA<NotFoundFailure>());
  });
}
