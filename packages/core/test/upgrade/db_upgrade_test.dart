import 'dart:io';

import 'package:core/core.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'schema_snapshot.dart';

/// App-update tests for the on-device database.
///
/// Each fixture in `fixtures/db/` is the schema a shipped version left on
/// patients' phones. For every one, the test builds that database, fills each
/// table with synthetic rows, opens it with today's [AppDatabase] — exactly
/// what the first launch after a store update does — and checks:
///
/// - **No crash**: opening (which runs every schema patch in `beforeOpen`)
///   succeeds, twice in a row.
/// - **No data loss**: every table still exists and holds every row it had,
///   with every value unchanged.
/// - **No drift**: the upgraded schema is the one a fresh install gets — no
///   column, index or trigger that new code relies on is missing on an
///   upgraded phone, and no leftover column would make new inserts fail.
/// - **Integrity**: `integrity_check` passes and no foreign key dangles.
///
/// Add a fixture whenever a version ships (see freeze_db_schema_test.dart).
void main() {
  final fixtures = dbFixturesDir.listSync().whereType<File>().where((f) => f.path.endsWith('.sql')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('at least one shipped schema is frozen', () => expect(fixtures, isNotEmpty));

  late SchemaShape fresh;
  setUpAll(() async {
    final db = AppDatabase(NativeDatabase.memory());
    fresh = await readShape(db);
    await db.close();
  });

  for (final fixture in fixtures) {
    final version = fixture.uri.pathSegments.last.replaceAll('.sql', '');

    group('updating from $version', () {
      late Directory dir;
      late File file;
      late Map<String, List<Map<String, Object?>>> seeded;

      setUp(() async {
        dir = await Directory.systemTemp.createTemp('balsm_upgrade_$version');
        file = File('${dir.path}/balsm.db');
        // The old build's database, created and filled by plain SQLite so
        // none of today's code touches it before the "update".
        final raw = sqlite3.open(file.path);
        raw.execute(fixture.readAsStringSync());
        raw.dispose();
        final seeder = RawDatabase(file);
        seeded = await seedSynthetic(seeder);
        await seeder.close();
      });

      tearDown(() => dir.delete(recursive: true));

      Future<AppDatabase> openUpdated() async {
        final db = AppDatabase(NativeDatabase(file));
        await db.customSelect('SELECT 1').get(); // runs beforeOpen
        return db;
      }

      test('opens with the current app without crashing, twice', () async {
        final first = await openUpdated();
        await first.close();
        final second = await openUpdated();
        await second.close();
      });

      test('keeps every table, row and value', () async {
        final db = await openUpdated();
        addTearDown(db.close);
        final after = await readShape(db);
        for (final MapEntry(key: table, value: rows) in seeded.entries) {
          expect(after.tables, contains(table), reason: '$table was dropped by the update');
          final cols = rows.first.keys.map((c) => '"$c"').join(', ');
          final stored = await db.customSelect('SELECT $cols FROM "$table"').get();
          expect(stored.length, rows.length, reason: '$table lost or gained rows in the update');
          String key(Map<String, Object?> r) => rows.first.keys.map((c) => '$c=${r[c]}').join('|');
          expect(
            stored.map((r) => key(r.data)).toList()..sort(),
            rows.map(key).toList()..sort(),
            reason: 'values in $table changed in the update',
          );
        }
      });

      test('ends with the same schema as a fresh install', () async {
        final db = await openUpdated();
        addTearDown(db.close);
        expect(schemaDrift(fresh: fresh, updated: await readShape(db)), isEmpty);
      });

      test('passes integrity and foreign-key checks', () async {
        final db = await openUpdated();
        addTearDown(db.close);
        final integrity = await db.customSelect('PRAGMA integrity_check').get();
        expect(integrity.single.read<String>('integrity_check'), 'ok');
        expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      });
    });
  }

  group('schemaDrift', () {
    ColumnShape col(String name, {bool notNull = false, String? dflt}) =>
        ColumnShape(name: name, type: 'TEXT', notNull: notNull, defaultValue: dflt, primaryKey: false);
    SchemaShape shape(Map<String, Map<String, ColumnShape>> tables,
            {Map<String, String> indexes = const {}, Set<String> triggers = const {}}) =>
        SchemaShape(tables: tables, indexes: indexes, triggers: triggers);

    test('a column only a fresh install has is reported', () {
      final drift = schemaDrift(
        fresh: shape({
          't': {'a': col('a'), 'b': col('b')}
        }),
        updated: shape({
          't': {'a': col('a')}
        }),
      );
      expect(drift.single, contains('t.b'));
    });

    test('a leftover required column with no default is reported; a nullable one is not', () {
      expect(
        schemaDrift(
          fresh: shape({
            't': {'a': col('a')}
          }),
          updated: shape({
            't': {'a': col('a'), 'old': col('old', notNull: true)}
          }),
        ).single,
        contains('t.old'),
      );
      expect(
        schemaDrift(
          fresh: shape({
            't': {'a': col('a')}
          }),
          updated: shape({
            't': {'a': col('a'), 'old': col('old')}
          }),
        ),
        isEmpty,
      );
    });

    test('missing tables, changed columns, indexes and triggers are reported', () {
      final drift = schemaDrift(
        fresh: shape({
          't': {'a': col('a', notNull: true)},
          'u': {}
        }, indexes: {
          'i': 't(a)'
        }, triggers: {
          'g'
        }),
        updated: shape({
          't': {'a': col('a')}
        }),
      );
      expect(drift, hasLength(4));
    });
  });
}

/// Every way an updated database differs from a fresh install, in words.
List<String> schemaDrift({required SchemaShape fresh, required SchemaShape updated}) {
  final out = <String>[];
  for (final MapEntry(key: table, value: cols) in fresh.tables.entries) {
    final had = updated.tables[table];
    if (had == null) {
      out.add('table $table is missing after the update');
      continue;
    }
    for (final c in cols.values) {
      final u = had[c.name];
      if (u == null) {
        out.add('$table.${c.name} is missing after the update (fresh install: $c)');
      } else if (u != c) {
        out.add('$table.${c.name} differs: updated "$u", fresh install "$c"');
      }
    }
    for (final u in had.values) {
      if (!cols.containsKey(u.name) && !u.optionalOnInsert) {
        out.add('$table.${u.name} is left over from an older version as "$u": '
            'inserts from the current app would fail');
      }
    }
  }
  for (final MapEntry(key: name, value: def) in fresh.indexes.entries) {
    final u = updated.indexes[name];
    if (u != def) out.add('index $name: updated ${u ?? 'missing'}, fresh install $def');
  }
  for (final t in fresh.triggers.difference(updated.triggers)) {
    out.add('trigger $t is missing after the update');
  }
  return out;
}
