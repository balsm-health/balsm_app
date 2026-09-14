# Flutter Local-Database Benchmark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone Flutter app that runs an identical CRUD workload across seven local-DB engines, on six platforms, plaintext + encrypted, and emits comparable timing numbers.

**Architecture:** One `BenchDb` interface; one adapter per engine; a platform-aware `Registry` picks available engines; a `Runner` orchestrates `engines × ops × {plain,encrypted} × iterations` with warmup + median/min timing; a `Report` writes console/JSON/CSV/markdown. Every engine adapter must pass one shared conformance test suite before its numbers count.

**Tech Stack:** Flutter (app, not CLI — native libs + web require it), Dart 3, drift, sqflite, floor, objectbox, isar, hive_ce, sembast, build_runner.

## Global Constraints

- Repo is standalone at `~/Dev/Balsm/db_benchmark`; it is NOT a dependency of `balsm_app`.
- Fixed record shape everywhere: `id` (text PK), `indexedInt` (int, indexed), `text` (string), `value` (double), `flag` (bool), `createdAt` (int epoch ms).
- Row counts (from the SQLite/PowerSync suite): single-insert 1,000; bulk-insert 25,000; readAll/queryIndexed/updateAll/deleteAll operate over a 25,000-row baseline.
- Deterministic data: seeded `Random(42)`; identical dataset per engine per iteration.
- Timing: wall-clock `Stopwatch` around async APIs; ≥3 iterations; report **median + min**; one discarded warmup per (engine, op, crypto).
- Release mode only for real numbers; runner prints a loud warning under `kDebugMode`.
- Cells that do not run carry a reason string (`N/A (encryption unsupported)`, `skipped (platform)`) — never a blank or a zero.
- `queryIndexed` = `WHERE indexedInt > threshold` for SQL engines; documented Dart-side filter for KV engines (Hive, sembast).
- Commit after every task. Conventional Commits. No push unless asked.
- Project root is the ABSOLUTE path `/Volumes/Dev/Balsm/db_benchmark` (the plan's earlier `~/Dev/Balsm` was wrong — that dir does not exist).

---

## REVISION 2026-07-04 — "Force all 7" via sidecar codegen

Task 1 outcome: 5/7 engines resolve on Flutter 3.41 (drift, sqflite, objectbox, hive_ce, sembast). **Isar and Floor cannot coexist with `drift_dev` in one pubspec** — their generators pin old `analyzer`/`source_gen` (Isar: `analyzer <6`; Floor: `source_gen ^1.5`) while `drift_dev` needs `analyzer 7` / `source_gen >=3`. Both are unmaintained. Decision: include all 7 anyway via **sidecar codegen**.

**Sidecar approach (applies to Tasks 6 Floor and 8 Isar — those tasks are SUPERSEDED by this pattern):**
- The generator conflict is build-time only. Runtime `isar`/`floor` packages do NOT depend on analyzer/source_gen.
- Create an isolated package per engine: `codegen/floor_gen/` and `codegen/isar_gen/`, each with its OWN pubspec pinning the engine + its generator + `build_runner` (old analyzer/source_gen — isolated, never resolved against the app).
- Each sidecar holds the SAME source file as the app (identical entity/DAO/DB classes + `part '..._engine.g.dart';`). Run `build_runner` in the sidecar to produce the `.g.dart`, then copy BOTH the source and the generated `.g.dart` into the app's `lib/engines/`.
- The app pubspec adds RUNTIME-ONLY deps: `isar` + `isar_flutter_libs`, `floor` + `floor_annotation` (NOT `isar_generator` / `floor_generator`). The committed `.g.dart` compiles against these.
- **Feasibility gate (do this first for each sidecar):** confirm the runtime-only deps resolve in the app pubspec (`flutter pub get` green) alongside the other engines BEFORE building the adapter. If runtime `floor` forces an `sqflite` version that conflicts with `sqflite_sqlcipher 3.4`, or runtime `isar` won't resolve, that engine is genuinely un-includable → report BLOCKED with the exact solve error; do not thrash.
- `supportsEncryption()` stays `false` for both (Floor via-sqflite encryption is out of scope for the sidecar; Isar OSS has no key) → encrypted cells are `N/A`, exercised by the runner.

Also correct from Task 1: `hive_ce_generator` is `^1.0.0` (resolves 1.9.3); `^2.0.0` does not exist.

---

### Task 1: Scaffold project + dependencies

**Files:**
- Create: `~/Dev/Balsm/db_benchmark/` (Flutter app)
- Modify: `pubspec.yaml`
- Create: `lib/main.dart` (temporary placeholder, replaced in Task 14)

**Interfaces:**
- Produces: a compiling Flutter app with all engine deps resolved; `flutter analyze` clean.

- [ ] **Step 1: Create the project**

```bash
cd ~/Dev/Balsm
flutter create --org com.balsm --platforms=android,ios,web,macos,linux,windows db_benchmark
cd db_benchmark
git init
```

- [ ] **Step 2: Write `pubspec.yaml` dependencies**

Replace the `dependencies:` / `dev_dependencies:` blocks with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # sqlite family
  drift: ^2.29.0
  sqlite3_flutter_libs: ^0.5.0
  sqlcipher_flutter_libs: ^0.6.0
  sqflite: ^2.3.0
  sqflite_common_ffi: ^2.3.0
  sqflite_sqlcipher: ^3.1.0
  floor: ^1.5.0
  # nosql
  objectbox: ^4.0.0
  objectbox_flutter_libs: ^4.0.0
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1
  # key-value
  hive_ce: ^2.7.0
  hive_ce_flutter: ^2.1.0
  sembast: ^3.7.0
  sembast_web: ^2.4.0
  # util
  path_provider: ^2.1.0
  path: ^1.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.13
  drift_dev: ^2.29.0
  floor_generator: ^1.5.0
  objectbox_generator: ^4.0.0
  isar_generator: ^3.1.0+1
  hive_ce_generator: ^2.0.0
```

- [ ] **Step 3: Resolve and verify**

Run: `flutter pub get`
Expected: resolves without version-solve errors. If `isar` fails to resolve on the current SDK, pin `isar`/`isar_flutter_libs`/`isar_generator` to the latest matching triple and note it in `README.md`; do not spend more than one attempt — Isar carries a documented maintenance risk.

- [ ] **Step 4: Create folder skeleton + placeholder main**

```bash
mkdir -p lib/engines results
```

`lib/main.dart`:

```dart
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('bench')))));
```

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze`
Expected: `No issues found!`

```bash
git add -A
git commit -m "chore: scaffold db_benchmark flutter app with engine deps"
```

---

### Task 2: Core model, ops enum, result types, data generator

**Files:**
- Create: `lib/bench_db.dart`
- Create: `lib/data_gen.dart`
- Test: `test/data_gen_test.dart`

**Interfaces:**
- Produces:
  - `class BenchRecord { final String id; final int indexedInt; final String text; final double value; final bool flag; final int createdAt; const BenchRecord({...}); BenchRecord copyWith({double? value}); }`
  - `enum BenchOp { insertBulk, insertSingle, readAll, queryIndexed, updateAll, deleteAll }`
  - `abstract class BenchDb` (see body)
  - `class OpResult { final BenchOp op; final bool encrypted; final Duration? median; final Duration? min; final int iterations; final String? skipReason; }`
  - `class EngineResult { final String engine; final List<OpResult> ops; final String? skipReason; }`
  - `List<BenchRecord> generateRecords(int n, {int seed = 42})`
  - `const int kQueryThreshold = 500000;`

- [ ] **Step 1: Write the failing test**

`test/data_gen_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:db_benchmark/data_gen.dart';

void main() {
  test('generateRecords is deterministic for a fixed seed', () {
    final a = generateRecords(1000, seed: 42);
    final b = generateRecords(1000, seed: 42);
    expect(a.length, 1000);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].id, b[i].id);
      expect(a[i].indexedInt, b[i].indexedInt);
      expect(a[i].text, b[i].text);
    }
  });

  test('ids are unique', () {
    final recs = generateRecords(5000);
    expect(recs.map((r) => r.id).toSet().length, 5000);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data_gen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:db_benchmark/data_gen.dart'`.

- [ ] **Step 3: Write `lib/bench_db.dart`**

```dart
class BenchRecord {
  final String id;
  final int indexedInt;
  final String text;
  final double value;
  final bool flag;
  final int createdAt;
  const BenchRecord({
    required this.id,
    required this.indexedInt,
    required this.text,
    required this.value,
    required this.flag,
    required this.createdAt,
  });
  BenchRecord copyWith({double? value}) => BenchRecord(
        id: id,
        indexedInt: indexedInt,
        text: text,
        value: value ?? this.value,
        flag: flag,
        createdAt: createdAt,
      );
}

enum BenchOp { insertBulk, insertSingle, readAll, queryIndexed, updateAll, deleteAll }

/// One adapter per engine. Every method uses the engine's idiomatic API.
abstract class BenchDb {
  String get name;

  /// False → the runner records encrypted ops as `N/A (encryption unsupported)`.
  bool supportsEncryption();

  Future<void> open({required bool encrypted});
  Future<void> clear();
  Future<void> close();

  /// Idiomatic fast path (single transaction / putMany).
  Future<void> insertBulk(List<BenchRecord> records);

  /// Deliberately naive: one commit per record, no batching.
  Future<void> insertSingle(List<BenchRecord> records);

  Future<int> readAll();

  /// SQL: WHERE indexedInt > threshold. KV: Dart-side filter.
  Future<int> queryIndexed(int threshold);

  Future<void> updateAll(List<BenchRecord> records);

  Future<void> deleteAll(List<String> ids);
}

class OpResult {
  final BenchOp op;
  final bool encrypted;
  final Duration? median;
  final Duration? min;
  final int iterations;
  final String? skipReason;
  const OpResult({
    required this.op,
    required this.encrypted,
    this.median,
    this.min,
    this.iterations = 0,
    this.skipReason,
  });
}

class EngineResult {
  final String engine;
  final List<OpResult> ops;
  final String? skipReason;
  const EngineResult({required this.engine, this.ops = const [], this.skipReason});
}
```

- [ ] **Step 4: Write `lib/data_gen.dart`**

```dart
import 'dart:math';
import 'bench_db.dart';

const int kQueryThreshold = 500000;
const _hex = '0123456789abcdef';

List<BenchRecord> generateRecords(int n, {int seed = 42}) {
  final rng = Random(seed);
  return List.generate(n, (i) {
    final id = List.generate(24, (_) => _hex[rng.nextInt(16)]).join();
    final text = List.generate(32, (_) => _hex[rng.nextInt(16)]).join();
    return BenchRecord(
      id: '$id-$i', // suffix guarantees uniqueness even on rng collision
      indexedInt: rng.nextInt(1000000),
      text: text,
      value: rng.nextDouble() * 1000,
      flag: rng.nextBool(),
      createdAt: 1700000000000 + i,
    );
  });
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data_gen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/bench_db.dart lib/data_gen.dart test/data_gen_test.dart
git commit -m "feat: core model, ops enum, result types, seeded data generator"
```

---

### Task 3: Shared engine conformance test suite

The contract every engine must satisfy before its numbers are trusted. Written once, parameterized by a factory; each engine task wires it in.

**Files:**
- Create: `test/engine_conformance.dart`
- Test: `test/fake_engine_test.dart` (proves the suite itself works against an in-memory fake)
- Create (test-only): `test/fake_engine.dart`

**Interfaces:**
- Produces: `void runConformanceTests(String name, BenchDb Function() make, {required bool encryptable, String? rawFilePath(BenchDb db)})`
- Consumes: `BenchDb`, `generateRecords` from Tasks 2.

- [ ] **Step 1: Write the conformance suite `test/engine_conformance.dart`**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:db_benchmark/bench_db.dart';
import 'package:db_benchmark/data_gen.dart';

/// [rawFile] returns the on-disk DB file for the plaintext-leak check, or null
/// if the engine has no single inspectable file (web / mmap dir).
void runConformanceTests(
  String name,
  BenchDb Function() make, {
  required bool encryptable,
  File? Function(BenchDb db)? rawFile,
}) {
  group('$name conformance', () {
    test('round-trip: bulk insert, read, query, delete', () async {
      final db = make();
      await db.open(encrypted: false);
      addTearDown(db.close);
      await db.clear();

      final recs = generateRecords(1000);
      await db.insertBulk(recs);
      expect(await db.readAll(), 1000, reason: 'readAll after bulk insert');

      final expected = recs.where((r) => r.indexedInt > kQueryThreshold).length;
      expect(await db.queryIndexed(kQueryThreshold), expected,
          reason: 'queryIndexed count must match arithmetic truth');

      await db.updateAll(recs.map((r) => r.copyWith(value: 1.0)).toList());
      expect(await db.readAll(), 1000, reason: 'update must not change row count');

      await db.deleteAll(recs.map((r) => r.id).toList());
      expect(await db.readAll(), 0, reason: 'deleteAll empties store');
    });

    test('single-insert path also round-trips', () async {
      final db = make();
      await db.open(encrypted: false);
      addTearDown(db.close);
      await db.clear();
      final recs = generateRecords(100);
      await db.insertSingle(recs);
      expect(await db.readAll(), 100);
    });

    if (encryptable) {
      test('encrypted write does not leave plaintext on disk', () async {
        final db = make();
        expect(db.supportsEncryption(), isTrue);
        await db.open(encrypted: true);
        addTearDown(db.close);
        await db.clear();
        const token = 'PLAINTEXTNEEDLE0123456789ABCDEF0';
        final rec = generateRecords(1).first;
        final tagged = BenchRecord(
          id: rec.id, indexedInt: rec.indexedInt, text: token,
          value: rec.value, flag: rec.flag, createdAt: rec.createdAt);
        await db.insertBulk([tagged]);
        await db.close();
        final f = rawFile?.call(db);
        if (f != null && await f.exists()) {
          final bytes = await f.readAsBytes();
          final haystack = String.fromCharCodes(bytes);
          expect(haystack.contains(token), isFalse,
              reason: 'encrypted DB file must not contain plaintext payload');
        }
      });
    }
  });
}
```

- [ ] **Step 2: Write the in-memory fake `test/fake_engine.dart`**

```dart
import 'package:db_benchmark/bench_db.dart';
import 'package:db_benchmark/data_gen.dart';

class FakeEngine implements BenchDb {
  final _store = <String, BenchRecord>{};
  @override
  String get name => 'fake';
  @override
  bool supportsEncryption() => false;
  @override
  Future<void> open({required bool encrypted}) async {}
  @override
  Future<void> clear() async => _store.clear();
  @override
  Future<void> close() async {}
  @override
  Future<void> insertBulk(List<BenchRecord> records) async {
    for (final r in records) _store[r.id] = r;
  }
  @override
  Future<void> insertSingle(List<BenchRecord> records) => insertBulk(records);
  @override
  Future<int> readAll() async => _store.length;
  @override
  Future<int> queryIndexed(int threshold) async =>
      _store.values.where((r) => r.indexedInt > threshold).length;
  @override
  Future<void> updateAll(List<BenchRecord> records) => insertBulk(records);
  @override
  Future<void> deleteAll(List<String> ids) async {
    for (final id in ids) _store.remove(id);
  }
}
```

- [ ] **Step 3: Wire the suite against the fake `test/fake_engine_test.dart`**

```dart
import 'engine_conformance.dart';
import 'fake_engine.dart';

void main() {
  runConformanceTests('fake', FakeEngine.new, encryptable: false);
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/fake_engine_test.dart`
Expected: PASS (2 tests — round-trip + single-insert; encryption group skipped since `encryptable: false`).

- [ ] **Step 5: Commit**

```bash
git add test/engine_conformance.dart test/fake_engine.dart test/fake_engine_test.dart
git commit -m "test: shared engine conformance suite + in-memory fake"
```

---

### Task 4: drift engine adapter (reference)

**Files:**
- Create: `lib/engines/drift_engine.dart`
- Create (generated): `lib/engines/drift_engine.g.dart` (via build_runner)
- Test: `test/drift_engine_test.dart`

**Interfaces:**
- Consumes: `BenchDb`, `BenchRecord`.
- Produces: `class DriftEngine implements BenchDb` with `File? dbFile`.

- [ ] **Step 1: Write the adapter `lib/engines/drift_engine.dart`**

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import '../bench_db.dart';

part 'drift_engine.g.dart';

class Records extends Table {
  TextColumn get id => text()();
  IntColumn get indexedInt => integer()();
  TextColumn get text => text()();
  RealColumn get value => real()();
  BoolColumn get flag => boolean()();
  IntColumn get createdAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => const [];
}

@DriftDatabase(tables: [Records])
class _Db extends _$_Db {
  _Db(super.e);
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_indexed_int ON records(indexed_int)');
        },
      );
}

class DriftEngine implements BenchDb {
  _Db? _db;
  File? dbFile;

  @override
  String get name => 'drift';
  @override
  bool supportsEncryption() => true;

  @override
  Future<void> open({required bool encrypted}) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'drift_${encrypted ? 'enc' : 'plain'}.db'));
    dbFile = file;
    if (await file.exists()) await file.delete();
    _db = _Db(NativeDatabase(
      file,
      setup: (raw) {
        if (encrypted) {
          open.overrideFor(OperatingSystem.iOS, openCipherOnIOS);
          raw.execute("PRAGMA key = 'bench-key-0123456789';");
        }
      },
    ));
  }

  @override
  Future<void> clear() async => _db!.delete(_db!.records).go();
  @override
  Future<void> close() async => _db?.close();

  @override
  Future<void> insertBulk(List<BenchRecord> records) async {
    await _db!.batch((b) => b.insertAll(_db!.records, records.map(_toRow)));
  }

  @override
  Future<void> insertSingle(List<BenchRecord> records) async {
    for (final r in records) {
      await _db!.into(_db!.records).insert(_toRow(r));
    }
  }

  @override
  Future<int> readAll() async => (await _db!.select(_db!.records).get()).length;

  @override
  Future<int> queryIndexed(int threshold) async {
    final q = _db!.select(_db!.records)..where((t) => t.indexedInt.isBiggerThanValue(threshold));
    return (await q.get()).length;
  }

  @override
  Future<void> updateAll(List<BenchRecord> records) async {
    await _db!.batch((b) {
      for (final r in records) {
        b.replace(_db!.records, _toRow(r));
      }
    });
  }

  @override
  Future<void> deleteAll(List<String> ids) async {
    await (_db!.delete(_db!.records)..where((t) => t.id.isIn(ids))).go();
  }

  RecordsCompanion _toRow(BenchRecord r) => RecordsCompanion.insert(
        id: r.id,
        indexedInt: r.indexedInt,
        text: r.text,
        value: r.value,
        flag: r.flag,
        createdAt: r.createdAt,
      );
}
```

- [ ] **Step 2: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `lib/engines/drift_engine.g.dart`; build succeeds.

- [ ] **Step 3: Write the test `test/drift_engine_test.dart`**

```dart
import 'dart:io';
import 'package:db_benchmark/bench_db.dart';
import 'package:db_benchmark/engines/drift_engine.dart';
import 'engine_conformance.dart';

void main() {
  runConformanceTests(
    'drift',
    DriftEngine.new,
    encryptable: true,
    rawFile: (db) => (db as DriftEngine).dbFile,
  );
}
```

- [ ] **Step 4: Run the conformance suite**

Run: `flutter test test/drift_engine_test.dart`
Expected: PASS (3 tests incl. encryption leak check). If `path_provider` throws in the test host, run this suite as an integration test on macOS: `flutter test integration_test/drift_engine_test.dart -d macos` (mirror the same file under `integration_test/`). Note the chosen host in `README.md`.

- [ ] **Step 5: Commit**

```bash
git add lib/engines/drift_engine.dart lib/engines/drift_engine.g.dart test/drift_engine_test.dart
git commit -m "feat: drift engine adapter (SQLCipher) + conformance"
```

---

### Task 5: sqflite engine adapter

**Files:**
- Create: `lib/engines/sqflite_engine.dart`
- Test: `test/sqflite_engine_test.dart`

**Interfaces:**
- Consumes: `BenchDb`. Produces: `class SqfliteEngine implements BenchDb` with `File? dbFile`.
- Uses `sqflite_sqlcipher` for the encrypted path, `sqflite_common_ffi` factory on desktop/test.

- [ ] **Step 1: Write `lib/engines/sqflite_engine.dart`**

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../bench_db.dart';

class SqfliteEngine implements BenchDb {
  Database? _db;
  File? dbFile;

  @override
  String get name => 'sqflite';
  @override
  bool supportsEncryption() => true;

  @override
  Future<void> open({required bool encrypted}) async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'sqflite_${encrypted ? 'enc' : 'plain'}.db');
    dbFile = File(path);
    if (await dbFile!.exists()) await dbFile!.delete();
    _db = await openDatabase(
      path,
      password: encrypted ? 'bench-key-0123456789' : null,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE records(
            id TEXT PRIMARY KEY, indexedInt INTEGER, text TEXT,
            value REAL, flag INTEGER, createdAt INTEGER)''');
        await db.execute('CREATE INDEX idx_indexed_int ON records(indexedInt)');
      },
    );
  }

  @override
  Future<void> clear() async => _db!.delete('records');
  @override
  Future<void> close() async => _db?.close();

  Map<String, Object?> _row(BenchRecord r) => {
        'id': r.id, 'indexedInt': r.indexedInt, 'text': r.text,
        'value': r.value, 'flag': r.flag ? 1 : 0, 'createdAt': r.createdAt,
      };

  @override
  Future<void> insertBulk(List<BenchRecord> records) async {
    final batch = _db!.batch();
    for (final r in records) {
      batch.insert('records', _row(r), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> insertSingle(List<BenchRecord> records) async {
    for (final r in records) {
      await _db!.insert('records', _row(r), conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  Future<int> readAll() async =>
      Sqflite.firstIntValue(await _db!.rawQuery('SELECT COUNT(*) FROM records')) ?? 0;

  @override
  Future<int> queryIndexed(int threshold) async => Sqflite.firstIntValue(await _db!
          .rawQuery('SELECT COUNT(*) FROM records WHERE indexedInt > ?', [threshold])) ??
      0;

  @override
  Future<void> updateAll(List<BenchRecord> records) async {
    final batch = _db!.batch();
    for (final r in records) {
      batch.update('records', _row(r), where: 'id = ?', whereArgs: [r.id]);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteAll(List<String> ids) async {
    final batch = _db!.batch();
    for (final id in ids) {
      batch.delete('records', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }
}
```

- [ ] **Step 2: Write `test/sqflite_engine_test.dart`**

```dart
import 'package:db_benchmark/engines/sqflite_engine.dart';
import 'engine_conformance.dart';

void main() {
  runConformanceTests(
    'sqflite',
    SqfliteEngine.new,
    encryptable: true,
    rawFile: (db) => (db as SqfliteEngine).dbFile,
  );
}
```

- [ ] **Step 3: Run**

Run: `flutter test integration_test/sqflite_engine_test.dart -d macos` (copy the test file under `integration_test/`; sqflite needs a platform host or ffi factory).
Expected: PASS (3 tests).

- [ ] **Step 4: Commit**

```bash
git add lib/engines/sqflite_engine.dart test/sqflite_engine_test.dart integration_test/sqflite_engine_test.dart
git commit -m "feat: sqflite engine adapter (sqflite_sqlcipher) + conformance"
```

---

### Task 6: floor engine adapter

Floor is annotation codegen over sqflite. Encrypted path uses `sqflite_sqlcipher`'s factory; if the factory override does not take a password cleanly, `supportsEncryption()` returns false and encrypted cells become `N/A` — an honest gap, not a failure.

**Files:**
- Create: `lib/engines/floor_engine.dart`
- Create (generated): `lib/engines/floor_engine.g.dart`
- Test: `test/floor_engine_test.dart`

**Interfaces:**
- Produces: `class FloorEngine implements BenchDb` with `File? dbFile`.

- [ ] **Step 1: Write `lib/engines/floor_engine.dart`**

```dart
import 'dart:async';
import 'dart:io';
import 'package:floor/floor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import '../bench_db.dart';

part 'floor_engine.g.dart';

@Entity(tableName: 'records', indices: [Index(value: ['indexedInt'])])
class RecordRow {
  @primaryKey
  final String id;
  final int indexedInt;
  final String text;
  final double value;
  final int flag;
  final int createdAt;
  RecordRow(this.id, this.indexedInt, this.text, this.value, this.flag, this.createdAt);
}

@dao
abstract class RecordDao {
  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertAll(List<RecordRow> rows);
  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertOne(RecordRow row);
  @Query('SELECT COUNT(*) FROM records')
  Future<int?> count();
  @Query('SELECT COUNT(*) FROM records WHERE indexedInt > :t')
  Future<int?> countAbove(int t);
  @update
  Future<void> updateAll(List<RecordRow> rows);
  @Query('DELETE FROM records')
  Future<void> clearAll();
  @Query('DELETE FROM records WHERE id IN (:ids)')
  Future<void> deleteIds(List<String> ids);
}

@Database(version: 1, entities: [RecordRow])
abstract class FloorDb extends FloorDatabase {
  RecordDao get dao;
}

class FloorEngine implements BenchDb {
  FloorDb? _db;
  File? dbFile;

  @override
  String get name => 'floor';
  @override
  bool supportsEncryption() => false; // see task note; encrypted → N/A

  @override
  Future<void> open({required bool encrypted}) async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'floor_plain.db');
    dbFile = File(path);
    if (await dbFile!.exists()) await dbFile!.delete();
    _db = await $FloorFloorDb.databaseBuilder(path).build();
  }

  RecordRow _row(BenchRecord r) =>
      RecordRow(r.id, r.indexedInt, r.text, r.value, r.flag ? 1 : 0, r.createdAt);

  @override
  Future<void> clear() async => _db!.dao.clearAll();
  @override
  Future<void> close() async => _db?.close();
  @override
  Future<void> insertBulk(List<BenchRecord> records) async =>
      _db!.dao.insertAll(records.map(_row).toList());
  @override
  Future<void> insertSingle(List<BenchRecord> records) async {
    for (final r in records) await _db!.dao.insertOne(_row(r));
  }
  @override
  Future<int> readAll() async => (await _db!.dao.count()) ?? 0;
  @override
  Future<int> queryIndexed(int threshold) async => (await _db!.dao.countAbove(threshold)) ?? 0;
  @override
  Future<void> updateAll(List<BenchRecord> records) async =>
      _db!.dao.updateAll(records.map(_row).toList());
  @override
  Future<void> deleteAll(List<String> ids) async => _db!.dao.deleteIds(ids);
}
```

- [ ] **Step 2: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `lib/engines/floor_engine.g.dart`. If Floor's generated `deleteIds(:ids)` list-binding fails to compile, replace the body with a per-id loop calling a `@Query('DELETE FROM records WHERE id = :id')` method; keep the interface identical.

- [ ] **Step 3: Write `test/floor_engine_test.dart`**

```dart
import 'package:db_benchmark/engines/floor_engine.dart';
import 'engine_conformance.dart';

void main() {
  runConformanceTests('floor', FloorEngine.new, encryptable: false);
}
```

- [ ] **Step 4: Run**

Run: `flutter test integration_test/floor_engine_test.dart -d macos` (copy under `integration_test/`).
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/engines/floor_engine.dart lib/engines/floor_engine.g.dart test/floor_engine_test.dart integration_test/floor_engine_test.dart
git commit -m "feat: floor engine adapter + conformance (encrypted = N/A)"
```

---

### Task 7: objectbox engine adapter

Encryption is a commercial ObjectBox feature → `supportsEncryption()` returns false; encrypted cells are `N/A (commercial)`. No web support — the registry (Task 11) excludes it there.

**Files:**
- Create: `lib/engines/objectbox_engine.dart`
- Create (generated): `objectbox.g.dart`, `objectbox-model.json` (via build_runner)
- Test: `test/objectbox_engine_test.dart`

**Interfaces:**
- Produces: `class ObjectBoxEngine implements BenchDb` with `Directory? storeDir`.

- [ ] **Step 1: Write `lib/engines/objectbox_engine.dart`**

```dart
import 'dart:io';
import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../bench_db.dart';
import '../../objectbox.g.dart';

@Entity()
class ObxRecord {
  @Id(assignable: true)
  int obxId = 0;
  @Index()
  String recId;
  @Index()
  int indexedInt;
  String text;
  double value;
  bool flag;
  int createdAt;
  ObxRecord(this.recId, this.indexedInt, this.text, this.value, this.flag, this.createdAt);
}

class ObjectBoxEngine implements BenchDb {
  Store? _store;
  Directory? storeDir;

  @override
  String get name => 'objectbox';
  @override
  bool supportsEncryption() => false; // commercial feature

  @override
  Future<void> open({required bool encrypted}) async {
    final dir = await getApplicationSupportDirectory();
    storeDir = Directory(p.join(dir.path, 'obx'));
    if (await storeDir!.exists()) await storeDir!.delete(recursive: true);
    await storeDir!.create(recursive: true);
    _store = await openStore(directory: storeDir!.path);
  }

  Box<ObxRecord> get _box => _store!.box<ObxRecord>();

  ObxRecord _row(BenchRecord r) =>
      ObxRecord(r.id, r.indexedInt, r.text, r.value, r.flag, r.createdAt);

  @override
  Future<void> clear() async => _box.removeAll();
  @override
  Future<void> close() async => _store?.close();

  @override
  Future<void> insertBulk(List<BenchRecord> records) async =>
      _box.putManyAsync(records.map(_row).toList());

  @override
  Future<void> insertSingle(List<BenchRecord> records) async {
    for (final r in records) await _box.putAsync(_row(r));
  }

  @override
  Future<int> readAll() async => _box.count();

  @override
  Future<int> queryIndexed(int threshold) async {
    final q = _box.query(ObxRecord_.indexedInt.greaterThan(threshold)).build();
    final n = q.count();
    q.close();
    return n;
  }

  @override
  Future<void> updateAll(List<BenchRecord> records) async {
    // Map recId → obxId to update in place.
    final existing = {for (final o in _box.getAll()) o.recId: o.obxId};
    final rows = records.map((r) {
      final o = _row(r)..value = r.value;
      o.obxId = existing[r.id] ?? 0;
      return o;
    }).toList();
    await _box.putManyAsync(rows);
  }

  @override
  Future<void> deleteAll(List<String> ids) async {
    final idset = ids.toSet();
    final targets = _box.getAll().where((o) => idset.contains(o.recId)).map((o) => o.obxId).toList();
    _box.removeMany(targets);
  }
}
```

- [ ] **Step 2: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `objectbox.g.dart` + `objectbox-model.json` at project root.

- [ ] **Step 3: Write `test/objectbox_engine_test.dart`**

```dart
import 'package:db_benchmark/engines/objectbox_engine.dart';
import 'engine_conformance.dart';

void main() {
  runConformanceTests('objectbox', ObjectBoxEngine.new, encryptable: false);
}
```

- [ ] **Step 4: Run**

Run: `flutter test integration_test/objectbox_engine_test.dart -d macos` (copy under `integration_test/`; ObjectBox needs native libs).
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/engines/objectbox_engine.dart objectbox.g.dart objectbox-model.json test/objectbox_engine_test.dart integration_test/objectbox_engine_test.dart
git commit -m "feat: objectbox engine adapter + conformance (encrypted = N/A commercial)"
```

---

### Task 8: isar engine adapter

Isar carries maintenance risk. Built-in AES encryption exists only in some builds; `supportsEncryption()` returns whether the resolved build exposes `encryptionKey`. If uncertain, return false → encrypted cells `N/A`.

**Files:**
- Create: `lib/engines/isar_engine.dart`
- Create (generated): `lib/engines/isar_engine.g.dart`
- Test: `test/isar_engine_test.dart`

**Interfaces:**
- Produces: `class IsarEngine implements BenchDb` with `Directory? storeDir`.

- [ ] **Step 1: Write `lib/engines/isar_engine.dart`**

```dart
import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../bench_db.dart';

part 'isar_engine.g.dart';

@collection
class IsarRecord {
  Id isarId = Isar.autoIncrement;
  @Index()
  late String recId;
  @Index()
  late int indexedInt;
  late String text;
  late double value;
  late bool flag;
  late int createdAt;
}

class IsarEngine implements BenchDb {
  Isar? _isar;
  Directory? storeDir;

  @override
  String get name => 'isar';
  @override
  bool supportsEncryption() => false; // open-source build has no encryptionKey

  @override
  Future<void> open({required bool encrypted}) async {
    final dir = await getApplicationSupportDirectory();
    storeDir = Directory(p.join(dir.path, 'isar'));
    if (await storeDir!.exists()) await storeDir!.delete(recursive: true);
    await storeDir!.create(recursive: true);
    _isar = await Isar.open([IsarRecordSchema], directory: storeDir!.path);
  }

  IsarRecord _row(BenchRecord r) => IsarRecord()
    ..recId = r.id
    ..indexedInt = r.indexedInt
    ..text = r.text
    ..value = r.value
    ..flag = r.flag
    ..createdAt = r.createdAt;

  @override
  Future<void> clear() async => _isar!.writeTxn(() => _isar!.clear());
  @override
  Future<void> close() async => _isar?.close();

  @override
  Future<void> insertBulk(List<BenchRecord> records) async =>
      _isar!.writeTxn(() => _isar!.isarRecords.putAll(records.map(_row).toList()));

  @override
  Future<void> insertSingle(List<BenchRecord> records) async {
    for (final r in records) {
      await _isar!.writeTxn(() => _isar!.isarRecords.put(_row(r)));
    }
  }

  @override
  Future<int> readAll() async => _isar!.isarRecords.count();

  @override
  Future<int> queryIndexed(int threshold) async =>
      _isar!.isarRecords.filter().indexedIntGreaterThan(threshold).count();

  @override
  Future<void> updateAll(List<BenchRecord> records) async {
    final byRec = {for (final o in await _isar!.isarRecords.where().findAll()) o.recId: o.isarId};
    final rows = records.map((r) => _row(r)..isarId = byRec[r.id] ?? Isar.autoIncrement).toList();
    await _isar!.writeTxn(() => _isar!.isarRecords.putAll(rows));
  }

  @override
  Future<void> deleteAll(List<String> ids) async {
    final idset = ids.toSet();
    final targets = (await _isar!.isarRecords.where().findAll())
        .where((o) => idset.contains(o.recId))
        .map((o) => o.isarId)
        .toList();
    await _isar!.writeTxn(() => _isar!.isarRecords.deleteAll(targets));
  }
}
```

- [ ] **Step 2: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `lib/engines/isar_engine.g.dart`.

- [ ] **Step 3: Write `test/isar_engine_test.dart`**

```dart
import 'package:db_benchmark/engines/isar_engine.dart';
import 'engine_conformance.dart';

void main() {
  runConformanceTests('isar', IsarEngine.new, encryptable: false);
}
```

- [ ] **Step 4: Run**

Run: `flutter test integration_test/isar_engine_test.dart -d macos` (copy under `integration_test/`; Isar needs native libs; `await Isar.initializeIsarCore(download: true)` may be required in a `setUpAll` on desktop test hosts).
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/engines/isar_engine.dart lib/engines/isar_engine.g.dart test/isar_engine_test.dart integration_test/isar_engine_test.dart
git commit -m "feat: isar engine adapter + conformance (encrypted = N/A)"
```

---

### Task 9: hive engine adapter (Hive CE)

Key-value store: no indexed query. `queryIndexed` loads the box and filters in Dart — the documented KV cost. Encryption via `HiveAesCipher`.

**Files:**
- Create: `lib/engines/hive_engine.dart`
- Create (generated): `lib/engines/hive_engine.g.dart`
- Test: `test/hive_engine_test.dart`

**Interfaces:**
- Produces: `class HiveEngine implements BenchDb` with `File? dbFile`.

- [ ] **Step 1: Write `lib/engines/hive_engine.dart`**

```dart
import 'dart:io';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../bench_db.dart';

part 'hive_engine.g.dart';

@HiveType(typeId: 1)
class HiveRecord {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final int indexedInt;
  @HiveField(2)
  final String text;
  @HiveField(3)
  final double value;
  @HiveField(4)
  final bool flag;
  @HiveField(5)
  final int createdAt;
  HiveRecord(this.id, this.indexedInt, this.text, this.value, this.flag, this.createdAt);
}

class HiveEngine implements BenchDb {
  Box<HiveRecord>? _box;
  File? dbFile;
  static bool _registered = false;

  @override
  String get name => 'hive';
  @override
  bool supportsEncryption() => true;

  static final _aesKey = List<int>.filled(32, 7); // fixed 256-bit key

  @override
  Future<void> open({required bool encrypted}) async {
    final dir = await getApplicationSupportDirectory();
    Hive.init(dir.path);
    if (!_registered) {
      Hive.registerAdapter(HiveRecordAdapter());
      _registered = true;
    }
    final boxName = 'records_${encrypted ? 'enc' : 'plain'}';
    dbFile = File(p.join(dir.path, '$boxName.hive'));
    if (await dbFile!.exists()) await dbFile!.delete();
    _box = await Hive.openBox<HiveRecord>(
      boxName,
      encryptionCipher: encrypted ? HiveAesCipher(_aesKey) : null,
    );
  }

  HiveRecord _row(BenchRecord r) =>
      HiveRecord(r.id, r.indexedInt, r.text, r.value, r.flag, r.createdAt);

  @override
  Future<void> clear() async => _box!.clear();
  @override
  Future<void> close() async => _box?.close();

  @override
  Future<void> insertBulk(List<BenchRecord> records) async =>
      _box!.putAll({for (final r in records) r.id: _row(r)});

  @override
  Future<void> insertSingle(List<BenchRecord> records) async {
    for (final r in records) await _box!.put(r.id, _row(r));
  }

  @override
  Future<int> readAll() async => _box!.length;

  @override
  Future<int> queryIndexed(int threshold) async =>
      _box!.values.where((r) => r.indexedInt > threshold).length; // Dart-side filter

  @override
  Future<void> updateAll(List<BenchRecord> records) async =>
      _box!.putAll({for (final r in records) r.id: _row(r)});

  @override
  Future<void> deleteAll(List<String> ids) async => _box!.deleteAll(ids);
}
```

- [ ] **Step 2: Run codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: generates `lib/engines/hive_engine.g.dart` (the `HiveRecordAdapter`).

- [ ] **Step 3: Write `test/hive_engine_test.dart`**

```dart
import 'package:db_benchmark/bench_db.dart';
import 'package:db_benchmark/engines/hive_engine.dart';
import 'engine_conformance.dart';

void main() {
  runConformanceTests(
    'hive',
    HiveEngine.new,
    encryptable: true,
    rawFile: (db) => (db as HiveEngine).dbFile,
  );
}
```

- [ ] **Step 4: Run**

Run: `flutter test integration_test/hive_engine_test.dart -d macos` (copy under `integration_test/`).
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/engines/hive_engine.dart lib/engines/hive_engine.g.dart test/hive_engine_test.dart integration_test/hive_engine_test.dart
git commit -m "feat: hive (CE) engine adapter + conformance (AES)"
```

---

### Task 10: sembast engine adapter

Document store: no indexed query → Dart-side filter (via a `Finder`, still an in-store scan). Encryption via a `SembastCodec`.

**Files:**
- Create: `lib/engines/sembast_engine.dart`
- Create: `lib/engines/sembast_codec.dart` (simple XOR-stream codec — enough to prove the plaintext-leak test; NOT production crypto)
- Test: `test/sembast_engine_test.dart`

**Interfaces:**
- Produces: `class SembastEngine implements BenchDb` with `File? dbFile`.

- [ ] **Step 1: Write the codec `lib/engines/sembast_codec.dart`**

```dart
import 'dart:convert';
import 'package:sembast/sembast.dart';

/// Minimal reversible codec so the encrypted DB file contains no plaintext.
/// Demonstration only — do not use for real PHI.
class _XorCodec extends Codec<Object?, String> {
  final List<int> key;
  _XorCodec(this.key);
  @override
  Converter<Object?, String> get encoder => _XorEncoder(key);
  @override
  Converter<String, Object?> get decoder => _XorDecoder(key);
}

class _XorEncoder extends Converter<Object?, String> {
  final List<int> key;
  _XorEncoder(this.key);
  @override
  String convert(Object? input) {
    final bytes = utf8.encode(json.encode(input));
    final out = List<int>.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
    return base64.encode(out);
  }
}

class _XorDecoder extends Converter<String, Object?> {
  final List<int> key;
  _XorDecoder(this.key);
  @override
  Object? convert(String input) {
    final bytes = base64.decode(input);
    final out = List<int>.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
    return json.decode(utf8.decode(out));
  }
}

SembastCodec xorSembastCodec(List<int> key) =>
    SembastCodec(signature: 'xor', codec: _XorCodec(key));
```

- [ ] **Step 2: Write `lib/engines/sembast_engine.dart`**

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import '../bench_db.dart';
import 'sembast_codec.dart';

class SembastEngine implements BenchDb {
  Database? _db;
  final _store = stringMapStoreFactory.store('records');
  File? dbFile;
  static final _key = List<int>.filled(16, 9);

  @override
  String get name => 'sembast';
  @override
  bool supportsEncryption() => true;

  @override
  Future<void> open({required bool encrypted}) async {
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'sembast_${encrypted ? 'enc' : 'plain'}.db');
    dbFile = File(path);
    if (await dbFile!.exists()) await dbFile!.delete();
    _db = await databaseFactoryIo.openDatabase(
      path,
      codec: encrypted ? xorSembastCodec(_key) : null,
    );
  }

  Map<String, Object?> _row(BenchRecord r) => {
        'indexedInt': r.indexedInt, 'text': r.text,
        'value': r.value, 'flag': r.flag, 'createdAt': r.createdAt,
      };

  @override
  Future<void> clear() async => _store.delete(_db!);
  @override
  Future<void> close() async => _db?.close();

  @override
  Future<void> insertBulk(List<BenchRecord> records) async {
    await _db!.transaction((txn) async {
      for (final r in records) {
        await _store.record(r.id).put(txn, _row(r));
      }
    });
  }

  @override
  Future<void> insertSingle(List<BenchRecord> records) async {
    for (final r in records) {
      await _store.record(r.id).put(_db!, _row(r));
    }
  }

  @override
  Future<int> readAll() async => _store.count(_db!);

  @override
  Future<int> queryIndexed(int threshold) async {
    final finder = Finder(filter: Filter.greaterThan('indexedInt', threshold));
    return (await _store.find(_db!, finder: finder)).length; // Dart-side filter
  }

  @override
  Future<void> updateAll(List<BenchRecord> records) async {
    await _db!.transaction((txn) async {
      for (final r in records) {
        await _store.record(r.id).put(txn, _row(r));
      }
    });
  }

  @override
  Future<void> deleteAll(List<String> ids) async {
    await _db!.transaction((txn) async {
      for (final id in ids) {
        await _store.record(id).delete(txn);
      }
    });
  }
}
```

- [ ] **Step 3: Write `test/sembast_engine_test.dart`**

```dart
import 'package:db_benchmark/engines/sembast_engine.dart';
import 'engine_conformance.dart';

void main() {
  runConformanceTests(
    'sembast',
    SembastEngine.new,
    encryptable: true,
    rawFile: (db) => (db as SembastEngine).dbFile,
  );
}
```

- [ ] **Step 4: Run**

Run: `flutter test integration_test/sembast_engine_test.dart -d macos` (copy under `integration_test/`).
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/engines/sembast_engine.dart lib/engines/sembast_codec.dart test/sembast_engine_test.dart integration_test/sembast_engine_test.dart
git commit -m "feat: sembast engine adapter + conformance (codec)"
```

---

### Task 11: Platform-aware registry

**Files:**
- Create: `lib/registry.dart`
- Test: `test/registry_test.dart`

**Interfaces:**
- Consumes: all engine adapters, `BenchDb`.
- Produces:
  - `class EngineEntry { final String name; final BenchDb Function()? make; final String? skipReason; }`
  - `List<EngineEntry> registryFor({required bool isWeb})`

- [ ] **Step 1: Write the failing test `test/registry_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:db_benchmark/registry.dart';

void main() {
  test('native registry exposes all 7 engines with makers', () {
    final r = registryFor(isWeb: false);
    expect(r.map((e) => e.name).toSet(),
        {'drift', 'sqflite', 'floor', 'objectbox', 'isar', 'hive', 'sembast'});
    expect(r.where((e) => e.make != null).length, 7);
  });

  test('web registry skips objectbox and isar with reasons', () {
    final r = registryFor(isWeb: true);
    final obx = r.firstWhere((e) => e.name == 'objectbox');
    final isar = r.firstWhere((e) => e.name == 'isar');
    expect(obx.make, isNull);
    expect(obx.skipReason, isNotNull);
    expect(isar.make, isNull);
    expect(isar.skipReason, isNotNull);
    // drift/hive/sembast remain runnable on web
    expect(r.firstWhere((e) => e.name == 'drift').make, isNotNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/registry_test.dart`
Expected: FAIL — `registry.dart` missing.

- [ ] **Step 3: Write `lib/registry.dart`**

```dart
import 'bench_db.dart';
import 'engines/drift_engine.dart';
import 'engines/sqflite_engine.dart';
import 'engines/floor_engine.dart';
import 'engines/objectbox_engine.dart';
import 'engines/isar_engine.dart';
import 'engines/hive_engine.dart';
import 'engines/sembast_engine.dart';

class EngineEntry {
  final String name;
  final BenchDb Function()? make; // null → skipped
  final String? skipReason;
  const EngineEntry(this.name, this.make, {this.skipReason});
}

List<EngineEntry> registryFor({required bool isWeb}) => [
      EngineEntry('drift', DriftEngine.new),
      EngineEntry('sqflite', SqfliteEngine.new),
      EngineEntry('floor', FloorEngine.new),
      isWeb
          ? const EngineEntry('objectbox', null, skipReason: 'skipped (no web support)')
          : EngineEntry('objectbox', ObjectBoxEngine.new),
      isWeb
          ? const EngineEntry('isar', null, skipReason: 'skipped (web unsupported/flaky)')
          : EngineEntry('isar', IsarEngine.new),
      EngineEntry('hive', HiveEngine.new),
      EngineEntry('sembast', SembastEngine.new),
    ];
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/registry_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/registry.dart test/registry_test.dart
git commit -m "feat: platform-aware engine registry"
```

---

### Task 12: Runner (orchestration, warmup, iterations, median/min)

**Files:**
- Create: `lib/runner.dart`
- Test: `test/runner_test.dart`

**Interfaces:**
- Consumes: `BenchDb`, `BenchOp`, `OpResult`, `EngineResult`, `generateRecords`, `kQueryThreshold`, `FakeEngine` (test).
- Produces:
  - `class RunConfig { final int warmup; final int iterations; final int singleInsertRows; final int baselineRows; const RunConfig({this.warmup = 1, this.iterations = 3, this.singleInsertRows = 1000, this.baselineRows = 25000}); }`
  - `class Runner { Future<EngineResult> run(BenchDb db, {required bool encrypted, RunConfig cfg = const RunConfig()}); }`
  - Op semantics: `insertSingle` uses `singleInsertRows`; all other ops operate on a `baselineRows` dataset that is inserted **untimed** before timing the op.

- [ ] **Step 1: Write the failing test `test/runner_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:db_benchmark/bench_db.dart';
import 'package:db_benchmark/runner.dart';
import 'fake_engine.dart';

void main() {
  test('runner produces one OpResult per BenchOp with median/min set', () async {
    final res = await Runner().run(FakeEngine(), encrypted: false,
        cfg: const RunConfig(warmup: 1, iterations: 3, singleInsertRows: 50, baselineRows: 200));
    expect(res.engine, 'fake');
    expect(res.ops.map((o) => o.op).toSet(), BenchOp.values.toSet());
    for (final o in res.ops) {
      expect(o.median, isNotNull);
      expect(o.min, isNotNull);
      expect(o.iterations, 3);
      expect(o.median! >= o.min!, isTrue);
    }
  });

  test('runner marks encrypted N/A when engine lacks encryption', () async {
    final res = await Runner().run(FakeEngine(), encrypted: true,
        cfg: const RunConfig(iterations: 2, baselineRows: 100, singleInsertRows: 20));
    expect(res.ops.every((o) => o.skipReason != null && o.median == null), isTrue);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/runner_test.dart`
Expected: FAIL — `runner.dart` missing.

- [ ] **Step 3: Write `lib/runner.dart`**

```dart
import 'bench_db.dart';
import 'data_gen.dart';

class RunConfig {
  final int warmup;
  final int iterations;
  final int singleInsertRows;
  final int baselineRows;
  const RunConfig({
    this.warmup = 1,
    this.iterations = 3,
    this.singleInsertRows = 1000,
    this.baselineRows = 25000,
  });
}

class Runner {
  Future<EngineResult> run(BenchDb db, {required bool encrypted, RunConfig cfg = const RunConfig()}) async {
    if (encrypted && !db.supportsEncryption()) {
      return EngineResult(
        engine: db.name,
        ops: [
          for (final op in BenchOp.values)
            OpResult(op: op, encrypted: true, skipReason: _naReason(db.name)),
        ],
      );
    }

    await db.open(encrypted: encrypted);
    final baseline = generateRecords(cfg.baselineRows);
    final singleSet = generateRecords(cfg.singleInsertRows, seed: 7);
    final ops = <OpResult>[];
    try {
      for (final op in BenchOp.values) {
        final samples = <Duration>[];
        for (var i = 0; i < cfg.warmup + cfg.iterations; i++) {
          final d = await _timeOnce(db, op, baseline, singleSet, cfg);
          if (i >= cfg.warmup) samples.add(d);
        }
        samples.sort();
        ops.add(OpResult(
          op: op,
          encrypted: encrypted,
          median: samples[samples.length ~/ 2],
          min: samples.first,
          iterations: cfg.iterations,
        ));
      }
    } finally {
      await db.close();
    }
    return EngineResult(engine: db.name, ops: ops);
  }

  /// Sets up untimed state, then times exactly the target op.
  Future<Duration> _timeOnce(
      BenchDb db, BenchOp op, List<BenchRecord> baseline, List<BenchRecord> singleSet, RunConfig cfg) async {
    final sw = Stopwatch();
    switch (op) {
      case BenchOp.insertBulk:
        await db.clear();
        sw.start();
        await db.insertBulk(baseline);
        sw.stop();
      case BenchOp.insertSingle:
        await db.clear();
        sw.start();
        await db.insertSingle(singleSet);
        sw.stop();
      case BenchOp.readAll:
        await db.clear();
        await db.insertBulk(baseline);
        sw.start();
        await db.readAll();
        sw.stop();
      case BenchOp.queryIndexed:
        await db.clear();
        await db.insertBulk(baseline);
        sw.start();
        await db.queryIndexed(kQueryThreshold);
        sw.stop();
      case BenchOp.updateAll:
        await db.clear();
        await db.insertBulk(baseline);
        final updated = baseline.map((r) => r.copyWith(value: 1.0)).toList();
        sw.start();
        await db.updateAll(updated);
        sw.stop();
      case BenchOp.deleteAll:
        await db.clear();
        await db.insertBulk(baseline);
        sw.start();
        await db.deleteAll(baseline.map((r) => r.id).toList());
        sw.stop();
    }
    return sw.elapsed;
  }

  String _naReason(String engine) =>
      engine == 'objectbox' ? 'N/A (encryption commercial)' : 'N/A (encryption unsupported)';
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/runner_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/runner.dart test/runner_test.dart
git commit -m "feat: runner with warmup, iterations, median/min, N/A handling"
```

---

### Task 13: Report (console / JSON / CSV / markdown)

**Files:**
- Create: `lib/report.dart`
- Test: `test/report_test.dart`

**Interfaces:**
- Consumes: `EngineResult`, `OpResult`, `BenchOp`.
- Produces:
  - `String renderMarkdown(List<EngineResult> results, {required bool encrypted})`
  - `String renderCsv(List<EngineResult> results)`
  - `String renderJson(List<EngineResult> results)`
  - Cells show `median.inMilliseconds` ms, or the `skipReason` verbatim.

- [ ] **Step 1: Write the failing test `test/report_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:db_benchmark/bench_db.dart';
import 'package:db_benchmark/report.dart';

void main() {
  final results = [
    EngineResult(engine: 'drift', ops: [
      const OpResult(op: BenchOp.insertBulk, encrypted: false,
          median: Duration(milliseconds: 120), min: Duration(milliseconds: 110), iterations: 3),
    ]),
    const EngineResult(engine: 'objectbox', ops: [
      OpResult(op: BenchOp.insertBulk, encrypted: true, skipReason: 'N/A (encryption commercial)'),
    ]),
  ];

  test('markdown includes engine rows and skip reasons', () {
    final md = renderMarkdown(results, encrypted: false);
    expect(md.contains('drift'), isTrue);
    expect(md.contains('120'), isTrue);
    expect(md.contains('N/A (encryption commercial)'), isTrue);
  });

  test('csv has a header and one row per engine/op', () {
    final csv = renderCsv(results);
    expect(csv.split('\n').first, 'engine,op,encrypted,median_ms,min_ms,skip_reason');
    expect(csv.contains('drift,insertBulk,false,120,110,'), isTrue);
  });

  test('json is parseable and lists engines', () {
    final jsonStr = renderJson(results);
    expect(jsonStr.contains('"engine":"drift"'), isTrue);
    expect(jsonStr.contains('"skip_reason":"N/A (encryption commercial)"'), isTrue);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/report_test.dart`
Expected: FAIL — `report.dart` missing.

- [ ] **Step 3: Write `lib/report.dart`**

```dart
import 'dart:convert';
import 'bench_db.dart';

String _cell(OpResult o) => o.skipReason ?? '${o.median!.inMilliseconds}';

String renderMarkdown(List<EngineResult> results, {required bool encrypted}) {
  final ops = BenchOp.values;
  final sb = StringBuffer()
    ..writeln('### ${encrypted ? 'Encrypted' : 'Plaintext'} — median ms')
    ..writeln('| engine | ${ops.map((o) => o.name).join(' | ')} |')
    ..writeln('|${List.filled(ops.length + 1, '---').join('|')}|');
  for (final e in results) {
    if (e.skipReason != null) {
      sb.writeln('| ${e.engine} | ${List.filled(ops.length, e.skipReason).join(' | ')} |');
      continue;
    }
    final byOp = {for (final o in e.ops) o.op: o};
    sb.writeln('| ${e.engine} | ${ops.map((o) => byOp[o] == null ? '-' : _cell(byOp[o]!)).join(' | ')} |');
  }
  return sb.toString();
}

String renderCsv(List<EngineResult> results) {
  final sb = StringBuffer('engine,op,encrypted,median_ms,min_ms,skip_reason\n');
  for (final e in results) {
    for (final o in e.ops) {
      sb.writeln([
        e.engine,
        o.op.name,
        o.encrypted,
        o.median?.inMilliseconds ?? '',
        o.min?.inMilliseconds ?? '',
        o.skipReason ?? '',
      ].join(','));
    }
  }
  return sb.toString();
}

String renderJson(List<EngineResult> results) {
  return jsonEncode([
    for (final e in results)
      {
        'engine': e.engine,
        'skip_reason': e.skipReason,
        'ops': [
          for (final o in e.ops)
            {
              'op': o.op.name,
              'encrypted': o.encrypted,
              'median_ms': o.median?.inMilliseconds,
              'min_ms': o.min?.inMilliseconds,
              'skip_reason': o.skipReason,
            }
        ],
      }
  ]);
}
```

Note: `jsonEncode` emits `"engine":"drift"` without spaces, matching the test.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/report_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/report.dart test/report_test.dart
git commit -m "feat: report renderers (markdown/csv/json)"
```

---

### Task 14: App entry — run, render, persist

**Files:**
- Modify: `lib/main.dart` (replace placeholder)
- Create: `lib/bench_app.dart`

**Interfaces:**
- Consumes: `registryFor`, `Runner`, `renderMarkdown/Csv/Json`, `path_provider`.
- Produces: a `BenchApp` widget with a "Run all" button that runs every available engine (plain + encrypted), renders a live markdown table, and writes `results/{platform}-{ts}.{json,csv,md}` on non-web (console + no-throw on web).

- [ ] **Step 1: Write `lib/bench_app.dart`**

```dart
import 'dart:io' show File, Directory, Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'registry.dart';
import 'runner.dart';
import 'report.dart';
import 'bench_db.dart';

class BenchApp extends StatefulWidget {
  const BenchApp({super.key});
  @override
  State<BenchApp> createState() => _BenchAppState();
}

class _BenchAppState extends State<BenchApp> {
  String _log = 'Idle. Run in --release for real numbers.';
  bool _running = false;

  Future<void> _runAll() async {
    if (kDebugMode) {
      setState(() => _log = 'WARNING: debug mode — numbers are meaningless. Use --release.\n');
    }
    setState(() => _running = true);
    final isWeb = kIsWeb;
    final plain = <EngineResult>[];
    final enc = <EngineResult>[];
    for (final entry in registryFor(isWeb: isWeb)) {
      if (entry.make == null) {
        plain.add(EngineResult(engine: entry.name, skipReason: entry.skipReason));
        enc.add(EngineResult(engine: entry.name, skipReason: entry.skipReason));
        setState(() => _log += '${entry.name}: ${entry.skipReason}\n');
        continue;
      }
      setState(() => _log += 'running ${entry.name}...\n');
      plain.add(await Runner().run(entry.make!(), encrypted: false));
      enc.add(await Runner().run(entry.make!(), encrypted: true));
    }
    final md = '${renderMarkdown(plain, encrypted: false)}\n${renderMarkdown(enc, encrypted: true)}';
    setState(() => _log = md);
    await _persist(plain + enc, md);
    setState(() => _running = false);
  }

  Future<void> _persist(List<EngineResult> all, String md) async {
    if (kIsWeb) return; // console-only on web
    final dir = Directory(p.join(Directory.current.path, 'results'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final platform = Platform.operatingSystem;
    final stem = p.join(dir.path, '$platform-run');
    await File('$stem.md').writeAsString(md);
    await File('$stem.csv').writeAsString(renderCsv(all));
    await File('$stem.json').writeAsString(renderJson(all));
    setState(() => _log += '\nwrote $stem.{md,csv,json}');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('DB Benchmark')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _running ? null : _runAll,
          label: Text(_running ? 'running...' : 'Run all'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectableText(_log, style: const TextStyle(fontFamily: 'monospace')),
        ),
      );
}
```

- [ ] **Step 2: Replace `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'bench_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    title: 'db_benchmark',
    debugShowCheckedModeBanner: false,
    home: const BenchApp(),
  ));
  if (kDebugMode) debugPrint('Run with --release for real numbers.');
}
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Smoke-run on macOS**

Run: `flutter run --release -d macos`
Expected: window opens; tapping "Run all" produces a markdown table and writes `results/macos-run.{md,csv,json}`. Verify the files exist and the encrypted objectbox cells read `N/A (encryption commercial)`.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/bench_app.dart
git commit -m "feat: bench app entry — run all engines, render + persist results"
```

---

### Task 15: README + run matrix

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: everything. Produces: run instructions per platform + a results-interpretation note.

- [ ] **Step 1: Write `README.md`**

```markdown
# db_benchmark

Standalone harness comparing seven Flutter local databases (drift, sqflite, floor,
objectbox, isar, hive_ce, sembast) across CRUD ops, plaintext + encrypted.

## Design
See `docs/superpowers/specs/2026-07-04-flutter-db-benchmark-design.md` in balsm_app.

## Run (release only — debug numbers are meaningless)
- macOS:   `flutter run --release -d macos`
- Linux:   `flutter run --release -d linux`
- Windows: `flutter run --release -d windows`
- iOS:     `flutter run --release -d <ios-device>`
- Android: `flutter run --release -d <android-device>`
- Web:     `flutter run --release -d chrome` (objectbox + isar auto-skipped)

Tap "Run all". Results print on screen and write to `results/{platform}-run.{md,csv,json}`
(console only on web).

## Reading the numbers
- Medians in ms; `min` in the CSV/JSON is best-case.
- `N/A (...)` = engine cannot do that config (e.g. objectbox encryption is commercial).
- `skipped (...)` = engine unavailable on this platform (objectbox/isar on web).
- KV engines (hive, sembast) have no indexed query; their `queryIndexed` is a Dart-side
  filter and is expected to scale worse — that is the finding, not a bug.
- This measures THIS workload on THIS device. Not a universal ranking.
  Methodology mirrors https://powersync.com/blog/flutter-database-comparison-sqlite-async-sqflite-objectbox-isar
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: readme with per-platform run matrix + interpretation notes"
```

---

## Self-Review

**Spec coverage:**
- 7 engines → Tasks 4–10. ✓
- Common interface + adapters → Task 2 (`BenchDb`) + per-engine tasks. ✓
- Platform-aware registry, web excludes objectbox/isar → Task 11. ✓
- Runner: warmup, ≥3 iters, median+min, isolate note, N/A → Task 12. ✓
- Encryption dimension, plaintext-leak verification → Task 3 conformance + per-engine `supportsEncryption`. ✓
- Output console/JSON/CSV/markdown, reasons not blanks → Task 13 + 14. ✓
- Row counts (1k single / 25k baseline), seeded determinism → Task 2 + `RunConfig` in Task 12. ✓
- Fixed record shape everywhere → Task 2 model, each adapter maps to it. ✓
- Release-mode warning → Task 14. ✓
- Fairness/honesty banners, KV filter documented → Task 15 README + conformance. ✓
- Six-platform run matrix → Task 15. ✓

**Placeholder scan:** No "TBD"/"handle edge cases"/"similar to Task N". Codegen steps are explicit commands, not placeholders. Encrypted-N/A paths for floor/objectbox/isar are deliberate `supportsEncryption() => false`, documented, and exercised by the runner — a real behavior, not a gap in the plan.

**Type consistency:** `BenchRecord`, `BenchOp`, `OpResult`, `EngineResult`, `BenchDb` signatures defined in Task 2 and used verbatim in Tasks 3–14. `RunConfig` fields (`warmup`, `iterations`, `singleInsertRows`, `baselineRows`) consistent between Task 12 definition and its test. `registryFor({required bool isWeb})` consistent between Tasks 11 and 14. `renderMarkdown/Csv/Json` signatures consistent between Tasks 13 and 14. `rawFile` callback name consistent between Task 3 suite and Tasks 4/5/9/10 wiring.

**Known execution risks (called out at point of use, not hidden):** Isar version resolution (Task 1), Floor list-binding for `deleteIds` (Task 6), and DB tests needing an `integration_test/` host on desktop rather than the pure-Dart test runner (Tasks 4–10). Each has an inline fallback.
