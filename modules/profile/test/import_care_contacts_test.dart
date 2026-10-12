import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// Turning picked contacts into care-team records.
///
/// Goes through the data source like any other write, so every imported row
/// queues a push exactly as a hand-typed one does. Nothing here talks to the
/// network directly.
void main() {
  late AppDatabase db;
  late HealthProfilesDataSource dao;
  late CareProvidersDataSource providers;
  late EventBus bus;
  late ImportCareContactsUseCase import;
  const user = UserId.value('u-import-1');

  ImportedContact contact(String name, {String? phone, String? email}) => ImportedContact(
        id: 'c-$name',
        name: name,
        phones: phone == null ? const [] : [phone],
        email: email,
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.ensureSelfHealthProfile(user);
    dao = DriftProfileDataSource(db: db, activeUser: () => user);
    providers = DriftCareProvidersDataSource(db: db, activeProfile: () => null);
    bus = EventBus();
    import = ImportCareContactsUseCase(dao: dao, providers: providers, eventBus: bus);
  });

  tearDown(() => db.close());

  Future<HealthProfileId> profileId() async => (await dao.getProfile(user))!.id;

  test('imports every selected contact as a care provider', () async {
    final result = await import.execute(
      userId: user,
      contacts: [
        contact('Dr. Sara Kamal', phone: '+201002345678', email: 'sara@example.test'),
        contact('El Ezaby Pharmacy', phone: '+20219600'),
      ],
    );

    expect(result.isSuccess, isTrue);
    final team = await providers.findAll(scope: await profileId());
    expect(team.map((p) => p.name).toSet(), {'Dr. Sara Kamal', 'El Ezaby Pharmacy'});
    expect(team.firstWhere((p) => p.name == 'Dr. Sara Kamal').type, CareProviderType.doctor);
    expect(team.firstWhere((p) => p.name == 'El Ezaby Pharmacy').type, CareProviderType.pharmacy);
  });

  test('each imported row gets its own id', () async {
    await import.execute(
      userId: user,
      contacts: [contact('A', phone: '+201000000001'), contact('B', phone: '+201000000002')],
    );

    final team = await providers.findAll(scope: await profileId());
    expect(team.map((p) => p.id.value).toSet(), hasLength(2));
  });

  test('a contact already on the team is skipped, not duplicated', () async {
    await import.execute(userId: user, contacts: [contact('Dr. Sara Kamal', phone: '+201002345678')]);

    // Same human, the other spelling of the number.
    final second = await import.execute(
      userId: user,
      contacts: [contact('Dr. Sara Kamal', phone: '01002345678')],
    );

    expect(second.isSuccess, isTrue);
    expect(second.value, isEmpty, reason: 'nothing new was imported');
    expect(await providers.findAll(scope: await profileId()), hasLength(1));
  });

  test('an empty selection is a no-op, not an error', () async {
    final result = await import.execute(userId: user, contacts: const []);

    expect(result.isSuccess, isTrue);
    expect(result.value, isEmpty);
    expect(await providers.findAll(scope: await profileId()), isEmpty);
  });

  test('publishes one profile-updated event for the whole batch', () async {
    final seen = <AppEvent>[];
    final sub = bus.events.listen(seen.add);

    await import.execute(
      userId: user,
      contacts: [contact('A', phone: '+201000000001'), contact('B', phone: '+201000000002')],
    );
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    // One event, not one per row — the care team changed once.
    expect(seen.whereType<HealthProfileUpdated>(), hasLength(1));
  });

  test('importing nothing publishes nothing', () async {
    final seen = <AppEvent>[];
    final sub = bus.events.listen(seen.add);

    await import.execute(userId: user, contacts: const []);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen.whereType<HealthProfileUpdated>(), isEmpty);
  });

  test('imports only as many as the cap allows rather than refusing the batch', () async {
    // A patient at the ceiling who picks five more should get the ones that fit,
    // not a wall. The sheet reports how many landed.
    final existing = List.generate(
      ImportCareContactsUseCase.maxProviders - 2,
      (i) => contact('Filler $i', phone: '+2010000${i.toString().padLeft(5, '0')}'),
    );
    await import.execute(userId: user, contacts: existing);

    final result = await import.execute(
      userId: user,
      contacts: [
        contact('Fits One', phone: '+201999000001'),
        contact('Fits Two', phone: '+201999000002'),
        contact('Too Many', phone: '+201999000003'),
      ],
    );

    expect(result.value, hasLength(2));
    expect(await providers.findAll(scope: await profileId()), hasLength(ImportCareContactsUseCase.maxProviders));
  });

  test('a contact with an over-long name is truncated, not rejected', () async {
    final long = 'x' * (ImportCareContactsUseCase.maxFieldLength + 50);

    final result = await import.execute(userId: user, contacts: [contact(long, phone: '+201000000009')]);

    expect(result.isSuccess, isTrue);
    expect(result.value.single.name.length, ImportCareContactsUseCase.maxFieldLength);
  });

  test('a contact with a blank name is skipped', () async {
    final result = await import.execute(userId: user, contacts: [contact('   ', phone: '+201000000010')]);

    expect(result.value, isEmpty);
    expect(await providers.findAll(scope: await profileId()), isEmpty);
  });
}
