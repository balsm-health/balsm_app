# Offline-Resilient Reads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every screen that can render from previously-seen server data does so when the network is unavailable, and every screen that cannot says why.

**Architecture:** One `cache_entry` table in the existing SQLCipher `AppDatabase` behind a `CacheStore` port. A `CachedValue<T>` policy object falls back to stale data for connectivity errors only, never for server errors. `OfflineFailure` joins the sealed `AppFailure` hierarchy so writes can fail with an honest message.

**Tech Stack:** Flutter 3.41.9 via fvm, melos monorepo, drift + SQLCipher, Riverpod, dio, connectivity_plus, i69n.

**Spec:** `docs/superpowers/specs/2026-09-13-offline-resilient-reads-design.md`

## Global Constraints

- Flutter runs via **fvm**: `fvm flutter …`, `fvm dart …`. Never bare `flutter`.
- Never log, print, or transmit PHI. Never fabricate sample PHI in code or fixtures — tests use synthetic non-PHI values only.
- Nothing written to `cache_entry` is PHI. `cache_entry` must NEVER be added to `SnapshotService._tables`.
- Requests are **never** gated on `onlineProvider`. The app always attempts the request; a failed attempt is the authoritative offline signal. Connectivity drives UI only.
- Stale data is served **only** when `isOfflineError(e)` is true. Every other error rethrows.
- A failed remote call is never retained.
- UI strings go in i69n JSON bundles, English and Arabic. No inline `ar ? … : …` ternaries. After editing a bundle run `fvm dart run build_runner build` in that package.
- Modules depend on `core`, never on each other.
- Run `fvm flutter analyze --no-fatal-infos` in each touched package before committing.

---

### Task 1: Cache storage tier

**Files:**
- Create: `packages/core/lib/src/cache/cache_row.dart`
- Create: `packages/core/lib/src/cache/cache_store.dart`
- Create: `packages/core/lib/src/cache/drift_cache_store.dart`
- Modify: `packages/core/lib/src/db/app_database.dart` (add `_cacheSchema`, run it in `beforeOpen`)
- Modify: `packages/core/lib/core.dart` (export the three new files)
- Test: `packages/core/test/cache/drift_cache_store_test.dart`
- Test: `packages/core/test/backup/snapshot_excludes_cache_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` and `appDatabaseProvider` from `packages/core/lib/src/db/app_database.dart`.
- Produces: `CacheRow({required String key, required String payload, required DateTime fetchedAt})` with `bool isFresh(Duration ttl)`; `abstract interface class CacheStore` with `read/write/delete/readNamespace/evictOldest/clearNamespace/clearAll`; `DriftCacheStore(AppDatabase)`; `final cacheStoreProvider = Provider<CacheStore>(…)`.

- [ ] **Step 1: Write the failing test**

`packages/core/test/cache/drift_cache_store_test.dart`:

```dart
import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftCacheStore store;

  setUp(() async {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    store = DriftCacheStore(db);
  });
  tearDown(() => db.close());

  test('round-trips a payload', () async {
    await store.write('account', 'u1', '{"handle":"sara"}');
    final row = await store.read('account', 'u1');
    expect(row!.payload, '{"handle":"sara"}');
    expect(row.key, 'u1');
  });

  test('namespaces are isolated', () async {
    await store.write('account', 'k', 'a');
    await store.write('care', 'k', 'b');
    expect((await store.read('account', 'k'))!.payload, 'a');
    expect((await store.read('care', 'k'))!.payload, 'b');
  });

  test('read returns null for an absent key', () async {
    expect(await store.read('account', 'nope'), isNull);
  });

  test('write overwrites and refreshes fetchedAt', () async {
    await store.write('account', 'k', 'old');
    final first = (await store.read('account', 'k'))!.fetchedAt;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.write('account', 'k', 'new');
    final row = (await store.read('account', 'k'))!;
    expect(row.payload, 'new');
    expect(row.fetchedAt.isAfter(first) || row.fetchedAt == first, isTrue);
  });

  test('evictOldest keeps exactly the newest N of its own namespace', () async {
    for (var i = 0; i < 5; i++) {
      await store.write('care', 'q$i', 'p$i');
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    await store.write('account', 'keepme', 'x');

    await store.evictOldest('care', keep: 2);

    final care = await store.readNamespace('care');
    expect(care.map((r) => r.key).toSet(), {'q3', 'q4'});
    expect(await store.read('account', 'keepme'), isNotNull);
  });

  test('clearNamespace leaves other namespaces intact', () async {
    await store.write('care', 'a', '1');
    await store.write('account', 'b', '2');
    await store.clearNamespace('care');
    expect(await store.readNamespace('care'), isEmpty);
    expect(await store.read('account', 'b'), isNotNull);
  });

  test('isFresh compares against fetchedAt', () {
    final fresh = CacheRow(key: 'k', payload: 'p', fetchedAt: DateTime.now().toUtc());
    final old = CacheRow(
      key: 'k',
      payload: 'p',
      fetchedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    );
    expect(fresh.isFresh(const Duration(hours: 1)), isTrue);
    expect(old.isFresh(const Duration(hours: 1)), isFalse);
  });
}
```

`packages/core/test/backup/snapshot_excludes_cache_test.dart`:

```dart
import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a snapshot never carries cache rows', () async {
    final db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);
    await DriftCacheStore(db).write('account', 'u1', '{"handle":"sara"}');

    final snapshot = await SnapshotService(db).export();
    final tables = (snapshot['tables'] as Map).cast<String, dynamic>();

    expect(tables.containsKey('cache_entry'), isFalse,
        reason: 'cache_entry must stay out of SnapshotService._tables — '
            'cache is not PHI and must not travel in a backup');
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd packages/core && fvm flutter test test/cache/ test/backup/snapshot_excludes_cache_test.dart
```

Expected: FAIL — `CacheRow`, `CacheStore`, `DriftCacheStore` are undefined.

If `SnapshotService(db).export()` does not match the real constructor or method name, read `packages/core/lib/src/backup/snapshot_service.dart` and correct the test call — the assertion is what matters, not the spelling.

- [ ] **Step 3: Add the schema**

In `packages/core/lib/src/db/app_database.dart`, add a new top-level const beside `_phiSchema`:

```dart
/// Cache schema — deliberately separate from [_phiSchema].
///
/// Nothing here is PHI, nothing here participates in backup, and dropping the
/// whole table is always safe: every row can be re-fetched. It shares the
/// encrypted database only to reuse the one connection and the one key.
///
/// `cache_entry` must NEVER appear in `SnapshotService._tables`.
const _cacheSchema = <String>[
  '''
  CREATE TABLE IF NOT EXISTS cache_entry (
    namespace  TEXT    NOT NULL,
    key        TEXT    NOT NULL,
    payload    TEXT    NOT NULL,
    fetched_at INTEGER NOT NULL,
    PRIMARY KEY (namespace, key)
  )''',
  'CREATE INDEX IF NOT EXISTS idx_cache_entry_ns_time ON cache_entry(namespace, fetched_at)',
];
```

In `beforeOpen`, immediately after the `for (final stmt in _phiSchema)` loop, add:

```dart
for (final stmt in _cacheSchema) {
  await customStatement(stmt);
}
```

- [ ] **Step 4: Implement `CacheRow`**

`packages/core/lib/src/cache/cache_row.dart`:

```dart
/// One cached payload and when it was fetched.
///
/// Freshness is a question the caller asks with its own TTL rather than a
/// property of the row: the same row is fresh enough for one consumer and
/// stale for another.
class CacheRow {
  const CacheRow({
    required this.key,
    required this.payload,
    required this.fetchedAt,
  });

  final String key;

  /// Opaque to the store — JSON, by every current convention, but the store
  /// neither parses nor validates it.
  final String payload;

  final DateTime fetchedAt;

  bool isFresh(Duration ttl) => DateTime.now().toUtc().difference(fetchedAt.toUtc()) < ttl;
}
```

- [ ] **Step 5: Implement the port**

`packages/core/lib/src/cache/cache_store.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cache_row.dart';

/// Raw keyed payloads, grouped by namespace.
///
/// Deliberately policy-free: no TTL, no typing, no eviction schedule. Those
/// belong to whoever owns the data — see `CachedValue` for the single-value
/// policy and the care directory's local source for the bounded one. This is
/// the same split the core [DataSource] contract makes.
abstract interface class CacheStore {
  Future<CacheRow?> read(String namespace, String key);
  Future<void> write(String namespace, String key, String payload);
  Future<void> delete(String namespace, String key);
  Future<List<CacheRow>> readNamespace(String namespace);

  /// Deletes all but the [keep] most recently fetched rows in [namespace].
  /// Other namespaces are untouched.
  Future<void> evictOldest(String namespace, {required int keep});

  Future<void> clearNamespace(String namespace);
  Future<void> clearAll();
}

final cacheStoreProvider = Provider<CacheStore>(
  (ref) => throw UnimplementedError('cacheStoreProvider must be overridden in bootstrap()'),
);
```

- [ ] **Step 6: Implement the drift store**

`packages/core/lib/src/cache/drift_cache_store.dart`:

```dart
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'cache_row.dart';
import 'cache_store.dart';

/// [CacheStore] over the `cache_entry` table in [AppDatabase].
///
/// Raw SQL rather than generated drift tables, matching every other DAO in
/// this database (see `_phiSchema`).
class DriftCacheStore implements CacheStore {
  const DriftCacheStore(this._db);

  final AppDatabase _db;

  @override
  Future<CacheRow?> read(String namespace, String key) async {
    final rows = await _db.customSelect(
      'SELECT key, payload, fetched_at FROM cache_entry WHERE namespace = ? AND key = ? LIMIT 1',
      variables: [Variable.withString(namespace), Variable.withString(key)],
    ).get();
    if (rows.isEmpty) return null;
    return _toRow(rows.first);
  }

  @override
  Future<void> write(String namespace, String key, String payload) => _db.customInsert(
        'INSERT OR REPLACE INTO cache_entry (namespace, key, payload, fetched_at) VALUES (?, ?, ?, ?)',
        variables: [
          Variable.withString(namespace),
          Variable.withString(key),
          Variable.withString(payload),
          Variable.withInt(DateTime.now().toUtc().millisecondsSinceEpoch),
        ],
      );

  @override
  Future<void> delete(String namespace, String key) => _db.customStatement(
        'DELETE FROM cache_entry WHERE namespace = ? AND key = ?',
        [namespace, key],
      );

  @override
  Future<List<CacheRow>> readNamespace(String namespace) async {
    final rows = await _db.customSelect(
      'SELECT key, payload, fetched_at FROM cache_entry WHERE namespace = ? ORDER BY fetched_at DESC',
      variables: [Variable.withString(namespace)],
    ).get();
    return rows.map(_toRow).toList(growable: false);
  }

  @override
  Future<void> evictOldest(String namespace, {required int keep}) => _db.customStatement(
        'DELETE FROM cache_entry WHERE namespace = ? AND key NOT IN ('
        '  SELECT key FROM cache_entry WHERE namespace = ? ORDER BY fetched_at DESC LIMIT ?'
        ')',
        [namespace, namespace, keep],
      );

  @override
  Future<void> clearNamespace(String namespace) =>
      _db.customStatement('DELETE FROM cache_entry WHERE namespace = ?', [namespace]);

  @override
  Future<void> clearAll() => _db.customStatement('DELETE FROM cache_entry');

  CacheRow _toRow(QueryRow r) => CacheRow(
        key: r.read<String>('key'),
        payload: r.read<String>('payload'),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('fetched_at'), isUtc: true),
      );
}
```

- [ ] **Step 7: Export from the barrel**

Add to `packages/core/lib/core.dart`, immediately after the `src/db/app_database.dart` export:

```dart
export 'src/cache/cache_row.dart';
export 'src/cache/cache_store.dart';
export 'src/cache/drift_cache_store.dart';
```

- [ ] **Step 8: Run tests to verify they pass**

```bash
cd packages/core && fvm flutter test test/cache/ test/backup/ && fvm flutter analyze --no-fatal-infos
```

Expected: PASS, no analyzer errors.

- [ ] **Step 9: Commit**

```bash
git add packages/core/lib/src/cache packages/core/lib/src/db/app_database.dart \
        packages/core/lib/core.dart packages/core/test/cache \
        packages/core/test/backup/snapshot_excludes_cache_test.dart
git commit -m "[Core] Cache storage tier over the on-device database"
```

---

### Task 2: Offline classification and connectivity

**Files:**
- Create: `packages/balsm_api/lib/src/transport/offline.dart`
- Modify: `packages/balsm_api/lib/src/transport/api_exception.dart` (add `isOffline`)
- Modify: `packages/balsm_api/lib/balsm_api.dart` (export `offline.dart`)
- Modify: `packages/core/lib/src/domain/app_failure.dart` (add `OfflineFailure`)
- Create: `packages/core/lib/src/network/connectivity.dart`
- Modify: `packages/core/lib/src/backup/connectivity_online_stream.dart` (becomes a re-export)
- Modify: `packages/core/lib/core.dart`
- Test: `packages/balsm_api/test/transport/offline_test.dart`
- Test: `packages/core/test/network/offline_failure_test.dart`

**Interfaces:**
- Consumes: `DioException` from `package:dio/dio.dart`; `AppFailure` from `packages/core/lib/src/domain/app_failure.dart`.
- Produces: `bool isOfflineError(Object error)` (from `package:balsm_api/balsm_api.dart`); `ApiException.isOffline`; `final class OfflineFailure extends AppFailure`; `Stream<bool> connectivityOnlineStream()`; `final onlineProvider = StreamProvider<bool>(…)`.

**Why the classifier lives in `balsm_api`, not `core`:** it is pure dio, and
`core` already depends on `balsm_api` (not the other way round). Putting it in
core and having `balsm_api` need it would invert that.

**The blocker this task removes.** `ApiException.fromDioException` currently
discards the `DioException` it was built from. A connection error and a
malformed response body both arrive downstream as
`ApiException(code: 'network_error', statusCode: null)` — indistinguishable.
Every use case catches `ApiException`, never `DioException`, so without
carrying the verdict forward no write path can tell offline from broken. Add
the field at the point the information still exists.

**Why `NetworkFailure` is not reused:** `modules/auth/test/application/sign_in_use_case_test.dart` asserts that *any* unexpected error maps to `NetworkFailure` — it is the catch-all and must stay one. `OfflineFailure` is the narrower claim that the request never reached a server. Do not change `NetworkFailure`'s meaning or those tests will fail for the right reason.

- [ ] **Step 1: Write the failing test**

`packages/balsm_api/test/transport/offline_test.dart` (plain `package:test`, since `balsm_api` is a Dart package with no Flutter dependency):

```dart
import 'dart:io';

import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

DioException _dio(DioExceptionType type, {int? status}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
      response: status == null ? null : Response(requestOptions: RequestOptions(path: '/x'), statusCode: status),
    );

void main() {
  group('isOfflineError', () {
    test('true for transport-level dio failures', () {
      expect(isOfflineError(_dio(DioExceptionType.connectionError)), isTrue);
      expect(isOfflineError(_dio(DioExceptionType.connectionTimeout)), isTrue);
      expect(isOfflineError(_dio(DioExceptionType.sendTimeout)), isTrue);
      expect(isOfflineError(_dio(DioExceptionType.receiveTimeout)), isTrue);
    });

    test('true for a raw SocketException', () {
      expect(isOfflineError(const SocketException('no route to host')), isTrue);
    });

    test('true for a SocketException wrapped by dio', () {
      expect(
        isOfflineError(DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.unknown,
          error: const SocketException('failed host lookup'),
        )),
        isTrue,
      );
    });

    test('false when the server answered', () {
      expect(isOfflineError(_dio(DioExceptionType.badResponse, status: 401)), isFalse);
      expect(isOfflineError(_dio(DioExceptionType.badResponse, status: 500)), isFalse);
    });

    test('false for a cancellation', () {
      expect(isOfflineError(_dio(DioExceptionType.cancel)), isFalse,
          reason: 'a superseded map pan is not the user being offline');
    });

    test('false for a parse error', () {
      expect(isOfflineError(FormatException('bad json')), isFalse,
          reason: 'a malformed body means the server answered — serving stale '
              'data for it would hide a real bug');
    });
  });

  test('ApiException carries the verdict forward', () {
    final offline = ApiException.fromDioException(_dio(DioExceptionType.connectionError));
    final serverError = ApiException.fromDioException(_dio(DioExceptionType.badResponse, status: 500));

    expect(offline.isOffline, isTrue);
    expect(serverError.isOffline, isFalse);
    expect(ApiException.fromDioException(_dio(DioExceptionType.cancel)).isOffline, isFalse);
  });
}
```

`packages/core/test/network/offline_failure_test.dart`:

```dart
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OfflineFailure is an AppFailure distinct from NetworkFailure', () {
    const f = OfflineFailure();
    expect(f, isA<AppFailure>());
    expect(f, isNot(isA<NetworkFailure>()));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/balsm_api && fvm dart test test/transport/offline_test.dart
cd ../core && fvm flutter test test/network/offline_failure_test.dart
```

Expected: FAIL — `isOfflineError`, `ApiException.isOffline` and `OfflineFailure` are undefined.

- [ ] **Step 3: Add `OfflineFailure`**

Append to `packages/core/lib/src/domain/app_failure.dart`:

```dart
/// The request never reached a server.
///
/// Narrower than [NetworkFailure], which is the catch-all for anything
/// unexpected. Only this one means "you are offline" — and only this one
/// justifies serving cached data past its TTL.
final class OfflineFailure extends AppFailure {
  const OfflineFailure([super.message = 'No connection']);
}
```

- [ ] **Step 4: Implement the classifier**

`packages/balsm_api/lib/src/transport/offline.dart`:

```dart
import 'dart:io';

import 'package:dio/dio.dart';

/// Whether [error] means the request never reached a server.
///
/// One implementation so every layer agrees. The distinction it draws is the
/// one that makes a stale-fallback cache safe: a transport failure may be
/// answered from cache, but a 500, a 401 or a malformed body must not be —
/// serving stale data for those would turn a server bug into silent, endless
/// staleness.
///
/// A cancellation is NOT offline: the map cancels superseded requests on every
/// settled pan, and treating that as offline would flag a working connection.
bool isOfflineError(Object error) {
  if (error is SocketException) return true;
  if (error is! DioException) return false;

  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return true;
    case DioExceptionType.badCertificate:
    case DioExceptionType.badResponse:
    case DioExceptionType.cancel:
      return false;
    case DioExceptionType.unknown:
      // dio wraps the underlying transport error here.
      return error.error is SocketException;
  }
}
```

Then stop `ApiException` discarding the verdict. In
`packages/balsm_api/lib/src/transport/api_exception.dart`, add the field:

```dart
  /// Whether the request never reached a server.
  ///
  /// Decided at construction, where the `DioException` is still in hand.
  /// `code == 'network_error'` cannot stand in for this: that code is also
  /// produced for a null status from a malformed body and for any unmapped
  /// status, and treating those as "offline" would serve stale data to hide a
  /// server bug.
  final bool isOffline;
```

Default it to `false` in the const constructor (`this.isOffline = false`), and
in `fromDioException` — after the `cancel` early return, which must keep
returning `const ApiException(code: 'cancelled')` — pass `isOffline:
isOfflineError(e)` to the returned `ApiException`. Leave
`fromEnvelopeError` alone: an envelope error means the server answered.

Export it from `packages/balsm_api/lib/balsm_api.dart`:

```dart
export 'src/transport/offline.dart';
```

- [ ] **Step 5: Move connectivity into the network layer**

Create `packages/core/lib/src/network/connectivity.dart`:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits `true` while any network interface is up, `false` when none is.
///
/// Emits the CURRENT state immediately on subscribe.
/// `onConnectivityChanged` does not — a listener would otherwise know nothing
/// until the interface next changed, which on a device that booted offline is
/// never.
Stream<bool> connectivityOnlineStream() async* {
  final connectivity = Connectivity();
  yield _isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_isOnline);
}

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// Interface state for the UI — NOT a precondition for making requests.
///
/// `connectivity_plus` reports whether an interface is up, not whether a
/// server is reachable: a captive-portal Wi-Fi reports online with nothing
/// routable behind it. Gating requests on this would block working connections
/// and admit dead ones. Always attempt the request; let the failure decide.
final onlineProvider = StreamProvider<bool>((ref) => connectivityOnlineStream());
```

Replace the body of `packages/core/lib/src/backup/connectivity_online_stream.dart` with a re-export so `BackupService` keeps compiling:

```dart
/// Moved to `src/network/connectivity.dart` — connectivity is not a backup
/// concern. Kept as a re-export so existing imports resolve.
export '../network/connectivity.dart' show connectivityOnlineStream;
```

- [ ] **Step 6: Export from the barrel**

Add to `packages/core/lib/core.dart` beside the other `src/network/` exports:

```dart
export 'src/network/connectivity.dart';
```

`isOfflineError` needs no core export — `core.dart` already re-exports
`package:balsm_api/balsm_api.dart`. Confirm that is true by reading the barrel;
if it does not, add `export 'package:balsm_api/balsm_api.dart' show isOfflineError;`.

If the analyzer reports an ambiguous export between `src/network/connectivity.dart` and `src/backup/connectivity_online_stream.dart`, remove the `src/backup/connectivity_online_stream.dart` line from the barrel — the symbol is now exported from its new home.

- [ ] **Step 7: Run tests to verify they pass**

```bash
cd packages/balsm_api && fvm dart test && fvm dart analyze
cd ../core && fvm flutter test && fvm flutter analyze --no-fatal-infos
```

Expected: PASS for both suites. The backup tests must still pass — if any fail on the connectivity move, fix the import, not the test.

- [ ] **Step 8: Commit**

```bash
git add packages/balsm_api/lib/src/transport packages/balsm_api/lib/balsm_api.dart \
        packages/balsm_api/test/transport/offline_test.dart \
        packages/core/lib/src/domain/app_failure.dart packages/core/lib/src/network \
        packages/core/lib/src/backup/connectivity_online_stream.dart \
        packages/core/lib/core.dart packages/core/test/network/offline_failure_test.dart
git commit -m "[API] Distinguish being offline from a request that failed"
```

---

### Task 3: CachedValue policy

**Files:**
- Create: `packages/core/lib/src/cache/cached_value.dart`
- Modify: `packages/core/lib/core.dart`
- Test: `packages/core/test/cache/cached_value_test.dart`

**Interfaces:**
- Consumes: `CacheStore`, `CacheRow` (Task 1); `isOfflineError` (Task 2).
- Produces: `CachedValue<T>({required CacheStore store, required String namespace, required Duration ttl, required T Function(Map<String, dynamic>) decode, required Map<String, dynamic> Function(T) encode})` with `Future<T?> read(String key, {required Future<T?> Function() fetch})`, `Future<T?> peek(String key)`, `Future<void> invalidate(String key)`, `Future<void> invalidateAll()`.

- [ ] **Step 1: Write the failing test**

`packages/core/test/cache/cached_value_test.dart`:

```dart
import 'dart:io';

import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Synthetic, non-PHI.
class _Thing {
  const _Thing(this.name);
  final String name;
  Map<String, dynamic> toJson() => {'name': name};
  static _Thing fromJson(Map<String, dynamic> j) => _Thing(j['name'] as String);
}

void main() {
  late AppDatabase db;
  late CachedValue<_Thing> cached;

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    cached = CachedValue<_Thing>(
      store: DriftCacheStore(db),
      namespace: 'thing',
      ttl: const Duration(hours: 1),
      decode: _Thing.fromJson,
      encode: (t) => t.toJson(),
    );
  });
  tearDown(() => db.close());

  test('a miss fetches and retains', () async {
    var calls = 0;
    final got = await cached.read('k', fetch: () async {
      calls++;
      return const _Thing('fetched');
    });
    expect(got!.name, 'fetched');
    expect(calls, 1);
    expect((await cached.peek('k'))!.name, 'fetched');
  });

  test('a fresh hit does not fetch', () async {
    await cached.read('k', fetch: () async => const _Thing('first'));
    var calls = 0;
    final got = await cached.read('k', fetch: () async {
      calls++;
      return const _Thing('second');
    });
    expect(calls, 0, reason: 'a fresh row must not touch the network');
    expect(got!.name, 'first');
  });

  test('a stale hit refetches and replaces', () async {
    final expiring = CachedValue<_Thing>(
      store: DriftCacheStore(db),
      namespace: 'thing',
      ttl: Duration.zero,
      decode: _Thing.fromJson,
      encode: (t) => t.toJson(),
    );
    await expiring.read('k', fetch: () async => const _Thing('old'));
    final got = await expiring.read('k', fetch: () async => const _Thing('new'));
    expect(got!.name, 'new');
  });

  test('an offline error on refetch serves the stale row', () async {
    final expiring = CachedValue<_Thing>(
      store: DriftCacheStore(db),
      namespace: 'thing',
      ttl: Duration.zero,
      decode: _Thing.fromJson,
      encode: (t) => t.toJson(),
    );
    await expiring.read('k', fetch: () async => const _Thing('old'));

    final got = await expiring.read('k',
        fetch: () async => throw const SocketException('offline'));

    expect(got!.name, 'old');
  });

  test('a server error rethrows and does NOT serve stale', () async {
    final expiring = CachedValue<_Thing>(
      store: DriftCacheStore(db),
      namespace: 'thing',
      ttl: Duration.zero,
      decode: _Thing.fromJson,
      encode: (t) => t.toJson(),
    );
    await expiring.read('k', fetch: () async => const _Thing('old'));

    expect(
      () => expiring.read('k', fetch: () async => throw StateError('boom')),
      throwsA(isA<StateError>()),
      reason: 'serving stale for a server error hides the bug forever',
    );
  });

  test('an offline error with nothing cached rethrows', () async {
    expect(
      () => cached.read('k', fetch: () async => throw const SocketException('offline')),
      throwsA(isA<SocketException>()),
    );
  });

  test('peek never fetches', () async {
    var calls = 0;
    expect(await cached.peek('absent'), isNull);
    expect(calls, 0);
  });

  test('keys do not leak across each other', () async {
    await cached.read('u1', fetch: () async => const _Thing('one'));
    await cached.read('u2', fetch: () async => const _Thing('two'));
    expect((await cached.peek('u1'))!.name, 'one');
    expect((await cached.peek('u2'))!.name, 'two');
  });

  test('invalidate forces the next read to fetch', () async {
    await cached.read('k', fetch: () async => const _Thing('first'));
    await cached.invalidate('k');
    final got = await cached.read('k', fetch: () async => const _Thing('second'));
    expect(got!.name, 'second');
  });

  test('a corrupt payload is treated as a miss, not an error', () async {
    await DriftCacheStore(db).write('thing', 'k', 'not json at all');
    final got = await cached.read('k', fetch: () async => const _Thing('recovered'));
    expect(got!.name, 'recovered');
  });

  test('a null fetch result clears the row', () async {
    await cached.read('k', fetch: () async => const _Thing('first'));
    await cached.invalidate('k');
    final got = await cached.read('k', fetch: () async => null);
    expect(got, isNull);
    expect(await cached.peek('k'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/core && fvm flutter test test/cache/cached_value_test.dart
```

Expected: FAIL — `CachedValue` is undefined.

- [ ] **Step 3: Implement**

`packages/core/lib/src/cache/cached_value.dart`:

```dart
import 'dart:convert';

import '../network/offline.dart';
import 'cache_store.dart';

/// One typed value per key, refreshed on read, kept when the refresh fails
/// because the device is offline.
///
/// The two failure clauses are the whole point, and they are what a hand-rolled
/// cache gets wrong: falling back on a bare `catch` makes a 500 or a malformed
/// body indistinguishable from being offline, and the caller then serves stale
/// data forever without anything looking broken.
class CachedValue<T> {
  const CachedValue({
    required CacheStore store,
    required String namespace,
    required Duration ttl,
    required T Function(Map<String, dynamic>) decode,
    required Map<String, dynamic> Function(T) encode,
  })  : _store = store,
        _namespace = namespace,
        _ttl = ttl,
        _decode = decode,
        _encode = encode;

  final CacheStore _store;
  final String _namespace;
  final Duration _ttl;
  final T Function(Map<String, dynamic>) _decode;
  final Map<String, dynamic> Function(T) _encode;

  /// Fresh row → returned without touching the network.
  /// Stale or absent → [fetch] runs; its result is retained and returned.
  /// [fetch] throws and `isOfflineError` → the stale row at any age, or a
  /// rethrow when there is nothing retained.
  /// [fetch] throws anything else → rethrow, and the retained row is left
  /// alone rather than served.
  Future<T?> read(String key, {required Future<T?> Function() fetch}) async {
    final row = await _store.read(_namespace, key);
    final retained = row == null ? null : _tryDecode(row.payload);

    if (row != null && retained != null && row.isFresh(_ttl)) return retained;

    try {
      final fresh = await fetch();
      if (fresh == null) {
        await _store.delete(_namespace, key);
        return null;
      }
      await _store.write(_namespace, key, jsonEncode(_encode(fresh)));
      return fresh;
    } catch (e) {
      if (retained != null && isOfflineError(e)) return retained;
      rethrow;
    }
  }

  /// The retained value, whatever its age. Never fetches.
  Future<T?> peek(String key) async {
    final row = await _store.read(_namespace, key);
    return row == null ? null : _tryDecode(row.payload);
  }

  Future<void> invalidate(String key) => _store.delete(_namespace, key);

  Future<void> invalidateAll() => _store.clearNamespace(_namespace);

  /// A payload this build can no longer read — a shape change across an app
  /// upgrade, or corruption — is a miss, not an error. Throwing here would
  /// make a schema change brick the screen until the user reinstalled.
  T? _tryDecode(String payload) {
    try {
      return _decode(jsonDecode(payload) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 4: Export from the barrel**

Add to `packages/core/lib/core.dart` beside the other cache exports:

```dart
export 'src/cache/cached_value.dart';
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd packages/core && fvm flutter test test/cache/ && fvm flutter analyze --no-fatal-infos
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/core/lib/src/cache/cached_value.dart packages/core/lib/core.dart \
        packages/core/test/cache/cached_value_test.dart
git commit -m "[Core] CachedValue: stale fallback for connectivity errors only"
```

---

### Task 4: Wire the cache store into bootstrap

**Files:**
- Modify: `app/lib/brands/balsm/main_balsm.dart` (override `cacheStoreProvider`; clear cache on sign-out)

**Interfaces:**
- Consumes: `cacheStoreProvider`, `DriftCacheStore` (Task 1); `appDatabaseProvider`.
- Produces: a bound `cacheStoreProvider` every later task depends on.

- [ ] **Step 1: Bind the provider**

In `app/lib/brands/balsm/main_balsm.dart`, in the same `overrides` list that already contains `readAccountRepositoryProvider.overrideWith(buildAccountAdapter)` (around line 90), add:

```dart
cacheStoreProvider.overrideWith((ref) => DriftCacheStore(ref.watch(appDatabaseProvider))),
```

If the surrounding list uses `overrideWithValue` and an already-constructed database, match that style instead — read the file and follow what is there.

- [ ] **Step 2: Clear the cache on sign-out**

Find where sign-out wipes tokens (search the file for the existing secure-storage clear and for `SessionExpired`). Add, in the same place:

```dart
// Cached read models are per-account. Leaving them would show the previous
// user's handle to the next one on the same device.
await container.read(cacheStoreProvider).clearAll();
```

`clearAll` rather than a per-namespace clear: every namespace this project introduces is account-scoped or public reference data, and both are safe to drop at sign-out.

- [ ] **Step 3: Verify the app still builds**

```bash
cd app && fvm flutter analyze --no-fatal-infos
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add app/lib/brands/balsm/main_balsm.dart
git commit -m "[App] Bind the cache store and clear it on sign-out"
```

---

### Task 5: Account summary survives being offline

**Files:**
- Modify: `modules/account/lib/src/infrastructure/api/balsm_account_adapter.dart`
- Test: `modules/account/test/infrastructure/balsm_account_adapter_test.dart`

**Interfaces:**
- Consumes: `CachedValue<AccountSummary>`, `cacheStoreProvider`, `isOfflineError`.
- Produces: `BalsmAccountAdapter(AccountApi api, CachedValue<AccountSummary> cache)` — note the added second positional parameter; `buildAccountAdapter(Ref)` keeps its signature.

**Existing behaviour to preserve:** `getAccount` returns `null` when the API returns null; `watchAccount` yields the current value then re-emits on the internal controller; `dispose` closes the controller.

- [ ] **Step 1: Write the failing test**

`modules/account/test/infrastructure/balsm_account_adapter_test.dart`:

```dart
import 'dart:io';

import 'package:account/account.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Synthetic identifiers only — never real user data.
AccountSelfResponse _response({String handle = 'sara'}) => AccountSelfResponse(
      id: '00000000-0000-0000-0000-0000000000a1',
      handle: handle,
      displayName: 'Test Person',
      countryCode: 'EG',
      preferredLanguage: 'ar',
      deletionState: 'ACTIVE',
    );

class _FakeAccountApi implements AccountApi {
  _FakeAccountApi(this.behaviour);
  Future<AccountSelfResponse?> Function() behaviour;
  int calls = 0;

  @override
  Future<AccountSelfResponse?> getSelf({CancelToken? cancelToken}) {
    calls++;
    return behaviour();
  }

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late AppDatabase db;
  late CacheStore store;

  CachedValue<AccountSummary> cacheFor(Duration ttl) => CachedValue<AccountSummary>(
        store: store,
        namespace: 'account',
        ttl: ttl,
        decode: AccountSummary.fromJson,
        encode: (s) => s.toJson(),
      );

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    store = DriftCacheStore(db);
  });
  tearDown(() => db.close());

  test('serves the cached summary when offline', () async {
    final api = _FakeAccountApi(() async => _response());
    final adapter = BalsmAccountAdapter(api, cacheFor(Duration.zero));
    addTearDown(adapter.dispose);

    final first = await adapter.getAccount('u1');
    expect(first!.handle, 'sara');

    api.behaviour = () async => throw const SocketException('offline');
    final second = await adapter.getAccount('u1');

    expect(second!.handle, 'sara', reason: 'offline must fall back to the retained summary');
  });

  test('a 401 clears the cache and rethrows', () async {
    final api = _FakeAccountApi(() async => _response());
    final adapter = BalsmAccountAdapter(api, cacheFor(Duration.zero));
    addTearDown(adapter.dispose);
    await adapter.getAccount('u1');

    api.behaviour = () async => throw DioException(
          requestOptions: RequestOptions(path: '/account/self'),
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: RequestOptions(path: '/account/self'), statusCode: 401),
        );

    await expectLater(() => adapter.getAccount('u1'), throwsA(isA<DioException>()));
    expect(await store.read('account', 'u1'), isNull,
        reason: 'a rejected session must not keep serving a cached identity');
  });

  test('one account never sees another account cached row', () async {
    final api = _FakeAccountApi(() async => _response(handle: 'first'));
    final adapter = BalsmAccountAdapter(api, cacheFor(const Duration(hours: 1)));
    addTearDown(adapter.dispose);

    await adapter.getAccount('u1');
    api.behaviour = () async => _response(handle: 'second');
    final other = await adapter.getAccount('u2');

    expect(other!.handle, 'second');
  });

  test('a fresh cache does not call the API', () async {
    final api = _FakeAccountApi(() async => _response());
    final adapter = BalsmAccountAdapter(api, cacheFor(const Duration(hours: 1)));
    addTearDown(adapter.dispose);

    await adapter.getAccount('u1');
    await adapter.getAccount('u1');

    expect(api.calls, 1);
  });
}
```

If `AccountSelfResponse`'s constructor parameters differ, read `packages/balsm_api/lib/src/account/` and correct the fixture. If `AccountApi` has more methods than `getSelf`, make `_FakeAccountApi` extend a `Fake` from `package:mocktail` if the module already depends on it — otherwise implement the extra methods as `throw UnimplementedError()`.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd modules/account && fvm flutter test test/infrastructure/balsm_account_adapter_test.dart
```

Expected: FAIL — `BalsmAccountAdapter` takes one argument.

- [ ] **Step 3: Implement**

Rewrite `modules/account/lib/src/infrastructure/api/balsm_account_adapter.dart`:

```dart
import 'dart:async';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long a retained summary is used without asking the server.
///
/// An hour, not a day: the summary changes only when the user changes it, and
/// every mutation path already invalidates this cache explicitly. The TTL is
/// the backstop for a change made on another device.
const _accountTtl = Duration(hours: 1);

const _accountNamespace = 'account';

/// .NET REST adapter for the account read-model.
///
/// Anti-corruption layer: maps [AccountSelfResponse] → [AccountSummary].
/// PHI rule: never logs the response body (it may contain user identifiers);
/// only structural failures are surfaced as typed [AppFailure]s upstream.
///
/// Retains the summary so settings, language and country screens render
/// offline. Keyed by user id — a second account on this device must never be
/// shown the first one's handle.
class BalsmAccountAdapter implements ReadAccountRepository {
  BalsmAccountAdapter(this._api, this._cache);

  final AccountApi _api;
  final CachedValue<AccountSummary> _cache;

  /// Local fan-out so [watchAccount] re-emits after mutations re-fetch.
  final _controller = StreamController<AccountSummary>.broadcast();

  @override
  Future<AccountSummary?> getAccount(String userId) async {
    final AccountSummary? summary;
    try {
      summary = await _cache.read(userId, fetch: () async {
        final res = await _api.getSelf();
        if (res == null) return null;
        return AccountSummary(
          id: UserId.value(res.id),
          handle: res.handle,
          displayName: res.displayName,
          countryCode: res.countryCode,
          preferredLanguage: res.preferredLanguage,
          deletionState: res.deletionState,
        );
      });
    } catch (e) {
      // A rejected session must not keep serving a cached identity. The
      // interceptor will sign out; drop the row first so nothing races it.
      if (_isRejection(e)) await _cache.invalidate(userId);
      rethrow;
    }

    if (summary != null && !_controller.isClosed) _controller.add(summary);
    return summary;
  }

  @override
  Stream<AccountSummary> watchAccount(String userId) async* {
    final current = await getAccount(userId);
    if (current != null) yield current;
    yield* _controller.stream;
  }

  /// Drops the retained summary — called when a mutation has changed it.
  /// Declared on [ReadAccountRepository] so callers reach it through the port.
  @override
  Future<void> refresh(String userId) => _cache.invalidate(userId);

  void dispose() => _controller.close();

  static bool _isRejection(Object e) {
    if (e is! DioException) return false;
    final status = e.response?.statusCode;
    return status == 401 || status == 403;
  }
}

/// Builds the account read-repository from the typed account client. The app
/// composition root binds this into core's `readAccountRepositoryProvider`
/// (see `bootstrap()`), so consumers depend on the core port, not this module.
BalsmAccountAdapter buildAccountAdapter(Ref ref) {
  final adapter = BalsmAccountAdapter(
    ref.watch(accountApiProvider),
    CachedValue<AccountSummary>(
      store: ref.watch(cacheStoreProvider),
      namespace: _accountNamespace,
      ttl: _accountTtl,
      decode: AccountSummary.fromJson,
      encode: (s) => s.toJson(),
    ),
  );
  ref.onDispose(adapter.dispose);
  return adapter;
}
```

- [ ] **Step 4: Make provider invalidation reach the cache**

`accountSummaryProvider` calls `getAccount('self')`. Five call sites invalidate that provider after a mutation (`language_settings_screen.dart:49`, `country_settings_screen.dart:46`, `handle_claim_screen.dart:123`, `auth_flow.dart:1096`, `main_balsm.dart:183`). Without this step each one re-reads the same fresh cache row and the user's change appears not to have happened.

In `packages/core/lib/src/contracts/account_read_providers.dart`, leave `accountSummaryProvider` as it is and add beneath it:

```dart
/// Drops the retained summary AND rebuilds the provider.
///
/// `ref.invalidate(accountSummaryProvider)` alone is not enough: the provider
/// re-runs, reads the still-fresh cache row, and the change the user just made
/// does not appear.
Future<void> refreshAccountSummary(WidgetRef ref) async {
  await ref.read(readAccountRepositoryProvider).refresh('self');
  ref.invalidate(accountSummaryProvider);
}
```

Add `Future<void> refresh(String userId);` to the `ReadAccountRepository` interface (in `packages/core/lib/src/contracts/`). `BalsmAccountAdapter` already implements it in Step 3. Every other implementation must gain it too — search for `implements ReadAccountRepository` across `packages/core/lib/src/test_kit/` and `modules/`, and give fakes `Future<void> refresh(String userId) async {}`.

Replace the five `ref.invalidate(accountSummaryProvider)` call sites with `await refreshAccountSummary(ref)`. `main_balsm.dart:183` uses a `ProviderContainer`, not a `WidgetRef` — there, call `container.read(readAccountRepositoryProvider).refresh('self')` then `container.invalidate(accountSummaryProvider)` directly.

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd modules/account && fvm flutter test && fvm flutter analyze --no-fatal-infos
cd ../../packages/core && fvm flutter test && fvm flutter analyze --no-fatal-infos
cd ../../app && fvm flutter analyze --no-fatal-infos
```

Expected: PASS everywhere.

- [ ] **Step 6: Commit**

```bash
git add modules/account packages/core/lib/src/contracts packages/core/lib/src/test_kit \
        app/lib/balsm_app/screens/auth_flow.dart app/lib/brands/balsm/main_balsm.dart
git commit -m "[Account] Keep the account summary readable offline"
```

---

### Task 6: Move the geofence deny list onto the shared cache

**Files:**
- Modify: `modules/geofence_block/lib/src/infrastructure/api/balsm_geofence_adapter.dart`
- Test: `modules/geofence_block/test/infrastructure/balsm_geofence_adapter_test.dart`

**Interfaces:**
- Consumes: `CachedValue`, `cacheStoreProvider`, `SecureStorageWrapper`.
- Produces: `BalsmGeofenceAdapter({required GeofenceApi api, required CachedValue<List<String>> cache, required SecureStorageWrapper legacyStorage})`.

**Behaviour that must not change:** 24h TTL; `isDenied` normalises to trimmed uppercase and returns `false` for an empty code; a stale list is still enforced when offline.

**Behaviour that must change:** the current `catch (_)` swallows every error, so a 500 or a malformed body silently serves stale data forever and an empty list on first run. Only `isOfflineError` may fall back.

- [ ] **Step 1: Write the failing test**

`modules/geofence_block/test/infrastructure/balsm_geofence_adapter_test.dart`:

```dart
import 'dart:io';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geofence_block/geofence_block.dart';

class _FakeGeofenceApi implements GeofenceApi {
  _FakeGeofenceApi(this.behaviour);
  Future<DeniedCountriesResponse> Function() behaviour;

  @override
  Future<DeniedCountriesResponse> getDeniedCountries({CancelToken? cancelToken}) => behaviour();

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late AppDatabase db;

  CachedValue<List<String>> cacheFor(Duration ttl) => CachedValue<List<String>>(
        store: DriftCacheStore(db),
        namespace: 'geofence',
        ttl: ttl,
        decode: (j) => (j['codes'] as List).map((e) => e.toString()).toList(growable: false),
        encode: (codes) => {'codes': codes},
      );

  setUp(() => db = AppDatabase(DatabaseConnection(NativeDatabase.memory())));
  tearDown(() => db.close());

  test('normalises the queried code', () async {
    final api = _FakeGeofenceApi(() async => DeniedCountriesResponse(deniedCodes: ['il']));
    final a = BalsmGeofenceAdapter(
      api: api,
      cache: cacheFor(const Duration(hours: 24)),
      legacyStorage: SecureStorageWrapper(),
    );
    expect(await a.isDenied(' il '), isTrue);
    expect(await a.isDenied(''), isFalse);
  });

  test('an offline refetch keeps enforcing the stale list', () async {
    final api = _FakeGeofenceApi(() async => DeniedCountriesResponse(deniedCodes: ['IL']));
    final a = BalsmGeofenceAdapter(
      api: api,
      cache: cacheFor(Duration.zero),
      legacyStorage: SecureStorageWrapper(),
    );
    expect(await a.isDenied('IL'), isTrue);

    api.behaviour = () async => throw const SocketException('offline');
    expect(await a.isDenied('IL'), isTrue,
        reason: 'a known block must survive losing the network');
  });

  test('a server error does not silently serve stale', () async {
    final api = _FakeGeofenceApi(() async => DeniedCountriesResponse(deniedCodes: ['IL']));
    final a = BalsmGeofenceAdapter(
      api: api,
      cache: cacheFor(Duration.zero),
      legacyStorage: SecureStorageWrapper(),
    );
    await a.isDenied('IL');

    api.behaviour = () async => throw StateError('500');
    await expectLater(() => a.isDenied('IL'), throwsA(isA<StateError>()));
  });
}
```

If `DeniedCountriesResponse`'s field is not `deniedCodes`, read `packages/balsm_api/lib/src/geofence/` and correct the fixture.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd modules/geofence_block && fvm flutter test
```

Expected: FAIL — the constructor does not take `cache`.

- [ ] **Step 3: Implement**

In `modules/geofence_block/lib/src/infrastructure/api/balsm_geofence_adapter.dart`, delete `_cacheKey`, `_readCache`, `_writeCache` and `class _CachedDenyList`, and replace the class body's cache handling:

```dart
/// SecureStorage key this adapter used before the shared cache tier existed.
/// Read never, deleted once — orphaned keychain entries survive an uninstall
/// on iOS, so leaving it behind would outlive the app.
const _legacyCacheKey = 'balsm.denied_countries_cache';

/// How long a cached deny list is considered fresh.
const _cacheTtl = Duration(hours: 24);

const _geofenceNamespace = 'geofence';
const _denyListKey = 'denied_countries';

class BalsmGeofenceAdapter implements ReadDeniedCountriesRepository {
  BalsmGeofenceAdapter({
    required GeofenceApi api,
    required CachedValue<List<String>> cache,
    required SecureStorageWrapper legacyStorage,
  })  : _api = api,
        _cache = cache,
        _legacyStorage = legacyStorage;

  final GeofenceApi _api;
  final CachedValue<List<String>> _cache;
  final SecureStorageWrapper _legacyStorage;

  bool _purgedLegacy = false;

  @override
  Future<bool> isDenied(String countryCode) async {
    final normalized = countryCode.trim().toUpperCase();
    if (normalized.isEmpty) return false;
    return (await _deniedCountryCodes()).contains(normalized);
  }

  @override
  Stream<List<String>> watchDeniedCountryCodes() async* {
    yield await _deniedCountryCodes();
  }

  Future<List<String>> _deniedCountryCodes() async {
    await _purgeLegacyCache();
    final codes = await _cache.read(_denyListKey, fetch: _fetch);
    return codes ?? const <String>[];
  }

  Future<List<String>> _fetch() async {
    final res = await _api.getDeniedCountries();
    return res.deniedCodes
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// One-shot cleanup of the pre-migration SecureStorage entry.
  Future<void> _purgeLegacyCache() async {
    if (_purgedLegacy) return;
    _purgedLegacy = true;
    try {
      await _legacyStorage.deleteToken(_legacyCacheKey);
    } catch (_) {
      // Keychain unavailable — retrying next launch is fine, and failing to
      // delete a stale country list must never block the geofence check.
    }
  }
}
```

Update `deniedCountriesRepositoryProvider` in the same file:

```dart
final deniedCountriesRepositoryProvider = Provider<ReadDeniedCountriesRepository>((ref) {
  return BalsmGeofenceAdapter(
    api: ref.watch(geofenceApiProvider),
    cache: CachedValue<List<String>>(
      store: ref.watch(cacheStoreProvider),
      namespace: _geofenceNamespace,
      ttl: _cacheTtl,
      decode: (j) => (j['codes'] as List).map((e) => e.toString()).toList(growable: false),
      encode: (codes) => {'codes': codes},
    ),
    legacyStorage: SecureStorageWrapper(),
  );
});
```

Read the existing provider body first and keep any arguments it passes that are not shown here.

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd modules/geofence_block && fvm flutter test && fvm flutter analyze --no-fatal-infos
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/geofence_block
git commit -m "[Geofence] Move the deny-list cache onto the shared tier"
```

---

### Task 7: Care directory cached to disk, with provenance

**Files:**
- Modify: `app/lib/balsm_app/care/ports/care_directory_repository.dart` (`CareResults`, `CarePinResults`, `pins`, `byId`)
- Modify: `app/lib/balsm_app/care/ports/care_directory_data_source.dart` (`pins`, `byId` on both ports)
- Modify: `app/lib/balsm_app/care/ports/care_query_id.dart` (add `CarePinQueryId`, `CareEntityId`)
- Create: `app/lib/balsm_app/care/infrastructure/drift_care_directory_data_source.dart`
- Delete: `app/lib/balsm_app/care/infrastructure/memory_care_directory_data_source.dart`
- Modify: `app/lib/balsm_app/care/infrastructure/api_care_directory_data_source.dart` (implement `pins`, `byId`)
- Modify: `app/lib/balsm_app/care/infrastructure/caching_care_directory_repository.dart`
- Modify: `app/lib/balsm_app/care/care_entity.dart` (providers)
- Modify: `app/lib/balsm_app/screens/map_screen.dart:187,299`, `app/lib/balsm_app/screens/home_screen.dart:272`
- Test: `app/test/care/caching_care_directory_repository_test.dart`

**Interfaces:**
- Consumes: `CacheStore`, `cacheStoreProvider`, `isOfflineError`.
- Produces: `CareResults({required List<CareEntity> entities, required bool stale})`; `CarePinResults({required List<CarePin> pins, required bool stale})`; `CareDirectoryRepository.nearby → Future<CareResults>`, `.pins → Future<CarePinResults>`, `.byId(String) → Future<CareEntity?>`; `careDirectoryProvider → FutureProvider<CareResults>`; `carePinsProvider → FutureProvider<CarePinResults>`.

**The bug this fixes:** `carePinsProvider` and `careEntityProvider` in `care_entity.dart` call `ref.watch(careDirectoryApiProvider)` directly, bypassing the repository. The pins the user actually sees on the map have never been cached at all. Route both through the repository.

**Keys must not collide.** `CareQueryId.of` covers the list query. Pins take a different limit and honour the `kFlagMapNoZoomFloor` dev flag, so `CarePinQueryId.of(center, search, {required bool noFloor})` must include the radius, limit and flag actually sent. Sharing one key would serve a list response to the map and vice versa.

- [ ] **Step 1: Write the failing test**

`app/test/care/caching_care_directory_repository_test.dart`:

```dart
import 'dart:io';

import 'package:app/balsm_app/care/care_entity.dart';
import 'package:app/balsm_app/care/infrastructure/caching_care_directory_repository.dart';
import 'package:app/balsm_app/care/infrastructure/drift_care_directory_data_source.dart';
import 'package:app/balsm_app/care/ports/care_directory_data_source.dart';
import 'package:balsm_api/balsm_api.dart' show CancelToken;
import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Synthetic place — the directory is public reference data, never PHI.
CareEntity _place(String name) => CareEntity(
      id: 'id-$name',
      name: name,
      type: CareEntityType.pharmacy,
      lat: 30.0,
      lng: 31.0,
    );

class _FakeRemote implements RemoteCareDirectoryDataSource {
  _FakeRemote(this.behaviour);
  Future<List<CareEntity>> Function() behaviour;
  int calls = 0;

  @override
  Future<List<CareEntity>> nearby(LatLng c, CareSearch s, {CancelToken? cancelToken}) {
    calls++;
    return behaviour();
  }

  @override
  Future<List<CarePin>> pins(LatLng c, CareSearch s, {bool noFloor = false, CancelToken? cancelToken}) async =>
      const [];

  @override
  Future<CareEntity?> byId(String id, LatLng c, {CancelToken? cancelToken}) async => null;
}

void main() {
  late AppDatabase db;
  const center = LatLng(30.0, 31.0);
  final search = const CareSearch();

  CachingCareDirectoryRepository repoWith(_FakeRemote remote, Duration ttl) =>
      CachingCareDirectoryRepository(
        remote: remote,
        local: DriftCareDirectoryDataSource(store: DriftCacheStore(db), ttl: ttl),
      );

  setUp(() => db = AppDatabase(DatabaseConnection(NativeDatabase.memory())));
  tearDown(() => db.close());

  test('a fresh retained result is not refetched', () async {
    final remote = _FakeRemote(() async => [_place('a')]);
    final repo = repoWith(remote, const Duration(days: 7));

    await repo.nearby(center, search);
    final again = await repo.nearby(center, search);

    expect(remote.calls, 1);
    expect(again.entities.single.name, 'a');
    expect(again.stale, isFalse);
  });

  test('a result survives a restart', () async {
    final remote = _FakeRemote(() async => [_place('a')]);
    await repoWith(remote, const Duration(days: 7)).nearby(center, search);

    // A second repository over the same database is what a relaunch looks like.
    final afterRestart = repoWith(_FakeRemote(() async => throw StateError('should not fetch')),
        const Duration(days: 7));
    final got = await afterRestart.nearby(center, search);

    expect(got.entities.single.name, 'a');
  });

  test('an expired result is refetched and marked fresh', () async {
    final remote = _FakeRemote(() async => [_place('old')]);
    final repo = repoWith(remote, Duration.zero);
    await repo.nearby(center, search);

    remote.behaviour = () async => [_place('new')];
    final got = await repo.nearby(center, search);

    expect(got.entities.single.name, 'new');
    expect(got.stale, isFalse);
  });

  test('an offline refetch returns the expired result marked stale', () async {
    final remote = _FakeRemote(() async => [_place('old')]);
    final repo = repoWith(remote, Duration.zero);
    await repo.nearby(center, search);

    remote.behaviour = () async => throw const SocketException('offline');
    final got = await repo.nearby(center, search);

    expect(got.entities.single.name, 'old');
    expect(got.stale, isTrue, reason: 'the map notice reads this, not connectivity');
  });

  test('a failed fetch with nothing retained rethrows', () async {
    final repo = repoWith(_FakeRemote(() async => throw const SocketException('offline')), Duration.zero);
    expect(() => repo.nearby(center, search), throwsA(isA<SocketException>()));
  });

  test('a failed fetch is never retained', () async {
    final remote = _FakeRemote(() async => throw const SocketException('offline'));
    final repo = repoWith(remote, const Duration(days: 7));
    await expectLater(() => repo.nearby(center, search), throwsA(isA<SocketException>()));

    remote.behaviour = () async => [_place('real')];
    final got = await repo.nearby(center, search);
    expect(got.entities.single.name, 'real',
        reason: 'an error cached as an answer makes a blip look like an empty region');
  });

  test('the retained set is bounded', () async {
    final remote = _FakeRemote(() async => [_place('x')]);
    final local = DriftCareDirectoryDataSource(
      store: DriftCacheStore(db),
      ttl: const Duration(days: 7),
      maxEntries: 3,
    );
    final repo = CachingCareDirectoryRepository(remote: remote, local: local);

    for (var i = 0; i < 6; i++) {
      await repo.nearby(LatLng(30.0 + i, 31.0), search);
    }

    expect(await DriftCacheStore(db).readNamespace('care'), hasLength(3));
  });
}
```

`CareEntity`'s constructor and `CareSearch`'s defaults may differ — read `app/lib/balsm_app/care/care_entity.dart` and correct the fixtures. The assertions are what matter.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && fvm flutter test test/care/caching_care_directory_repository_test.dart
```

Expected: FAIL — `DriftCareDirectoryDataSource` is undefined and `nearby` returns a list.

- [ ] **Step 3: Add the result types and the new keys**

In `app/lib/balsm_app/care/ports/care_directory_repository.dart`:

```dart
/// Directory results plus where they came from.
///
/// Staleness travels with the data rather than being inferred in the UI from
/// connectivity: `onlineProvider` reports whether an interface is up, not
/// whether these particular rows are old.
class CareResults {
  const CareResults({required this.entities, required this.stale});
  const CareResults.fresh(this.entities) : stale = false;

  final List<CareEntity> entities;

  /// True when these came from a retained row past its TTL because the
  /// refetch failed for want of a connection.
  final bool stale;
}

class CarePinResults {
  const CarePinResults({required this.pins, required this.stale});
  const CarePinResults.fresh(this.pins) : stale = false;

  final List<CarePin> pins;
  final bool stale;
}

abstract interface class CareDirectoryRepository {
  Future<CareResults> nearby(LatLng center, CareSearch search, {CancelToken? cancelToken});

  /// Map pins for [search]. [noFloor] mirrors the `kFlagMapNoZoomFloor` dev
  /// flag and changes both the request and its cache key.
  Future<CarePinResults> pins(
    LatLng center,
    CareSearch search, {
    bool noFloor = false,
    CancelToken? cancelToken,
  });

  /// Full detail for one place. No staleness flag — a detail sheet opened from
  /// a stale pin is already covered by the map's notice.
  Future<CareEntity?> byId(String id, LatLng center, {CancelToken? cancelToken});
}
```

In `app/lib/balsm_app/care/ports/care_query_id.dart`, add beside `CareQueryId`:

```dart
/// Typed id of one PIN query.
///
/// Separate from [CareQueryId] because the pins endpoint takes a different
/// limit and honours the no-zoom-floor dev flag: one key for both would serve
/// a list response to the map and a pin response to the list.
class CarePinQueryId extends UniqueId {
  const CarePinQueryId.value(super.value) : super.value();
  const CarePinQueryId.empty() : super.empty();

  factory CarePinQueryId.of(LatLng center, CareSearch search, {required bool noFloor}) =>
      CarePinQueryId.value([
        'pins',
        center.latitude.toStringAsFixed(kCareCenterPrecision),
        center.longitude.toStringAsFixed(kCareCenterPrecision),
        (noFloor ? kCareMaxRadiusKm : search.radiusKm).toStringAsFixed(1),
        search.wireType ?? '',
        search.text.trim().toLowerCase(),
        noFloor ? kCarePinLimitMax : kCarePinLimit,
      ].join('|'));
}

/// Typed id of one place-detail lookup.
class CareEntityId extends UniqueId {
  const CareEntityId.value(super.value) : super.value();
  const CareEntityId.empty() : super.empty();

  factory CareEntityId.of(String id) => CareEntityId.value('entity|$id');
}
```

- [ ] **Step 4: Extend both data-source ports**

In `app/lib/balsm_app/care/ports/care_directory_data_source.dart`, add to `RemoteCareDirectoryDataSource`:

```dart
  /// Map pins near [center]. [noFloor] lifts the zoom floor, the radius and
  /// the pin cap together — see `kFlagMapNoZoomFloor`.
  Future<List<CarePin>> pins(
    LatLng center,
    CareSearch search, {
    bool noFloor = false,
    CancelToken? cancelToken,
  });

  /// Full detail for one place. Null when it has left the directory since the
  /// pin was drawn.
  Future<CareEntity?> byId(String id, LatLng center, {CancelToken? cancelToken});
```

Replace the single `LocalCareDirectoryDataSource` declaration with three, so each key type stays typed:

```dart
/// Locally retained directory results, keyed by the query that produced them.
///
/// A core [DataSource]: unscoped, because the directory is public reference
/// data with no partition — it belongs to no profile and no account, unlike the
/// PHI sources that use [ProfileDataSource] / [UserDataSource]. Nothing stored
/// here is PHI, which is also why it need not participate in backup or wipe.
///
/// Retention policy — bounded size, TTL — is the implementation's own, exactly
/// as the base contract intends: policies are not part of the generic shape.
///
/// [findRow] exposes the fetch time alongside the value, which plain `find`
/// cannot: the repository needs to know whether a hit is expired before it
/// decides to refetch.
abstract class LocalCareDirectoryDataSource extends DataSource<CareQueryId, List<CareEntity>> {
  Future<({List<CareEntity> value, bool expired})?> findRow(CareQueryId key);

  Future<({List<CarePin> value, bool expired})?> findPins(CarePinQueryId key);
  Future<void> putPins(CarePinQueryId key, List<CarePin> value);

  Future<CareEntity?> findEntity(CareEntityId key);
  Future<void> putEntity(CareEntityId key, CareEntity value);
}
```

- [ ] **Step 5: Implement the drift-backed local source**

Create `app/lib/balsm_app/care/infrastructure/drift_care_directory_data_source.dart`. Delete `memory_care_directory_data_source.dart`.

```dart
import 'dart:convert';

import 'package:core/core.dart';

import '../care_cache.dart';
import '../care_entity.dart';
import '../ports/care_directory_data_source.dart';
import '../ports/care_query_id.dart';

/// How long a retained directory result is used before a refetch is attempted.
///
/// The directory is refreshed server-side by re-import, so a result can outlive
/// a facility that has closed. Seven days bounds that; the map's stale notice
/// discloses it. The governorate-pack project replaces this with versioned data
/// carrying a real "as of" date, at which point revisit the number.
const _careTtl = Duration(days: 7);

/// Retained query results, evicting least-recently-fetched beyond this.
const _careMaxEntries = 200;

const _careNamespace = 'care';

/// [LocalCareDirectoryDataSource] over the shared `cache_entry` table, with an
/// in-memory tier in front.
///
/// Two tiers because they answer different questions. The memory tier (LRU by
/// access) makes a repeated pan within one session cost no I/O. The database
/// tier (evicting by fetch time, the only timestamp a row carries) is what
/// survives a relaunch — the whole reason this replaced the memory-only source.
class DriftCareDirectoryDataSource extends LocalCareDirectoryDataSource {
  DriftCareDirectoryDataSource({
    required CacheStore store,
    Duration ttl = _careTtl,
    int maxEntries = _careMaxEntries,
    CareDirectoryCache? memory,
  })  : _store = store,
        _ttl = ttl,
        _maxEntries = maxEntries,
        _memory = memory ?? CareDirectoryCache();

  final CacheStore _store;
  final Duration _ttl;
  final int _maxEntries;
  final CareDirectoryCache _memory;

  @override
  Future<({List<CareEntity> value, bool expired})?> findRow(CareQueryId key) async {
    final hot = _memory.get(key.value);
    if (hot != null) return (value: hot, expired: false);

    final row = await _store.read(_careNamespace, key.value);
    if (row == null) return null;
    final decoded = _decodeList(row.payload, CareEntity.fromJson);
    if (decoded == null) return null;
    if (!row.isFresh(_ttl)) return (value: decoded, expired: true);

    _memory.put(key.value, decoded);
    return (value: decoded, expired: false);
  }

  @override
  Future<List<CareEntity>?> find(CareQueryId key) async => (await findRow(key))?.value;

  @override
  Future<void> put(CareQueryId key, List<CareEntity> value) async {
    _memory.put(key.value, value);
    await _write(key.value, value.map((e) => e.toJson()).toList(growable: false));
  }

  @override
  Future<({List<CarePin> value, bool expired})?> findPins(CarePinQueryId key) async {
    final row = await _store.read(_careNamespace, key.value);
    if (row == null) return null;
    final decoded = _decodeList(row.payload, CarePin.fromJson);
    if (decoded == null) return null;
    return (value: decoded, expired: !row.isFresh(_ttl));
  }

  @override
  Future<void> putPins(CarePinQueryId key, List<CarePin> value) =>
      _write(key.value, value.map((e) => e.toJson()).toList(growable: false));

  @override
  Future<CareEntity?> findEntity(CareEntityId key) async {
    final row = await _store.read(_careNamespace, key.value);
    if (row == null || !row.isFresh(_ttl)) return null;
    try {
      return CareEntity.fromJson(jsonDecode(row.payload) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> putEntity(CareEntityId key, CareEntity value) async {
    await _store.write(_careNamespace, key.value, jsonEncode(value.toJson()));
    await _store.evictOldest(_careNamespace, keep: _maxEntries);
  }

  Future<void> _write(String key, List<Map<String, dynamic>> rows) async {
    await _store.write(_careNamespace, key, jsonEncode(rows));
    await _store.evictOldest(_careNamespace, keep: _maxEntries);
  }

  /// A payload this build can no longer read is a miss, not an error — a shape
  /// change across an app upgrade must not brick the map.
  List<T>? _decodeList<T>(String payload, T Function(Map<String, dynamic>) fromJson) {
    try {
      return (jsonDecode(payload) as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<List<CareEntity>>> findAll() async => _memory.values;

  @override
  Future<List<List<CareEntity>>> findMany(Iterable<CareQueryId> keys) async {
    final out = <List<CareEntity>>[];
    for (final k in keys) {
      final hit = await find(k);
      if (hit != null) out.add(hit);
    }
    return out;
  }

  @override
  Future<bool> exists(CareQueryId key) async => await find(key) != null;

  @override
  Future<void> putBulk(Map<CareQueryId, List<CareEntity>> values) async {
    for (final e in values.entries) {
      await put(e.key, e.value);
    }
  }

  @override
  Future<void> delete(CareQueryId key) async {
    _memory.remove(key.value);
    await _store.delete(_careNamespace, key.value);
  }

  @override
  Future<void> deleteMany(Iterable<CareQueryId> keys) async {
    for (final k in keys) {
      await delete(k);
    }
  }

  @override
  Future<void> clear() async {
    _memory.clear();
    await _store.clearNamespace(_careNamespace);
  }
}
```

If `CareEntity` and `CarePin` lack `toJson`/`fromJson`, add them in `care_entity.dart` — round-tripping every field the UI reads. Write a test asserting `CareEntity.fromJson(e.toJson())` equals `e` for a fully-populated synthetic value, including the nullable fields (`nameAr`, `phone`, `rating`).

If `CareDirectoryCache` has no `clear()`, add one.

- [ ] **Step 6: Implement `pins` and `byId` on the API data source**

In `app/lib/balsm_app/care/infrastructure/api_care_directory_data_source.dart`, add the two methods. Move the request-building code out of `carePinsProvider` and `careEntityProvider` in `care_entity.dart` verbatim — it already builds `CarePinsQuery` correctly, including the `noFloor` radius and limit swaps.

- [ ] **Step 7: Implement the repository**

Rewrite `app/lib/balsm_app/care/infrastructure/caching_care_directory_repository.dart`:

```dart
import 'package:balsm_api/balsm_api.dart' show CancelToken;
import 'package:core/core.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../care_entity.dart';
import '../ports/care_directory_data_source.dart';
import '../ports/care_directory_repository.dart';
import '../ports/care_query_id.dart';

/// [CareDirectoryRepository] that answers from the local data source when it
/// can and the remote one when it must.
///
/// Read-through, not write-back: a fresh hit returns immediately without
/// touching the network. The map re-queries on every settled pan, so panning
/// back over covered ground is the common case this exists for.
///
/// An expired hit attempts a refetch. If that refetch fails for want of a
/// connection, the expired value is returned marked `stale` — a map with
/// week-old pins beats a blank one, provided it says so. Any other failure
/// propagates: serving stale data for a 500 would hide the bug forever.
///
/// A failed remote call is NOT retained — an error must not be cached as if it
/// were an answer, or a transient network blip would look like an empty area
/// for the rest of the TTL.
class CachingCareDirectoryRepository implements CareDirectoryRepository {
  const CachingCareDirectoryRepository({
    required RemoteCareDirectoryDataSource remote,
    required LocalCareDirectoryDataSource local,
  })  : _remote = remote,
        _local = local;

  final RemoteCareDirectoryDataSource _remote;
  final LocalCareDirectoryDataSource _local;

  @override
  Future<CareResults> nearby(LatLng center, CareSearch search, {CancelToken? cancelToken}) async {
    final key = CareQueryId.of(center, search);
    final hit = await _local.findRow(key);
    if (hit != null && !hit.expired) return CareResults.fresh(hit.value);

    try {
      final fetched = await _remote.nearby(center, search, cancelToken: cancelToken);
      await _local.put(key, fetched);
      return CareResults.fresh(fetched);
    } catch (e) {
      if (hit != null && isOfflineError(e)) {
        return CareResults(entities: hit.value, stale: true);
      }
      rethrow;
    }
  }

  @override
  Future<CarePinResults> pins(
    LatLng center,
    CareSearch search, {
    bool noFloor = false,
    CancelToken? cancelToken,
  }) async {
    final key = CarePinQueryId.of(center, search, noFloor: noFloor);
    final hit = await _local.findPins(key);
    if (hit != null && !hit.expired) return CarePinResults.fresh(hit.value);

    try {
      final fetched = await _remote.pins(center, search, noFloor: noFloor, cancelToken: cancelToken);
      await _local.putPins(key, fetched);
      return CarePinResults.fresh(fetched);
    } catch (e) {
      if (hit != null && isOfflineError(e)) {
        return CarePinResults(pins: hit.value, stale: true);
      }
      rethrow;
    }
  }

  @override
  Future<CareEntity?> byId(String id, LatLng center, {CancelToken? cancelToken}) async {
    final key = CareEntityId.of(id);
    final hit = await _local.findEntity(key);
    if (hit != null) return hit;

    try {
      final fetched = await _remote.byId(id, center, cancelToken: cancelToken);
      if (fetched != null) await _local.putEntity(key, fetched);
      return fetched;
    } catch (e) {
      // Nothing retained and no connection: the sheet shows its own empty
      // state rather than an error, which is what a missing place looks like.
      if (isOfflineError(e)) return null;
      rethrow;
    }
  }
}
```

- [ ] **Step 8: Rewire the providers**

In `app/lib/balsm_app/care/care_entity.dart`:

```dart
final localCareDirectoryDataSourceProvider = Provider<LocalCareDirectoryDataSource>(
  (ref) => DriftCareDirectoryDataSource(store: ref.watch(cacheStoreProvider)),
);
```

`careDirectoryProvider` becomes `FutureProvider.autoDispose<CareResults>` and returns the repository's result unchanged. `carePinsProvider` becomes `FutureProvider.autoDispose<CarePinResults>` and calls `ref.watch(careDirectoryRepositoryProvider).pins(center, search, noFloor: noFloor, cancelToken: cancel)` instead of the API. `careEntityProvider` calls `.byId(id, center, cancelToken: cancel)`.

Keep every existing guard exactly as it is: the `tooZoomedOut` early return in both, the `noFloor` dev-flag read, `_withinCoverage`, `_roundCenter`, and the `ref.onDispose(cancel.cancel)` cancellation.

Update the three consumers:
- `map_screen.dart:187` → `ref.watch(careDirectoryProvider).valueOrNull?.entities ?? const <CareEntity>[]`
- `map_screen.dart:299` → `ref.watch(carePinsProvider).valueOrNull?.pins ?? const []`
- `home_screen.dart:272` → `(ref.watch(careDirectoryProvider).valueOrNull?.entities ?? const <CareEntity>[]).length`

- [ ] **Step 9: Run tests to verify they pass**

```bash
cd app && fvm flutter test test/care/ && fvm flutter analyze --no-fatal-infos
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add app/lib/balsm_app/care app/lib/balsm_app/screens/map_screen.dart \
        app/lib/balsm_app/screens/home_screen.dart app/test/care
git rm app/lib/balsm_app/care/infrastructure/memory_care_directory_data_source.dart
git commit -m "[Care] Retain directory results on disk and route pins through the cache"
```

---

### Task 8: Say when the app is offline

**Files:**
- Create: `packages/core/lib/src/kit/offline_banner.dart`
- Modify: `packages/core/lib/core.dart`
- Modify: `app/lib/balsm_app/i18n/strings.i69n.jsonc` and `strings_ar.i69n.jsonc`
- Modify: `app/lib/balsm_app/screens/map_screen.dart` (stale notice)
- Modify: `app/lib/balsm_app/shell.dart:320-328` (`_MainAppState.build`, mount the banner once)
- Modify: `modules/sessions/lib/src/presentation/screens/sessions_screen.dart:48-56` (offline empty state)
- Test: `packages/core/test/kit/offline_banner_test.dart`

**Interfaces:**
- Consumes: `onlineProvider` (Task 2); `CareResults.stale`, `CarePinResults.stale` (Task 7).
- Produces: `OfflineBanner` widget.

- [ ] **Step 1: Write the failing test**

`packages/core/test/kit/offline_banner_test.dart`:

```dart
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Stream<bool> online) => ProviderScope(
      overrides: [onlineProvider.overrideWith((ref) => online)],
      child: const MaterialApp(home: Scaffold(body: OfflineBanner(message: 'No connection'))),
    );

void main() {
  testWidgets('hidden while online', (t) async {
    await t.pumpWidget(_host(Stream.value(true)));
    await t.pump();
    expect(find.text('No connection'), findsNothing);
  });

  testWidgets('shown while offline', (t) async {
    await t.pumpWidget(_host(Stream.value(false)));
    await t.pump();
    expect(find.text('No connection'), findsOneWidget);
  });

  testWidgets('hidden before connectivity is known', (t) async {
    await t.pumpWidget(_host(const Stream<bool>.empty()));
    await t.pump();
    expect(find.text('No connection'), findsNothing,
        reason: 'an unknown state must not be reported as offline');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd packages/core && fvm flutter test test/kit/offline_banner_test.dart
```

Expected: FAIL — `OfflineBanner` is undefined.

- [ ] **Step 3: Implement the banner**

`packages/core/lib/src/kit/offline_banner.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/connectivity.dart';
import 'theme.dart';

/// A slim strip shown while no network interface is up.
///
/// Takes its [message] from the caller so the string stays in the app's i69n
/// bundles — core has no bundle of its own for this.
///
/// Shows nothing while connectivity is unknown: reporting "offline" during the
/// first frame, before `checkConnectivity` has answered, would flash on every
/// launch.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).valueOrNull;
    if (online != false) return const SizedBox.shrink();

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: T.amber100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 16, color: T.ink700),
            const SizedBox(width: 8),
            Flexible(child: Text(message, style: TextStyle(fontSize: 13, color: T.ink700))),
          ],
        ),
      ),
    );
  }
}
```

Read `packages/core/lib/src/kit/theme.dart` and substitute real token names for `T.amber100` / `T.ink700` — use whatever the design tokens actually call a warning background and a body-text ink.

- [ ] **Step 4: Add the strings**

Add to `app/lib/balsm_app/i18n/strings.i69n.jsonc`, inside whichever top-level group the surrounding shell strings use (read the file — i69n nests by group, so a bare top-level key will not generate the accessor the shell expects):

```json
"offline_banner": "You're offline — showing saved data",
"offline_stale_places": "These places may be out of date",
"offline_sessions": "Sign-in activity needs a connection",
"offline_write": "You're offline. This needs a connection."
```

The same keys in `strings_ar.i69n.jsonc`:

```json
"offline_banner": "لا يوجد اتصال — نعرض بيانات محفوظة",
"offline_stale_places": "قد تكون هذه الأماكن غير محدّثة",
"offline_sessions": "يحتاج سجل الدخول إلى اتصال",
"offline_write": "لا يوجد اتصال. هذا يحتاج إلى إنترنت."
```

Then regenerate:

```bash
cd app && fvm dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 5: Mount the banner and the stale notice**

In `app/lib/balsm_app/shell.dart`, `_MainAppState.build` ends with a `Stack` holding `content` and a `PositionedDirectional` `TopLoadingBar`. Add the banner to that same stack, below the loading bar so the bar stays on top:

```dart
return Stack(children: [
  content,
  PositionedDirectional(
    top: 0,
    start: 0,
    end: 0,
    child: OfflineBanner(message: s.strings.offline_banner),
  ),
  PositionedDirectional(
    top: 0,
    start: 0,
    end: 0,
    child: TopLoadingBar(loading: _navLoading, color: s.accent.main),
  ),
]);
```

This one mount covers both layouts — the phone Column and the tablet `_SideNav` Row are both inside `content`. Mounting per screen would stack duplicates.

`_MainAppState` is a `State`, not a `ConsumerState`. `OfflineBanner` is a `ConsumerWidget` and reads the provider itself, so no change to the host is needed — but confirm a `ProviderScope` is above it (it is: `PatientApp` is mounted under the root scope in `main_balsm.dart`).

In `map_screen.dart`, when `ref.watch(carePinsProvider).valueOrNull?.stale == true`, show `s.strings.offline_stale_places` in the existing notice area above the map.

In `modules/sessions/lib/src/presentation/screens/sessions_screen.dart`, the `sessionsAsync.when(...)` at line 48 renders `BalsmErrorBanner(... onRetry: () => ref.invalidate(sessionsProvider))` for every error. Branch on the cause:

```dart
error: (e, _) => Padding(
  padding: const EdgeInsets.all(16),
  child: isOfflineError(e)
      // A retry button that cannot succeed is worse than no button.
      ? BalsmEmptyState(message: s.strings.offline_sessions)
      : BalsmErrorBanner(
          message: /* keep whatever message the existing code passes */,
          onRetry: () => ref.invalidate(sessionsProvider),
        ),
),
```

Read the file for the exact existing `message:` argument and for the empty-state widget this codebase already uses — if there is no `BalsmEmptyState`, use a plain centred `Text` styled like the other empty states in `packages/core/lib/src/kit/shared_widgets.dart`.

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd packages/core && fvm flutter test && fvm flutter analyze --no-fatal-infos
cd ../../app && fvm flutter test && fvm flutter analyze --no-fatal-infos
```

Expected: PASS.

- [ ] **Step 7: Full suite**

```bash
fvm dart run melos run test
fvm dart run melos run analyze
```

Expected: every package green.

- [ ] **Step 8: Commit**

```bash
git add packages/core/lib/src/kit/offline_banner.dart packages/core/lib/core.dart \
        packages/core/test/kit/offline_banner_test.dart \
        app/lib/balsm_app/shell.dart app/lib/balsm_app/i18n \
        app/lib/balsm_app/screens/map_screen.dart modules/sessions
git commit -m "[UI] Say when the app is offline and when places are stale"
```

---

### Task 9: Writes fail with an honest message

**Files:**
- Modify: `modules/account/lib/src/application/use_cases/change_language_use_case.dart:42-48`
- Modify: `modules/account/lib/src/application/use_cases/change_country_use_case.dart:55-61`
- Modify: `modules/account/lib/src/application/use_cases/claim_handle_use_case.dart:31-37`
- Modify: `modules/account/lib/src/application/use_cases/account_profile_use_case.dart:103-109`
- Modify: `modules/deletion/lib/src/application/use_cases/request_deletion_use_case.dart:54-60`
- Modify: `modules/deletion/lib/src/application/use_cases/cancel_deletion_use_case.dart:47-53`
- Modify: `modules/disclosure/` accept use case (find it: `grep -rn "NetworkFailure" modules/disclosure/lib`)
- Test: `modules/account/test/application/offline_write_test.dart`

**Interfaces:**
- Consumes: `ApiException.isOffline` (Task 2), `OfflineFailure` (Task 2).
- Produces: nothing new — this changes which `AppFailure` subtype existing use cases return.

**What must NOT change.** `modules/auth/lib/src/application/use_cases/` — sign-in, sign-up and recovery — keep returning `NetworkFailure`. Their tests assert that mapping explicitly (`sign_in_use_case_test.dart:81,92,112,148`; `recovery_claim_use_case_test.dart:73,77`), and an auth screen that is offline already shows a connection error through its own path. Touching them breaks green tests for no user-visible gain.

Scope this to the settings and account mutations the user reaches from inside a working session — those are the ones that currently fail with a generic message when the connection is the whole problem.

- [ ] **Step 1: Write the failing test**

`modules/account/test/application/offline_write_test.dart`:

```dart
import 'package:account/account.dart';
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The exception an offline write actually produces, built the way the
/// transport builds it.
ApiException _offline() => ApiException.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/account/language'),
        type: DioExceptionType.connectionError,
      ),
    );

ApiException _serverError() => ApiException.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/account/language'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/account/language'),
          statusCode: 500,
        ),
      ),
    );

void main() {
  test('an offline language change reports being offline', () async {
    final useCase = ChangeLanguageUseCase(_ThrowingApi(_offline()));
    final r = await useCase.execute(LanguageCode.ar);

    expect(r.error, isA<OfflineFailure>(),
        reason: 'a generic "network error" hides that the fix is to reconnect');
  });

  test('a server error is still the catch-all', () async {
    final useCase = ChangeLanguageUseCase(_ThrowingApi(_serverError()));
    final r = await useCase.execute(LanguageCode.ar);

    expect(r.error, isA<NetworkFailure>());
    expect(r.error, isNot(isA<OfflineFailure>()));
  });

  test('a 401 is still unauthorized', () async {
    final useCase = ChangeLanguageUseCase(_ThrowingApi(
      const ApiException(code: 'unauthorized', statusCode: 401),
    ));
    final r = await useCase.execute(LanguageCode.ar);

    expect(r.error, isA<UnauthorizedFailure>());
  });
}
```

`ChangeLanguageUseCase`'s real constructor takes whatever collaborators it takes — read the file and build `_ThrowingApi` as a fake of the one it calls, throwing the supplied `ApiException` from the method the use case invokes. If the module already uses `mocktail`, use it instead of a hand-rolled fake.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd modules/account && fvm flutter test test/application/offline_write_test.dart
```

Expected: FAIL — the offline case returns `NetworkFailure`, not `OfflineFailure`.

- [ ] **Step 3: Add the branch**

In each `switch (e.statusCode)` listed above, the `_ =>` arm is the catch-all. Add an offline check ahead of the switch, because `statusCode` is null for an offline error and null is exactly what an unmapped status also looks like:

```dart
    } on ApiException catch (e) {
      if (e.isOffline) return AppResult.failure(const OfflineFailure());
      return AppResult.failure(switch (e.statusCode) {
        401 || 403 => const UnauthorizedFailure(),
        400 || 422 => const ValidationFailure('Invalid language'),
        _ => const NetworkFailure(),
      });
    }
```

Keep each file's existing status arms and their existing messages exactly as they are — only the new first line is added. In `request_deletion_use_case.dart` and `cancel_deletion_use_case.dart` the mapping is a helper returning `AppFailure` rather than an inline switch; add the same guard as that helper's first statement.

- [ ] **Step 4: Show the message**

Find where these use-case failures reach the user. Each screen renders `failure.message`; `OfflineFailure`'s default is `'No connection'`, which is English-only and bypasses i69n.

Rather than changing the message at the failure, map it at the display edge. In whichever shared helper turns an `AppFailure` into user-facing text (search `app/lib` and `packages/core/lib/src/kit/` for where `AppFailure` or `.message` is rendered), add:

```dart
  OfflineFailure() => s.strings.offline_write,
```

If no such shared helper exists, add the branch at each of the call sites that display these use cases' failures — the account settings screens and the deletion screens. Do not invent a new error-display abstraction for this; follow whatever the screens already do.

`s.strings.offline_write` is added in Task 8. If Task 8 has not run yet, run it first — this step depends on that key existing.

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd modules/account && fvm flutter test && fvm flutter analyze --no-fatal-infos
cd ../deletion && fvm flutter test && fvm flutter analyze --no-fatal-infos
cd ../disclosure && fvm flutter test && fvm flutter analyze --no-fatal-infos
cd ../auth && fvm flutter test
```

Expected: PASS. The auth suite must be **untouched and green** — if anything there fails, the change leaked into auth and must be reverted there.

- [ ] **Step 6: Commit**

```bash
git add modules/account modules/deletion modules/disclosure app/lib packages/core/lib/src/kit
git commit -m "[Settings] Tell people a failed write was a lost connection"
```

---

## Task order and dependencies

```
1 (cache store) ─┬─> 3 (CachedValue) ─┬─> 5 (account)
2 (offline)    ──┤                    └─> 6 (geofence)
                 └─> 7 (care)
4 (bootstrap) ─────> 5, 6, 7   (nothing resolves cacheStoreProvider without it)
2 ────────────────> 9 (writes)
8 (strings) ──────> 9 Step 4
```

Tasks 1 and 2 are independent and may run in either order. Task 4 must land before any screen is exercised on a device, or `cacheStoreProvider` throws its `UnimplementedError`.

## Done means

- `fvm dart run melos run test` green across every package.
- `fvm dart run melos run analyze` clean.
- On a device in airplane mode, launched fresh: settings shows the account, the map shows previously-seen pins with a stale notice, the offline banner is visible, and changing the language says the connection is the problem.
