import 'dart:io';

import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Multi-profile storage foundation: `is_self` resolution, the one-time
/// backfill on an existing v1 database, and the active-profile selection.
/// All data here is synthetic.
void main() {
  const u1 = UserId.value('u1');
  const u2 = UserId.value('u2');

  Future<List<String>> rows(AppDatabase db, String sql) async =>
      (await db.customSelect(sql).get()).map((r) => r.data.values.map((v) => '$v').join('|')).toList();

  Future<void> addDependent(AppDatabase db, String id, UserId user, {String status = 'active'}) => db.customStatement(
        "INSERT INTO health_profile (id, user_id, is_self, kind, status, updated_at) VALUES (?, ?, 0, 'dependent', ?, 0)",
        [id, user.value, status],
      );

  group('existing v1 database', () {
    late File file;

    setUp(() async {
      final dir = await Directory.systemTemp.createTemp('balsm_v1_profiles');
      addTearDown(() => dir.delete(recursive: true));
      file = File('${dir.path}/v1.db');
      // The v1 shapes, before profiles were per person: no is_self/kind/…,
      // prescriptions keyed by user only, and NULL anchors waiting on backfill.
      final seed = sqlite3.open(file.path);
      seed.execute('CREATE TABLE health_profile (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, blood_type TEXT, '
          'weight_kg REAL, height_cm REAL, updated_at TEXT NOT NULL)');
      seed.execute("INSERT INTO health_profile (id, user_id, updated_at) VALUES ('hp-u1', 'u1', 1), "
          "('hp-u1-dup', 'u1', 2), ('hp-u2', 'u2', 3)");
      seed.execute('CREATE TABLE prescription (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, clinician TEXT NOT NULL, '
          'specialty TEXT, reference TEXT, items TEXT NOT NULL, issued_at TEXT NOT NULL, valid_until TEXT, '
          'created_at TEXT NOT NULL)');
      seed.execute("INSERT INTO prescription (id, user_id, clinician, items, issued_at, created_at) "
          "VALUES ('rx1', 'u1', 'Test Clinician', '[]', 't', 't')");
      seed.execute('CREATE TABLE health_record (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, health_profile_id TEXT, '
          'type TEXT NOT NULL, title TEXT NOT NULL, tags TEXT NOT NULL, source TEXT NOT NULL, file_type TEXT, '
          'file_path TEXT, pages INTEGER, result_note TEXT, taken_at TEXT NOT NULL, created_at TEXT NOT NULL)');
      seed.execute("INSERT INTO health_record (id, user_id, type, title, tags, source, taken_at, created_at) "
          "VALUES ('r1', 'u2', 'lab', 'Test record', '[]', 'self', 't', 't')");
      seed.dispose();
    });

    test('gains the member columns; each account\'s earliest row becomes its self', () async {
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      final cols =
          (await db.customSelect('PRAGMA table_info(health_profile)').get()).map((r) => r.read<String>('name')).toSet();
      expect(
          cols,
          containsAll([
            'is_self', 'kind', 'display_name', 'date_of_birth', 'sex', 'relationship', 'group_id', //
            'tone', 'status', 'closed_on', 'pregnancy_id', 'sequence',
          ]));
      expect(await rows(db, 'SELECT id, is_self, kind, status FROM health_profile ORDER BY id'), [
        'hp-u1|1|self|active',
        'hp-u1-dup|0|dependent|active',
        'hp-u2|1|self|active',
      ]);
      // Existing rows anchor to their account's SELF profile, prescriptions included.
      expect(await rows(db, 'SELECT health_profile_id FROM prescription'), ['hp-u1']);
      expect(await rows(db, 'SELECT health_profile_id FROM health_record'), ['hp-u2']);
      expect(await db.ensureSelfHealthProfile(u1), const HealthProfileId.value('hp-u1'));
    });

    test('the patch is idempotent: later opens never promote a dependent', () async {
      final first = AppDatabase(NativeDatabase(file));
      await addDependent(first, 'hp-kid', u2);
      await first.close();

      for (var i = 0; i < 2; i++) {
        final again = AppDatabase(NativeDatabase(file));
        expect(await rows(again, 'SELECT id, is_self, kind FROM health_profile ORDER BY id'), [
          'hp-kid|0|dependent',
          'hp-u1|1|self',
          'hp-u1-dup|0|dependent',
          'hp-u2|1|self',
        ]);
        await again.close();
      }
    });
  });

  group('self resolution', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a dependent created before self is never taken for the account holder', () async {
      await addDependent(db, 'hp-kid', u1);

      final self = await db.ensureSelfHealthProfile(u1);

      expect(self, isNot(const HealthProfileId.value('hp-kid')));
      expect(await rows(db, "SELECT is_self, kind FROM health_profile WHERE id = '${self.value}'"), ['1|self']);
      expect(await db.ensureSelfHealthProfile(u1), self);
      expect(await db.selfHealthProfileId(u1), self);
    });

    test('NULL anchors go to self even with several profiles', () async {
      await addDependent(db, 'hp-kid', u1);
      final self = await db.ensureSelfHealthProfile(u1);
      await db.customStatement("INSERT INTO prescription (id, user_id, clinician, items, issued_at, created_at) "
          "VALUES ('rx1', 'u1', 'Test Clinician', '[]', 't', 't')");

      await db.runProfileAnchorBackfill();

      expect(await rows(db, 'SELECT health_profile_id FROM prescription'), [self.value]);
    });

    test('the Mother & Child tables exist and are soft-delete', () async {
      for (final t in ['member_group', 'vaccination_record', 'growth_entry', 'pregnancy', 'pregnancy_item']) {
        final cols = (await db.customSelect('PRAGMA table_info($t)').get()).map((r) => r.read<String>('name'));
        expect(cols, contains('deleted_at'), reason: t);
      }
      final link =
          (await db.customSelect('PRAGMA table_info(pregnancy_item_baby)').get()).map((r) => r.read<String>('name'));
      expect(link, containsAll(['item_id', 'health_profile_id', 'deleted_at']));
    });
  });

  group('active profile', () {
    late AppDatabase db;
    late HealthProfileId self;
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      self = await db.ensureSelfHealthProfile(u1);
      await addDependent(db, 'hp-kid', u1);
    });
    tearDown(() => db.close());

    test('defaults to self', () async {
      expect(await db.resolveActiveHealthProfile(u1), self);
    });

    test('follows a selection, and clearing it returns to self', () async {
      expect(await db.setActiveHealthProfile(u1, const HealthProfileId.value('hp-kid')), isTrue);
      expect(await db.resolveActiveHealthProfile(u1), const HealthProfileId.value('hp-kid'));

      await db.setActiveHealthProfile(u1, null);

      expect(await db.resolveActiveHealthProfile(u1), self);
    });

    test('a selection that is later closed falls back to self', () async {
      await db.setActiveHealthProfile(u1, const HealthProfileId.value('hp-kid'));

      await db.customStatement("UPDATE health_profile SET status = 'closed' WHERE id = 'hp-kid'");

      expect(await db.resolveActiveHealthProfile(u1), self);
    });

    test('a selection whose profile is gone falls back to self', () async {
      await db.setActiveHealthProfile(u1, const HealthProfileId.value('hp-kid'));

      await db.customStatement("DELETE FROM health_profile WHERE id = 'hp-kid'");

      expect(await db.resolveActiveHealthProfile(u1), self);
    });

    test('refuses a closed profile or another account\'s profile', () async {
      await addDependent(db, 'hp-closed', u1, status: 'closed');
      final other = await db.ensureSelfHealthProfile(u2);

      expect(await db.setActiveHealthProfile(u1, const HealthProfileId.value('hp-closed')), isFalse);
      expect(await db.setActiveHealthProfile(u1, other), isFalse);
      expect(await db.resolveActiveHealthProfile(u1), self);
    });

    test('is per account', () async {
      final other = await db.ensureSelfHealthProfile(u2);
      await db.setActiveHealthProfile(u1, const HealthProfileId.value('hp-kid'));

      expect(await db.resolveActiveHealthProfile(u2), other);
    });
  });

  group('providers', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    ProviderContainer container({UserId? user = u1}) {
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue(user),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('currentProfileIdProvider follows the switcher and the choice persists', () async {
      final c = container();
      c.listen(currentProfileIdProvider, (_, __) {});
      final self = await c.read(activeProfileProvider.future);
      expect(c.read(currentProfileIdProvider), self);
      await addDependent(db, 'hp-kid', u1);

      expect(await c.read(activeProfileSwitcherProvider).select(const HealthProfileId.value('hp-kid')), isTrue);
      await c.read(activeProfileProvider.future);

      expect(c.read(currentProfileIdProvider), const HealthProfileId.value('hp-kid'));
      expect(await c.read(selfProfileIdProvider.future), self);
      // A fresh session on the same device resumes the selection.
      expect(await container().read(activeProfileProvider.future), const HealthProfileId.value('hp-kid'));

      await c.read(activeProfileSwitcherProvider).selectSelf();
      expect(await c.read(activeProfileProvider.future), self);
    });

    test('refresh falls back to self once the selection is closed', () async {
      final c = container();
      final self = await c.read(activeProfileProvider.future);
      await addDependent(db, 'hp-kid', u1);
      await c.read(activeProfileSwitcherProvider).select(const HealthProfileId.value('hp-kid'));
      await db.customStatement("UPDATE health_profile SET status = 'closed' WHERE id = 'hp-kid'");

      c.read(activeProfileSwitcherProvider).refresh();

      expect(await c.read(activeProfileProvider.future), self);
    });

    test('signed out: no active profile, and select is refused', () async {
      final c = container(user: null);
      expect(await c.read(activeProfileProvider.future), isNull);
      expect(await c.read(activeProfileSwitcherProvider).select(const HealthProfileId.value('hp-kid')), isFalse);
    });
  });
}
