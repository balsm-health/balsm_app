import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Helpers for the app-upgrade tests: reading a database's schema as data,
/// writing it out as a frozen release fixture, and filling a fixture with
/// synthetic rows.
///
/// Every value written here is synthetic (`fx-<table>-<column>-<n>`, small
/// integers). Nothing resembles a real patient record.

/// A bare connection to a database file: no schema, no migrations, nothing
/// of today's [AppDatabase]. Used to fill an old-version database the way
/// the old build would have left it.
class RawDatabase extends GeneratedDatabase {
  RawDatabase(File file) : super(NativeDatabase(file));

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  // Matches the fixture's own `PRAGMA user_version`, so drift sees nothing to
  // create or upgrade and leaves the file as the old build wrote it.
  @override
  int get schemaVersion => 1;
}

/// Directory holding one `<version>.sql` per shipped release.
final Directory dbFixturesDir = Directory('test/upgrade/fixtures/db');

/// The schema of [db] as executable SQL, in a stable order: tables, then
/// indexes, then triggers, each by name. Internal `sqlite_%` objects and
/// auto-indexes (which have no SQL) are left out.
Future<String> dumpSchemaSql(DatabaseConnectionUser db) async {
  final rows = await db.customSelect('''
    SELECT type, name, sql FROM sqlite_master
    WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'
    ORDER BY CASE type WHEN 'table' THEN 0 WHEN 'index' THEN 1 ELSE 2 END, name''').get();
  final version = (await db.customSelect('PRAGMA user_version').get()).single.read<int>('user_version');
  return [
    ...rows.map((r) => '${r.read<String>('sql').trim()};'),
    'PRAGMA user_version = $version;',
  ].join('\n\n');
}

/// One column as `PRAGMA table_info` reports it.
class ColumnShape {
  const ColumnShape({
    required this.name,
    required this.type,
    required this.notNull,
    required this.defaultValue,
    required this.primaryKey,
  });

  final String name;
  final String type;
  final bool notNull;
  final String? defaultValue;
  final bool primaryKey;

  /// A row an older build inserts without naming this column still succeeds.
  bool get optionalOnInsert => !notNull || defaultValue != null || primaryKey;

  @override
  String toString() => '$name $type${notNull ? ' NOT NULL' : ''}'
      '${defaultValue == null ? '' : ' DEFAULT $defaultValue'}${primaryKey ? ' PK' : ''}';

  @override
  bool operator ==(Object other) => other is ColumnShape && other.toString() == toString();

  @override
  int get hashCode => toString().hashCode;
}

/// Tables (with their columns), indexes and triggers of one database.
class SchemaShape {
  const SchemaShape({required this.tables, required this.indexes, required this.triggers});

  /// table → column name → shape.
  final Map<String, Map<String, ColumnShape>> tables;

  /// index name → `table(col, …)`, with `UNIQUE` when it is.
  final Map<String, String> indexes;

  final Set<String> triggers;
}

Future<SchemaShape> readShape(DatabaseConnectionUser db) async {
  final objects =
      await db.customSelect("SELECT type, name, tbl_name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'").get();
  final tables = <String, Map<String, ColumnShape>>{};
  final indexes = <String, String>{};
  final triggers = <String>{};
  for (final o in objects) {
    final type = o.read<String>('type');
    final name = o.read<String>('name');
    switch (type) {
      case 'table':
        final cols = await db.customSelect('PRAGMA table_info("$name")').get();
        tables[name] = {
          for (final c in cols)
            c.read<String>('name'): ColumnShape(
              name: c.read<String>('name'),
              type: c.read<String>('type').toUpperCase(),
              notNull: c.read<int>('notnull') == 1,
              defaultValue: c.readNullable<String>('dflt_value'),
              primaryKey: c.read<int>('pk') > 0,
            ),
        };
      case 'index':
        final list = await db.customSelect('PRAGMA index_list("${o.read<String>('tbl_name')}")').get();
        final unique = list.any((r) => r.read<String>('name') == name && r.read<int>('unique') == 1);
        final cols = await db.customSelect('PRAGMA index_info("$name")').get();
        indexes[name] = '${unique ? 'UNIQUE ' : ''}${o.read<String>('tbl_name')}'
            '(${cols.map((c) => c.readNullable<String>('name')).join(', ')})';
      case 'trigger':
        triggers.add(name);
    }
  }
  return SchemaShape(tables: tables, indexes: indexes, triggers: triggers);
}

/// Inserts [rowsPerTable] synthetic rows into every table, parents before
/// children so foreign keys hold. Returns what was written, per table, as
/// rows of column → value, for comparing after the upgrade.
Future<Map<String, List<Map<String, Object?>>>> seedSynthetic(
  DatabaseConnectionUser db, {
  int rowsPerTable = 3,
}) async {
  final shape = await readShape(db);
  final fks = <String, Map<String, ({String table, String column})>>{};
  for (final table in shape.tables.keys) {
    final list = await db.customSelect('PRAGMA foreign_key_list("$table")').get();
    fks[table] = {
      for (final f in list) f.read<String>('from'): (table: f.read<String>('table'), column: f.read<String>('to')),
    };
  }

  // Parents first. The schema has no cycles; a table whose parent is not in
  // the fixture is seeded anyway (the parent cannot be checked, so neither is
  // the key).
  final order = <String>[];
  void visit(String t, Set<String> path) {
    if (order.contains(t) || path.contains(t)) return;
    for (final p in fks[t]!.values) {
      if (p.table != t && shape.tables.containsKey(p.table)) visit(p.table, {...path, t});
    }
    order.add(t);
  }

  for (final t in shape.tables.keys.toList()..sort()) {
    visit(t, {});
  }

  final written = <String, List<Map<String, Object?>>>{};
  for (final table in order) {
    final rows = <Map<String, Object?>>[];
    for (var i = 0; i < rowsPerTable; i++) {
      final row = <String, Object?>{};
      for (final col in shape.tables[table]!.values) {
        final parent = fks[table]![col.name];
        row[col.name] = parent != null && written.containsKey(parent.table)
            ? written[parent.table]![i][parent.column]
            : _syntheticValue(table, col, i);
      }
      final names = row.keys.map((k) => '"$k"').join(', ');
      final marks = List.filled(row.length, '?').join(', ');
      await db.customStatement('INSERT INTO "$table" ($names) VALUES ($marks)', row.values.toList());
      rows.add(row);
    }
    written[table] = rows;
  }
  return written;
}

Object _syntheticValue(String table, ColumnShape col, int i) {
  final t = col.type;
  if (t.contains('INT')) return i + 1;
  if (t.contains('REAL') || t.contains('FLOA') || t.contains('DOUB')) return i + 0.5;
  return 'fx-$table-${col.name}-$i';
}
