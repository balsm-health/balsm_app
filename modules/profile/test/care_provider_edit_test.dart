import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile/profile.dart';

/// Editing a care-team member, and the map link the card's Directions action
/// reads (`home.jsx` — the card's remove button became an edit button).
///
/// Editing has to keep the row id: the provider's attached files hang off it,
/// and the old remove-and-re-add path silently dropped them.
void main() {
  late AppDatabase db;
  late HealthProfilesDataSource dao;
  late EventBus bus;
  late AddCareProviderUseCase add;
  late UpdateCareProviderUseCase update;
  const user = UserId.value('u-care-edit');

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.ensureSelfHealthProfile(user);
    dao = DriftProfileDataSource(db: db, activeUser: () => user);
    bus = EventBus();
    add = AddCareProviderUseCase(dao: dao, eventBus: bus);
    update = UpdateCareProviderUseCase(dao: dao, eventBus: bus);
  });
  tearDown(() => db.close());

  Future<CareProvider> seed({String? mapUrl}) async {
    final r = await add.execute(
      userId: user,
      type: CareProviderType.doctor,
      name: 'Dr. Sara Kamal',
      specialty: 'Internal medicine',
      phone: '+20 2 2555 0100',
      clinic: 'Maadi Medical Centre',
      mapUrl: mapUrl,
    );
    return r.value;
  }

  group('editing', () {
    test('an edit keeps the row id, so attached files survive it', () async {
      final p = await seed();
      await dao.addProviderFile(p.id, 'vault/card.png');

      final r = await update.execute(
        userId: user,
        provider: p,
        type: p.type,
        name: 'Dr. Sara Kamal',
        phone: '+20 2 2555 0199',
      );

      expect(r.isSuccess, isTrue);
      expect(r.value.id, p.id, reason: 'a new id would orphan the files');
      expect(await dao.listProviderFiles(p.id), ['vault/card.png']);
    });

    test('cleared fields persist as null, not empty strings', () async {
      final p = await seed();
      await update.execute(
        userId: user,
        provider: p,
        type: p.type,
        name: 'Dr. Sara Kamal',
        specialty: '',
        clinic: '   ',
      );
      final stored = (await dao.listProviders(p.healthProfileId)).single;
      expect(stored.specialty, isNull);
      expect(stored.clinic, isNull);
    });

    test('the type can change — a clinic becomes a lab', () async {
      final p = await seed();
      await update.execute(
        userId: user,
        provider: p,
        type: CareProviderType.lab,
        name: p.name,
      );
      expect((await dao.listProviders(p.healthProfileId)).single.type, CareProviderType.lab);
    });

    test('a nameless edit is refused and changes nothing', () async {
      final p = await seed();
      final r = await update.execute(userId: user, provider: p, type: p.type, name: '  ');
      expect(r.isSuccess, isFalse);
      expect((await dao.listProviders(p.healthProfileId)).single.name, 'Dr. Sara Kamal');
    });

    test('editing does not add a second row', () async {
      final p = await seed();
      await update.execute(userId: user, provider: p, type: p.type, name: 'Dr. S. Kamal');
      final all = await dao.listProviders(p.healthProfileId);
      expect(all, hasLength(1));
      expect(all.single.name, 'Dr. S. Kamal');
    });

    test('createdAt is not rewritten by an edit', () async {
      final p = await seed();
      // Compared row-to-row: `created_at` is stored as epoch milliseconds, so
      // the in-memory entity's microseconds do not survive the first write.
      final before = (await dao.listProviders(p.healthProfileId)).single.createdAt;
      await update.execute(userId: user, provider: p, type: p.type, name: 'Dr. S. Kamal');
      expect((await dao.listProviders(p.healthProfileId)).single.createdAt, before);
    });
  });

  group('map link', () {
    test('an https link round-trips and offers directions', () async {
      final p = await seed(mapUrl: 'https://maps.app.goo.gl/abc123');
      final stored = (await dao.listProviders(p.healthProfileId)).single;
      expect(stored.mapUrl, 'https://maps.app.goo.gl/abc123');
      expect(stored.hasDirections, isTrue);
    });

    test('no link, no directions', () async {
      final p = await seed();
      expect((await dao.listProviders(p.healthProfileId)).single.hasDirections, isFalse);
    });

    test('a typed address is stored but is not a destination', () async {
      final p = await seed(mapUrl: '12 Street 9, Maadi');
      final stored = (await dao.listProviders(p.healthProfileId)).single;
      expect(stored.mapUrl, '12 Street 9, Maadi', reason: 'what the patient typed is kept');
      expect(stored.hasDirections, isFalse, reason: 'but it is not launchable');
    });

    test('a non-web scheme is never offered as a link', () async {
      for (final bad in ['javascript:alert(1)', 'file:///etc/passwd', 'tel:+20225550100']) {
        final p = await seed(mapUrl: bad);
        expect(
          (await dao.listProviders(p.healthProfileId)).last.hasDirections,
          isFalse,
          reason: '$bad must not become a tappable link',
        );
      }
    });

    test('a link can be added by editing a provider saved without one', () async {
      final p = await seed();
      await update.execute(
        userId: user,
        provider: p,
        type: p.type,
        name: p.name,
        mapUrl: 'https://maps.apple.com/?q=Maadi',
      );
      expect((await dao.listProviders(p.healthProfileId)).single.hasDirections, isTrue);
    });
  });
}
