import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// Care team persistence + the add/remove use cases.
///
/// Everything here is patient-entered and stays on the device; the design
/// prototype's seeded sample doctors deliberately have no counterpart, so a
/// fresh profile starts with an empty team.
void main() {
  late AppDatabase db;
  late HealthProfilesDataSource dao;
  late CareProvidersDataSource providers;
  late EventBus bus;
  late AddCareProviderUseCase add;
  late RemoveCareProviderUseCase remove;
  const user = UserId.value('u-care-1');

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Creates the profile row every care_provider row must reference.
    await db.ensureSelfHealthProfile(user);
    dao = DriftProfileDataSource(db: db, activeUser: () => user);
    providers = DriftCareProvidersDataSource(db: db, activeProfile: () => null);
    bus = EventBus();
    add = AddCareProviderUseCase(dao: dao, providers: providers, eventBus: bus);
    remove = RemoveCareProviderUseCase(providers: providers, eventBus: bus);
  });
  tearDown(() => db.close());

  Future<HealthProfileId> profileId() async => (await dao.getProfile(user))!.id;

  test('a fresh profile has no care team', () async {
    expect(await providers.findAll(scope: await profileId()), isEmpty);
  });

  test('every field round-trips', () async {
    final result = await add.execute(
      userId: user,
      type: CareProviderType.pharmacy,
      name: 'Corner pharmacy',
      specialty: 'Delivery',
      phone: '0223456789',
      phone2: '0100000000',
      email: 'hello@corner.eg',
      clinic: 'Maadi branch',
      address: '12 Street 9, Maadi',
      notes: 'Open until midnight',
    );
    expect(result.isSuccess, isTrue);

    final saved = (await providers.findAll(scope: await profileId())).single;
    expect(saved.type, CareProviderType.pharmacy);
    expect(saved.name, 'Corner pharmacy');
    expect(saved.specialty, 'Delivery');
    expect(saved.phone, '0223456789');
    expect(saved.phone2, '0100000000');
    expect(saved.email, 'hello@corner.eg');
    expect(saved.clinic, 'Maadi branch');
    expect(saved.address, '12 Street 9, Maadi');
    expect(saved.notes, 'Open until midnight');
    // The use case returns the row under its persisted id, not the placeholder.
    expect(result.value.id, saved.id);
  });

  test('only the name is required, and blank optionals stay null', () async {
    final result = await add.execute(
      userId: user,
      type: CareProviderType.other,
      name: 'The nurse from the clinic',
      specialty: '   ',
      phone: '',
    );
    expect(result.isSuccess, isTrue);

    final saved = (await providers.findAll(scope: await profileId())).single;
    expect(saved.name, 'The nurse from the clinic');
    // Empty strings would defeat every "has a value" check the card makes.
    expect(saved.specialty, isNull);
    expect(saved.phone, isNull);
    expect(saved.placeLine, isNull);
  });

  test('a nameless provider is rejected', () async {
    final result = await add.execute(userId: user, type: CareProviderType.doctor, name: '  ');
    expect(result.isSuccess, isFalse);
    expect(result.error, isA<ValidationFailure>());
    expect(await providers.findAll(scope: await profileId()), isEmpty);
  });

  test('over-long free text is truncated, not rejected', () async {
    await add.execute(
      userId: user,
      type: CareProviderType.doctor,
      name: 'x' * 500,
      notes: 'n' * 900,
    );
    final saved = (await providers.findAll(scope: await profileId())).single;
    expect(saved.name.length, AddCareProviderUseCase.maxFieldLength);
    expect(saved.notes!.length, AddCareProviderUseCase.maxNotesLength);
  });

  test('the team is ordered oldest first', () async {
    for (final name in ['first', 'second', 'third']) {
      await add.execute(userId: user, type: CareProviderType.doctor, name: name);
    }
    final team = await providers.findAll(scope: await profileId());
    expect(team.map((p) => p.name), ['first', 'second', 'third']);
  });

  test('placeLine joins clinic and address, and skips what is missing', () async {
    await add.execute(
      userId: user,
      type: CareProviderType.clinic,
      name: 'Balsm Medical Centre',
      address: 'Maadi, Cairo',
    );
    final saved = (await providers.findAll(scope: await profileId())).single;
    expect(saved.placeLine, 'Maadi, Cairo');
  });

  test('removing takes the row out and publishes', () async {
    await add.execute(userId: user, type: CareProviderType.lab, name: 'Alfa Lab');
    final saved = (await providers.findAll(scope: await profileId())).single;

    final events = <AppEvent>[];
    final sub = bus.events.listen(events.add);
    addTearDown(sub.cancel);

    final result = await remove.execute(userId: user, providerId: saved.id);
    expect(result.isSuccess, isTrue);
    expect(await providers.findAll(scope: await profileId()), isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(events.single, isA<HealthProfileUpdated>());
  });

  test('removing an id that is already gone succeeds', () async {
    final result = await remove.execute(userId: user, providerId: CareProviderId.value('cp-missing'));
    expect(result.isSuccess, isTrue);
  });

  test('deleting the profile cascades the care team away', () async {
    await add.execute(userId: user, type: CareProviderType.doctor, name: 'Dr. Someone');
    final id = await profileId();
    await dao.delete(id);
    expect(await providers.findAll(scope: id), isEmpty);
  });

  test('watchProviders emits the current team', () async {
    await add.execute(userId: user, type: CareProviderType.physio, name: 'Physio');
    final team = await providers.watchAll(scope: await profileId()).first;
    expect(team.single.name, 'Physio');
  });

  test('an unknown stored type degrades to doctor rather than throwing', () {
    expect(CareProviderType.fromId('telepath'), CareProviderType.doctor);
    expect(CareProviderType.fromId(null), CareProviderType.doctor);
  });

  test('places relabel their name and specialty fields', () {
    expect(CareProviderType.pharmacy.isPlace, isTrue);
    expect(CareProviderType.lab.isPlace, isTrue);
    expect(CareProviderType.clinic.isPlace, isTrue);
    expect(CareProviderType.doctor.isPlace, isFalse);
    expect(CareProviderType.carer.isPlace, isFalse);
  });

  group('provider files', () {
    Future<CareProviderId> withProvider() async {
      await add.execute(userId: user, type: CareProviderType.doctor, name: 'Dr. Ahmed');
      return (await providers.findAll(scope: await profileId())).single.id;
    }

    test('files attach and read back oldest first', () async {
      final id = await withProvider();
      await providers.putFile(id, 'vault/card.jpg');
      await providers.putFile(id, 'vault/referral.pdf');
      expect(await providers.findFiles(id), ['vault/card.jpg', 'vault/referral.pdf']);
    });

    test('detaching removes only the named path', () async {
      final id = await withProvider();
      await providers.putFile(id, 'vault/a.jpg');
      await providers.putFile(id, 'vault/b.jpg');
      await providers.deleteFile(id, 'vault/a.jpg');
      expect(await providers.findFiles(id), ['vault/b.jpg']);
    });

    test('removing the provider cascades its files away', () async {
      final id = await withProvider();
      await providers.putFile(id, 'vault/card.jpg');
      await remove.execute(userId: user, providerId: id);
      expect(await providers.findFiles(id), isEmpty);
    });

    test('files are scoped to their own provider', () async {
      final first = await withProvider();
      await add.execute(userId: user, type: CareProviderType.lab, name: 'Alfa');
      final second = (await providers.findAll(scope: await profileId())).last.id;
      await providers.putFile(first, 'vault/only-first.jpg');
      expect(await providers.findFiles(second), isEmpty);
    });

    test('watchProviderFiles emits the current set', () async {
      final id = await withProvider();
      await providers.putFile(id, 'vault/card.jpg');
      expect(await providers.watchFiles(id).first, ['vault/card.jpg']);
    });
  });
}
