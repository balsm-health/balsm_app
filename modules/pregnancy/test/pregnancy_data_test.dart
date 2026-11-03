import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pregnancy/pregnancy.dart';

/// The drift data source and the use cases over it, with an in-memory
/// babies port standing in for the profile module (which the app binds in
/// production). Baby rows are written to `health_profile` so the item links'
/// foreign keys hold. Synthetic data only.
void main() {
  const user = UserId.value('u-preg');
  final now = DateTime(2026, 11, 3);
  late AppDatabase db;
  late HealthProfileId self;
  late DriftPregnanciesDataSource ds;
  late _FakeBabies babies;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    self = await db.ensureSelfHealthProfile(user);
    ds = DriftPregnanciesDataSource(db: db, activeProfile: () => self);
    babies = _FakeBabies(db, user);
  });
  tearDown(() => db.close());

  StartPregnancyUseCase start() => StartPregnancyUseCase(pregnancies: ds, babies: babies);

  Future<Pregnancy> twins() async =>
      (await start()(motherId: self, dueDate: DateTime(2027, 2, 21), babyCount: 2, now: now, obName: 'Test Doctor'))
          .value;

  PregnancyRecordsUseCase records() => PregnancyRecordsUseCase(pregnancies: ds, babies: babies);

  group('DriftPregnanciesDataSource', () {
    test('a pregnancy round-trips and is partitioned by the mother', () async {
      final p = await twins();
      final withVisit = (await records().setNextVisit(
        p.id,
        NextVisit(date: DateTime(2026, 11, 14), time: '10:30', clinic: 'Test Clinic'),
        motherId: self,
        now: now,
      ))
          .value;

      final stored = (await ds.find(p.id))!;
      expect(stored.dueDate, DateTime.utc(2027, 2, 21));
      expect(stored.obName, 'Test Doctor');
      expect(stored.nextVisit!.time, '10:30');
      expect(stored.nextVisit!.clinic, withVisit.nextVisit!.clinic);
      expect((await ds.findActive())!.id, p.id);
      expect(await ds.find(p.id, scope: const HealthProfileId.value('hp-other')), isNull);
      expect(
        () => ds.put(p.id, p, scope: const HealthProfileId.value('hp-other')),
        throwsA(isA<StorageWriteException>()),
      );
    });

    test('items keep their baby links, newest first; delete is soft', () async {
      final p = await twins();
      final [a, b] = await babies.listBabies(p.id);
      await records().addItem(
        pregnancyId: p.id,
        motherId: self,
        about: ItemAbout.baby,
        babyIds: [a.id, b.id],
        kind: ItemKind.scan,
        recordedOn: DateTime(2026, 10, 6),
        now: now,
        title: 'Test shared scan',
        attachmentRef: 'vault/test.pdf',
      );
      final measured = (await records().addItem(
        pregnancyId: p.id,
        motherId: self,
        about: ItemAbout.baby,
        babyIds: [a.id],
        kind: ItemKind.measure,
        recordedOn: DateTime(2026, 11, 1),
        now: now,
        fetalHeartRateBpm: 144,
        estimatedFetalWeightG: 610,
      ))
          .value;

      final items = await ds.findItems(p.id);
      expect(items.map((i) => i.title ?? 'measure'), ['measure', 'Test shared scan']);
      expect(items.last.babyIds, [a.id, b.id]);
      expect(items.last.attachmentRef, 'vault/test.pdf');
      expect(items.first.fetalHeartRateBpm, 144);

      expect(await ds.deleteItem(measured.id), isTrue);
      expect(await ds.deleteItem(measured.id), isFalse);
      expect((await ds.findItems(p.id)).length, 1);
      final kept = await db.customSelect('SELECT COUNT(*) AS n FROM pregnancy_item').getSingle();
      expect(kept.read<int>('n'), 2, reason: 'soft delete keeps the row');
    });

    test('watchAll and watchItems re-emit after writes', () async {
      final seen = <int>[];
      final sub = ds.watchAll().listen((l) => seen.add(l.length));
      await pumpEventQueue();
      final p = await twins();
      await pumpEventQueue();
      final items = <int>[];
      final sub2 = ds.watchItems(p.id).listen((l) => items.add(l.length));
      await pumpEventQueue();
      await records().addItem(
        pregnancyId: p.id,
        motherId: self,
        about: ItemAbout.me,
        babyIds: const [],
        kind: ItemKind.doc,
        recordedOn: now,
        now: now,
        title: 'Test blood count',
      );
      await pumpEventQueue();

      expect(seen.first, 0);
      expect(seen.last, 1);
      expect(items, [0, 1]);
      await sub.cancel();
      await sub2.cancel();
    });
  });

  group('use cases', () {
    test('start creates one prenatal baby per count and refuses a second pregnancy', () async {
      final p = await twins();

      final list = await babies.listBabies(p.id);
      expect(list.map((b) => b.sequence), [1, 2]);
      expect(list.every((b) => b.isActive), isTrue);
      final again = await start()(motherId: self, dueDate: DateTime(2027, 2, 21), babyCount: 1, now: now);
      expect(again.error.message, 'alreadyTracking');
      final none = await start()(motherId: self, dueDate: DateTime(2027, 2, 21), babyCount: 0, now: now);
      expect(none.error.message, 'babyCount');
    });

    test('adding a baby takes the next sequence', () async {
      final p = await twins();
      final use = PregnancyBabiesUseCase(pregnancies: ds, babies: babies);

      final added = await use.add(p.id, motherId: self, now: now);

      expect(added.value.sequence, 3);
    });

    test('stopping one baby closes that profile only; the last one closes the pregnancy as ended', () async {
      final p = await twins();
      final [a, b] = await babies.listBabies(p.id);
      final use = PregnancyBabiesUseCase(pregnancies: ds, babies: babies);

      final first = await use.stopFollowing(p.id, a.id, motherId: self, now: now);
      expect(first.value.isActive, isTrue);
      expect(babies.byId[a.id]!.status, BabyStatus.closed);
      expect(babies.byId[b.id]!.status, BabyStatus.active);

      final last = await use.stopFollowing(p.id, b.id, motherId: self, now: now);
      expect(last.value.status, PregnancyStatus.ended);
      expect((await ds.find(p.id))!.status, PregnancyStatus.ended);
      expect(await ds.findActive(), isNull);
    });

    test('ending closes the pregnancy and every baby still followed, keeping the records', () async {
      final p = await twins();
      final [a, _] = await babies.listBabies(p.id);
      await records().addItem(
        pregnancyId: p.id,
        motherId: self,
        about: ItemAbout.baby,
        babyIds: [a.id],
        kind: ItemKind.measure,
        recordedOn: now,
        now: now,
        fetalHeartRateBpm: 150,
      );

      final ended = await EndPregnancyUseCase(pregnancies: ds, babies: babies)(p.id, motherId: self, now: now);

      expect(ended.value.status, PregnancyStatus.ended);
      expect((await babies.listBabies(p.id)).every((b) => b.status == BabyStatus.closed), isTrue);
      expect((await ds.findItems(p.id)).length, 1);
      final again = await EndPregnancyUseCase(pregnancies: ds, babies: babies)(p.id, motherId: self, now: now);
      expect(again.error.message, 'closed');
    });

    test('birth keeps the baby id, detaches unticked records and closes as birth with the last baby', () async {
      final p = await twins();
      final [a, b] = await babies.listBabies(p.id);
      Future<PregnancyItem> add(List<HealthProfileId> ids, String title) async => (await records().addItem(
            pregnancyId: p.id,
            motherId: self,
            about: ItemAbout.baby,
            babyIds: ids,
            kind: ItemKind.scan,
            recordedOn: now,
            now: now,
            title: title,
          ))
              .value;
      final shared = await add([a.id, b.id], 'Test shared');
      final mine = await add([a.id], 'Test a only');
      final birth = RecordBirthUseCase(pregnancies: ds, babies: babies);

      final afterA = await birth(
        p.id,
        BirthDetails(
          babyId: a.id,
          name: 'Test Baby',
          sex: Sex.female,
          dateOfBirth: now,
          keepItemIds: {mine.id},
        ),
        motherId: self,
        now: now,
      );

      expect(afterA.value.isActive, isTrue, reason: 'the other baby is still followed');
      expect(babies.byId[a.id]!.status, BabyStatus.born);
      expect(babies.births.single.babyId, a.id, reason: 'the same profile id is born');
      final items = {for (final i in await ds.findItems(p.id)) i.id: i};
      expect(items[mine.id]!.babyIds, [a.id]);
      expect(items[shared.id]!.babyIds, [b.id], reason: 'unticked: detached from the child, kept on the pregnancy');

      final refused = await birth(p.id, BirthDetails(babyId: b.id, name: '', sex: null, dateOfBirth: now),
          motherId: self, now: now);
      expect(refused.error.message, 'nameRequired,sexRequired');

      final afterB = await birth(p.id, BirthDetails(babyId: b.id, name: 'Test Twin', sex: Sex.male, dateOfBirth: now),
          motherId: self, now: now);
      expect(afterB.value.status, PregnancyStatus.birth);
      expect((await ds.findItems(p.id)).firstWhere((i) => i.id == shared.id).babyIds, isEmpty);
    });

    test('items refuse a baby that is no longer followed', () async {
      final p = await twins();
      final [a, _] = await babies.listBabies(p.id);
      await PregnancyBabiesUseCase(pregnancies: ds, babies: babies).stopFollowing(p.id, a.id, motherId: self, now: now);

      final r = await records().addItem(
        pregnancyId: p.id,
        motherId: self,
        about: ItemAbout.baby,
        babyIds: [a.id],
        kind: ItemKind.measure,
        recordedOn: now,
        now: now,
        fetalHeartRateBpm: 140,
      );

      expect(r.error, isA<NotFoundFailure>());
    });
  });
}

/// In-memory [PregnancyBabiesPort]. Each baby also gets a bare
/// `health_profile` row so the `pregnancy_item_baby` foreign keys hold.
class _FakeBabies implements PregnancyBabiesPort {
  _FakeBabies(this._db, this._user);

  final AppDatabase _db;
  final UserId _user;
  final byId = <HealthProfileId, PregnancyBaby>{};
  final births = <BirthDetails>[];

  @override
  Future<AppResult<PregnancyBaby>> addBaby(PregnancyId pregnancy,
      {required int sequence, required DateTime now}) async {
    final id = HealthProfileId.uuid();
    await _db.customInsert(
      "INSERT INTO health_profile (id, user_id, kind, updated_at) VALUES (?, ?, 'prenatal', 0)",
      variables: [Variable.withString(id.value), Variable.withString(_user.value)],
    );
    final b = PregnancyBaby(id: id, pregnancyId: pregnancy, sequence: sequence, status: BabyStatus.active);
    byId[id] = b;
    return AppResult.success(b);
  }

  @override
  Future<List<PregnancyBaby>> listBabies(PregnancyId pregnancy) async =>
      byId.values.where((b) => b.pregnancyId == pregnancy).toList()..sort((a, b) => a.sequence.compareTo(b.sequence));

  @override
  Stream<List<PregnancyBaby>> watchBabies(PregnancyId pregnancy) => Stream.fromFuture(listBabies(pregnancy));

  @override
  Future<AppResult<void>> renameBaby(HealthProfileId id, String? name, {required DateTime now}) async =>
      _set(id, name: name);

  @override
  Future<AppResult<void>> closeBaby(HealthProfileId id, {required DateTime now}) async =>
      _set(id, status: BabyStatus.closed);

  @override
  Future<AppResult<void>> recordBirth(BirthDetails details, {required DateTime now}) async {
    births.add(details);
    return _set(details.babyId, status: BabyStatus.born, name: details.name);
  }

  AppResult<void> _set(HealthProfileId id, {BabyStatus? status, String? name}) {
    final b = byId[id];
    if (b == null || !b.isActive) return AppResult.failure(const NotFoundFailure());
    byId[id] = PregnancyBaby(
      id: b.id,
      pregnancyId: b.pregnancyId,
      sequence: b.sequence,
      status: status ?? b.status,
      name: name ?? b.name,
    );
    return AppResult.success(null);
  }
}
