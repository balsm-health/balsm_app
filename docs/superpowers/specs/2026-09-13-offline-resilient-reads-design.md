# Offline-Resilient Reads — Design

**Status:** approved for implementation
**Date:** 2026-09-13
**Scope:** `balsm_app` only. No backend changes, no new infrastructure.

## Problem

Health data already works offline — profile, medications, records,
prescriptions and check-ins live in the on-device SQLCipher database. The app
still looks broken without a network because everything the *server* owns is
read live on every access:

| Read model | Today | Offline result |
|---|---|---|
| Account summary (`GET /account/self`) | fetched on every `getAccount`, nothing retained | settings, language and country screens show an error state |
| Denied countries (`GET /geofence/denied-countries`) | 24h cache in `flutter_secure_storage`, stale fallback | works — but the mechanism is hand-rolled inside the adapter |
| Care directory (`GET /care/entities`, `/care/pins`) | bounded in-memory LRU | empty map after every app restart |
| Sessions (`GET /sessions`) | live only | error state |

Writes fail with a generic error that does not tell the user the problem is
their connection.

`BalsmGeofenceAdapter` already solves its own version of this correctly:
prefer a fresh cache, fetch on staleness, fall back to the stale copy when the
fetch throws. It is the right behaviour in the wrong place — a private TTL
constant, bespoke JSON, and a storage tier chosen for secrets rather than for
cache. Copying that shape into each new adapter is how the behaviour drifts
apart.

## Goal

Every screen that can render from previously-seen data does so when the
network is unavailable, and every screen that cannot says why.

## Non-goals

- **Queued writes.** Mutations fail fast. No outbox, no replay, no conflict
  resolution. Decided explicitly; revisit only with a new spec.
- **Map tiles.** The basemap stays online-only. Offline tiles are the separate
  governorate-pack project, which supersedes parts of the care-cache retention
  policy below.
- **Syncing PHI to the server.** Unchanged: on-device only.

## Architecture

Three pieces, smallest first.

### 1. Cache storage tier (`packages/core/lib/src/cache/`)

One table in the existing `AppDatabase`, one store over it.

```sql
CREATE TABLE IF NOT EXISTS cache_entry (
  namespace  TEXT    NOT NULL,
  key        TEXT    NOT NULL,
  payload    TEXT    NOT NULL,
  fetched_at INTEGER NOT NULL,
  PRIMARY KEY (namespace, key)
)
CREATE INDEX IF NOT EXISTS idx_cache_entry_ns_time
  ON cache_entry(namespace, fetched_at)
```

Declared in a new `_cacheSchema` const beside `_phiSchema`, kept separate
because the distinction is load-bearing: **nothing in `cache_entry` is PHI,
nothing in it is backed up, and dropping the whole table is always safe.**

It lives in `AppDatabase` rather than a second database to reuse the one
connection and the one key. `SnapshotService` enumerates an explicit `_tables`
allowlist, so cache rows cannot leak into a backup by accident — but
`cache_entry` must never be added to that list, and a test asserts it is
absent.

`flutter_secure_storage` is the wrong tier and the geofence cache moves off
it: it is slow, size-limited on Android, and encrypting a public list of
country codes buys nothing.

```dart
/// Raw JSON rows keyed within a namespace. No typing, no TTL — policy belongs
/// to the caller.
abstract interface class CacheStore {
  Future<CacheRow?> read(String namespace, String key);
  Future<void> write(String namespace, String key, String payload);
  Future<void> delete(String namespace, String key);
  Future<List<CacheRow>> readNamespace(String namespace);
  /// Deletes all but the [keep] most recently fetched rows in [namespace].
  Future<void> evictOldest(String namespace, {required int keep});
  Future<void> clearNamespace(String namespace);
  Future<void> clearAll();
}

class CacheRow {
  final String key;
  final String payload;
  final DateTime fetchedAt;
  bool isFresh(Duration ttl);
}
```

`DriftCacheStore` implements it. `cacheStoreProvider` is bound in
`bootstrap()` from `appDatabaseProvider`.

### 2. Single-slot cached value (`packages/core/lib/src/cache/cached_value.dart`)

The account summary and the denied-country list are the same shape: one value,
refreshed on read, kept when the refresh fails. That shape gets one
implementation with two consumers — enough to justify it, and deliberately not
a general keyed-cache framework, which would have one.

```dart
class CachedValue<T> {
  CachedValue({
    required CacheStore store,
    required String namespace,
    required Duration ttl,
    required T Function(Map<String, dynamic>) decode,
    required Map<String, dynamic> Function(T) encode,
  });

  /// Fresh cache → return it without touching the network.
  /// Stale or absent → call [fetch]; retain and return the result.
  /// [fetch] throws a connectivity error → return the stale copy at any age.
  /// [fetch] throws anything else → rethrow, without serving stale.
  Future<T?> read(String key, {required Future<T?> Function() fetch});

  Future<T?> peek(String key);       // cache only, never fetches
  Future<void> invalidate(String key);
  Future<void> invalidateAll();
}
```

The key is a method parameter rather than a constructor field because the
account's key is its user id, which is known per call (`getAccount(userId)`)
and not when the adapter is built. Geofence passes a constant.

The distinction in the last two clauses is the whole point and is where a
hand-rolled cache goes wrong. `BalsmGeofenceAdapter` today catches bare
`catch (_)`, so a 500 or a malformed body is indistinguishable from being
offline and silently serves stale data forever. `CachedValue` falls back only
for connectivity errors — everything else propagates.

### 3. Offline as a typed failure and an app-wide signal

**`OfflineFailure extends AppFailure`** joins the sealed hierarchy in
`app_failure.dart`. `NetworkFailure` stays as the catch-all it currently is
(`sign_in_use_case_test.dart` asserts that role); `OfflineFailure` is narrower
and means exactly "the request never reached a server".

A single classifier owns the decision, so every layer agrees:

```dart
// packages/core/lib/src/network/offline.dart
bool isOfflineError(Object error);   // DioExceptionType.connectionError /
                                     // connectionTimeout, SocketException,
                                     // and the same wrapped in AuthException
```

**Connectivity is a hint, not truth.** `connectivity_plus` reports interface
state: a captive-portal Wi-Fi reports online with no reachable server, and a
transitioning interface reports offline while requests still succeed.
Therefore:

- Requests are **never** gated on connectivity. The app always tries; a failed
  attempt is the authoritative signal.
- `onlineProvider` exists only to drive UI and to trigger opportunistic
  refresh on reconnect.

`connectivityOnlineStream()` moves from `src/backup/` to `src/network/` (its
`BackupService` consumer is updated) and gains a synchronous first emission —
`onConnectivityChanged` does not emit current state on subscribe, so today a
listener knows nothing until the interface next changes.

## Per-context changes

### Account summary

`BalsmAccountAdapter.getAccount` wraps `_api.getSelf()` in a `CachedValue`
over `AccountSummary`, which already has `toJson`/`fromJson`.

Two rules that are not optional:

- **Namespaced by user id.** The cache key includes the signed-in user id, so
  a second account on the same device can never be shown account one's handle.
- **A 401 clears the cache and rethrows.** A rejected session must not keep
  serving a cached identity. Only `isOfflineError` triggers the stale path.

`clearNamespace` runs on sign-out alongside the existing token wipe.

TTL: 1 hour. The summary changes only when the user changes it, and every
mutation path already calls `ref.invalidate(accountSummaryProvider)` —
`invalidate` on the provider must also invalidate the `CachedValue`, or the
refetch returns the same stale row.

### Denied countries

`BalsmGeofenceAdapter` keeps its behaviour and its 24h TTL, but delegates to
`CachedValue` and drops `_readCache`, `_writeCache`, `_CachedDenyList` and the
`SecureStorageWrapper` dependency. The bare `catch (_)` narrows to the offline
classifier.

One migration concern: existing installs have a deny list under the old
SecureStorage key. It is not read back — the first launch after upgrade fetches
fresh, and the old key is deleted. Deleting it matters; leaving orphaned data
in the keychain is the kind of thing that survives an uninstall on iOS.

### Care directory

`MemoryCareDirectoryDataSource` is replaced by `DriftCareDirectoryDataSource`
over `cache_entry`, namespace `care`. `LocalCareDirectoryDataSource`,
`CachingCareDirectoryRepository` and `CareQueryId` keep their shapes — the
whole reason that seam exists.

One signature does change. `CareDirectoryRepository.nearby` returns
`CareResults` instead of `List<CareEntity>`:

```dart
class CareResults {
  final List<CareEntity> entities;
  /// True when these came from a cache row past its TTL because the refetch
  /// failed — the map's stale notice reads this, not the connectivity stream.
  final bool stale;
}
```

The alternative was inferring staleness in the UI from `onlineProvider`, which
would be a guess: connectivity reports the interface, not whether these
particular rows are old. Provenance has to travel with the data. `map_screen`
is the only caller and updates accordingly.

The in-memory `CareDirectoryCache` stays as a first tier in front of the
database, so a repeated pan within one session still costs no I/O. It keeps
its own LRU-by-access policy; the database tier evicts by fetch time, since
that is the only timestamp a row carries.

Retention:

- **Bound:** 200 query results, evicting least-recently-fetched. Care results
  are the only high-volume cache; a cap matters.
- **TTL 7 days.** A result older than that is refetched.
- **A stale row survives a failed refetch.** When the refetch throws an
  offline error, the expired row is returned rather than an error — the same
  rule `CachedValue` applies, reached the same way.

Note what this does *not* do: nothing here consults `onlineProvider`. An
earlier draft said "no TTL when offline", which would have contradicted the
rule that requests are never gated on connectivity. The repository always
attempts the refetch; the failed attempt is what selects the stale row. A
captive-portal Wi-Fi therefore behaves correctly with no special case.

This revises the memory-only ruling recorded in
`memory_care_directory_data_source.dart`, whose reasoning was that a retained
result could outlive a facility that has closed. That reasoning is sound and
survives here in a weaker form — the risk is accepted in exchange for a usable
offline map, bounded by the TTL, and disclosed by the banner. The governorate-
pack project replaces this with versioned data carrying a real "as of" date,
at which point this policy should be revisited.

A failed fetch is still never retained. Unchanged, and worth restating: an
error cached as an answer makes a blip look like an empty region.

### Sessions

No cache — a stale list of active sessions is a security-relevant lie. The
screen gains an offline empty state instead of an error state.

### Write paths

Every mutation maps `isOfflineError` to `OfflineFailure` and the UI renders
one shared message. No queuing.

## UI

**`OfflineBanner`** in `packages/core/lib/src/kit/`: a slim strip, styled with
existing tokens, shown when `onlineProvider` is false. Placed in the app shell
so it appears once rather than per screen.

**Stale-data notice on the map** when results came from cache while offline.

Both strings go through i69n bundles in English and Arabic. No inline
ternaries.

## Testing

Unit tests, no device needed:

- `CachedValue`: fresh hit skips fetch; stale triggers fetch; offline error
  returns stale; non-offline error rethrows and does not serve stale; `peek`
  never fetches.
- `isOfflineError`: each `DioExceptionType`, `SocketException`, wrapped
  `AuthException`, and negative cases (401, 500, malformed body).
- `DriftCacheStore`: round-trip, namespace isolation, `evictOldest` keeps
  exactly the newest N, `clearNamespace` leaves other namespaces intact.
- Account adapter: 401 clears cache and rethrows; offline serves stale; a
  different user id does not read the first user's row.
- Care repository: fresh row skips fetch; expired row triggers fetch; a
  failed refetch returns the expired row with `stale: true`; a successful one
  returns `stale: false`; bound enforced at 200 rows.
- `SnapshotService`: `cache_entry` is not in `_tables`.

Existing suites must stay green, particularly
`packages/core/test/network/auth_interceptor_test.dart` and the auth use-case
tests that assert the `NetworkFailure` catch-all.

## Risks

- **Stale identity after a password change on another device.** The 1h TTL
  bounds it; a 401 clears it immediately.
- **Cache growth.** Bounded per namespace; care is the only large one.
- **`connectivity_plus` false positives.** Mitigated by never gating requests
  on it — the banner may briefly lie, requests will not.
- **Care staleness.** Accepted and disclosed, above.
