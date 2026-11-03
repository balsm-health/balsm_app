import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:family/family.dart';
import 'package:flutter_test/flutter_test.dart';

/// GrowthEntry rules and `growth_entry` persistence, partitioned by health
/// profile. Synthetic ids and values only.
void main() {
  final now = DateTime(2026, 11, 3, 18);

  group('GrowthEntry', () {
    test('weight alone, height alone or both; the day is kept as a calendar day', () {
      expect(GrowthEntry.violationsOf(measuredOn: now, weightKg: 12.5, heightCm: null, now: now), isEmpty);
      expect(GrowthEntry.violationsOf(measuredOn: now, weightKg: null, heightCm: 90, now: now), isEmpty);
      final r = GrowthEntry.record(measuredOn: DateTime(2026, 10, 1, 9), weightKg: 3.4, heightCm: 50, now: now);
      expect(r.value.measuredOn, DateTime.utc(2026, 10, 1));
      expect((r.value.weightKg, r.value.heightCm), (3.4, 50.0));
    });

    test('reports every broken rule at once', () {
      expect(GrowthEntry.violationsOf(measuredOn: null, weightKg: null, heightCm: null, now: now), [
        GrowthViolation.measuredOnRequired,
        GrowthViolation.measurementRequired,
      ]);
      expect(GrowthEntry.violationsOf(measuredOn: DateTime(2026, 11, 4), weightKg: 0.1, heightCm: 251, now: now), [
        GrowthViolation.measuredInFuture,
        GrowthViolation.weightOutOfRange,
        GrowthViolation.heightOutOfRange,
      ]);
      expect(GrowthEntry.violationsOf(measuredOn: now, weightKg: 301, heightCm: 19.9, now: now), [
        GrowthViolation.weightOutOfRange,
        GrowthViolation.heightOutOfRange,
      ]);
    });

    test('a failure names the broken rules', () {
      final r = GrowthEntry.record(measuredOn: now, weightKg: null, heightCm: null, now: now);
      expect(r.error, isA<ValidationFailure>());
      expect(r.error.message, 'measurementRequired');
    });
  });

  group('DriftGrowthLogDataSource', () {
    const user = UserId.value('u-growth');
    const other = UserId.value('u-growth-other');
    const child = HealthProfileId.value('hp-growth-child');
    const closed = HealthProfileId.value('hp-growth-closed');
    late AppDatabase db;
    late HealthProfileId self;
    late HealthProfileId otherSelf;
    HealthProfileId? active;
    late DriftGrowthLogDataSource ds;

    GrowthEntry entry(String id, DateTime on, {double? kg = 10, double? cm}) => GrowthEntry(
          id: GrowthEntryId.value(id),
          measuredOn: DateTime.utc(on.year, on.month, on.day),
          weightKg: kg,
          heightCm: cm,
          createdAt: DateTime.utc(2026),
        );

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      self = await db.ensureSelfHealthProfile(user);
      otherSelf = await db.ensureSelfHealthProfile(other);
      await db.customStatement("INSERT INTO health_profile (id, user_id, is_self, kind, updated_at) "
          "VALUES ('${child.value}', '${user.value}', 0, 'dependent', 0)");
      await db.customStatement("INSERT INTO health_profile (id, user_id, is_self, kind, status, updated_at) "
          "VALUES ('${closed.value}', '${user.value}', 0, 'dependent', 'closed', 0)");
      active = child;
      ds = DriftGrowthLogDataSource(
        db: db,
        activeProfile: () => active,
        activeUser: () => user,
        clock: () => DateTime.utc(2026, 11, 3),
      );
    });

    tearDown(() => db.close());

    test('round-trips an entry, newest first, per person', () async {
      await ds.put(const GrowthEntryId.value('g1'), entry('g1', DateTime(2026, 4, 3), kg: 9.1, cm: 74));
      await ds.put(const GrowthEntryId.value('g2'), entry('g2', DateTime(2026, 10, 5), kg: null, cm: 77.5));
      await ds.put(const GrowthEntryId.value('s1'), entry('s1', DateTime(2026, 9, 1)), scope: self);

      final log = await ds.findAll();
      expect([for (final g in log) g.id.value], ['g2', 'g1']);
      expect((log.first.weightKg, log.first.heightCm), (null, 77.5));
      expect(log.last.measuredOn, DateTime.utc(2026, 4, 3));
      expect([for (final g in await ds.findAll(scope: self)) g.id.value], ['s1']);
    });

    test('refuses another account\'s person and a closed profile', () async {
      await expectLater(ds.put(const GrowthEntryId.value('x'), entry('x', now), scope: otherSelf),
          throwsA(isA<StorageWriteException>()));
      await expectLater(ds.put(const GrowthEntryId.value('y'), entry('y', now), scope: closed),
          throwsA(isA<StorageWriteException>()));
      active = null;
      await expectLater(
          ds.put(const GrowthEntryId.value('z'), entry('z', now)), throwsA(isA<NoActiveProfileException>()));
    });

    test('delete is soft and watchAll follows every change', () async {
      final seen = <List<String>>[];
      final sub = ds.watchAll().listen((l) => seen.add([for (final g in l) g.id.value]));
      await pumpEventQueue();
      await ds.put(const GrowthEntryId.value('w1'), entry('w1', DateTime(2026, 10, 1)));
      await pumpEventQueue();
      await ds.delete(const GrowthEntryId.value('w1'));
      await pumpEventQueue();
      await sub.cancel();

      expect(seen, [
        <String>[],
        ['w1'],
        <String>[],
      ]);
      final raw = await db.customSelect("SELECT deleted_at FROM growth_entry WHERE id = 'w1'").getSingle();
      expect(raw.read<int>('deleted_at'), DateTime.utc(2026, 11, 3).millisecondsSinceEpoch);
    });

    test('RecordGrowthEntryUseCase validates, then logs under the person', () async {
      final use = RecordGrowthEntryUseCase(ds);
      expect((await use(measuredOn: now, weightKg: null, heightCm: null, now: now)).error, isA<ValidationFailure>());
      final ok = await use(measuredOn: now, weightKg: 11.2, heightCm: null, now: now, profileId: child);
      expect(ok.isSuccess, isTrue);
      expect((await ds.findAll(scope: child)).single.weightKg, 11.2);
      final refused = await use(measuredOn: now, weightKg: 11.2, heightCm: null, now: now, profileId: closed);
      expect(refused.error, isA<StorageFailure>());
    });
  });
}
