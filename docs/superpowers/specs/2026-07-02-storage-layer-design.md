# Storage Management Architecture — Design Spec

**Date:** 2026-07-02 (revised — supersedes the initial draft of the same date)
**Status:** Approved (design), pending implementation plan
**Reference:** [`hossameldinmi/core_fe`](https://github.com/hossameldinmi/core_fe) — storage manager/provider/model pattern.

## Goal

A coherent persistence architecture for the patient app. Rather than adding a
silo, define an explicit **tier taxonomy** and make the key-value tier
first-class: scoped (user/global), expiring (TTL), **reactive** (watch),
**backup-aware** (per-record durability), with a **fail-loud** error model
appropriate for health data.

## Persistence tiers (explicit — no unified god-façade)

| Tier | Backend | Holds | Encrypted | Backed up |
|------|---------|-------|-----------|-----------|
| **Secrets** | `SecureStorageWrapper` (keychain/keystore) | tokens, backup key, recovery code | OS keystore | no |
| **Structured** | drift DAOs on `AppDatabase` (SQLCipher) | PHI aggregates (profile, meds, dose events) | SQLCipher | yes (`SnapshotService`) |
| **Key-Value** | `StorageManager` → drift `kv_store` (SQLCipher) | prefs, drafts, cached responses, feature flags | SQLCipher | **opt-in per record** |

Routing rules are documented in a doc-comment on `StorageManager` and in this
table. `StorageManager` owns **only** the KV tier. Secrets stay in
`SecureStorageWrapper` (keychain semantics differ from a DB); structured PHI
stays in its DAOs. This keeps boundaries honest and avoids a leaky god-object.

`shared_preferences` is a declared but unused dependency and is **removed**.

## What already exists (baseline)

Implemented in `packages/core/lib/src/storage/`: `StorageScope`, `StorageRecord`,
`StorageProvider` (+ `Relational`/`NoSql` markers, `StorageCipher`,
`UserContext`, `Clock`), `StorageManager` + `StorageManagerImpl`,
`DriftStorageProvider`, `InMemoryStorageProvider`, riverpod wiring, and the
`kv_store` table. This spec adds four capabilities on top.

## Capabilities added

### 1. Durability → backup integration

- `kv_store` gains `durable INTEGER NOT NULL DEFAULT 0`.
- API: `set<T>(..., bool durable = false)`.
- `StorageRecord` gains `bool durable`.
- `SnapshotService` participates in export/import for `kv_store`:
  - **Export:** durable rows visible to the backing-up user —
    `WHERE durable = 1 AND (owner_id = :userId OR scope = 'global')`.
  - **Merge (import):** last-writer-wins by `updated_at` on the composite key
    `(owner_id, scope, key)`. A new `_lwwUpsertKv` handles the composite key
    (the existing `_lwwUpsert` assumes a single `id` column).
  - Added to `SnapshotService._tables` handling as a special case (composite
    key + durable filter), keeping FK-safe ordering unaffected (kv_store has no
    FKs).
- Non-durable records are pure local cache: never exported, dropped on device
  loss. This keeps the encrypted blob small.

### 2. Fail-loud error model

New exceptions in `storage_exceptions.dart`:
`StorageException` (base) ⊃ `NoActiveUserException`, `StorageWriteException`,
`StorageDecodeException`.

| Operation | No authenticated user (user scope) | Backend failure | Corrupt/undecodable value | Absent / expired |
|-----------|-----------------------------------|-----------------|---------------------------|------------------|
| `get`     | return `null` (pre-login read is legitimate) | rethrow as `StorageException` | throw `StorageDecodeException` | return `null` |
| `set`     | throw `NoActiveUserException` | throw `StorageWriteException` | — (encode failure → `StorageWriteException`) | — |
| `delete`  | throw `NoActiveUserException` | throw `StorageWriteException` | — | no-op |
| `deleteAll` | **no-op** (idempotent cleanup; logout may run twice) | throw `StorageWriteException` | — | — |
| `purgeExpired` | n/a (scope-agnostic) | throw `StorageWriteException` | — | — |

Rationale: silently dropping a write of health-adjacent data hides bugs. Reads
returning `null` for "not there" is a value, not a failure; but a value that is
present-yet-corrupt is a real error and must surface.

### 3. Reactive reads

- `Stream<T?> watch<T>(String key, {StorageScope scope = user, T Function(Map<String,dynamic>)? fromJson})`
  on `StorageManager`.
- `StorageProvider` gains `Stream<StorageRecord?> watch({scope, ownerId, key})`.
- Implementation is backend-agnostic: each provider holds a map of per-record
  broadcast `StreamController`s, emitting the current record on
  `write`/`remove`, and `null` on `removeExpired` for a matched key. The manager
  maps records → `T?` (applying expiry + decode) and de-dupes.
- **Known limitation:** writes that bypass the provider — notably
  `SnapshotService.import` during restore (raw `customStatement`) — do not emit.
  Documented; acceptable for this milestone (restore is a full-app reload path).

### 4. Cleanup

- Remove the unused `shared_preferences` dependency from `app/pubspec.yaml`.

## Files

New:
- `storage/storage_exceptions.dart`

Modified:
- `storage/storage_record.dart` — add `durable`
- `storage/storage_manager.dart` — add `durable` param to `set`, add `watch`
- `storage/storage_manager_impl.dart` — throw semantics, `watch`, pass `durable`
- `storage/storage_provider.dart` — add `watch` to `StorageProvider`
- `storage/providers/drift_storage_provider.dart` — `durable` column, broadcast `watch`
- `storage/providers/in_memory_storage_provider.dart` — `durable`, broadcast `watch`
- `db/app_database.dart` — `kv_store` gains `durable` column
- `backup/snapshot_service.dart` — export/import `kv_store` (durable filter, composite LWW)
- `core.dart` — export `storage_exceptions.dart`
- `app/pubspec.yaml` — drop `shared_preferences`

## Testing

- Manager (in-memory): existing suite + `durable` round-trip, `watch` emits on
  set/delete/expire, `set`/`delete` throw `NoActiveUserException` without a user,
  `get` returns null without a user, corrupt value → `StorageDecodeException`.
- Drift provider: existing suite + `durable` column persists, `watch` emits.
- `SnapshotService`: durable rows export (own + global), non-durable excluded,
  composite-key LWW merge (newer wins, older ignored), restore-onto-empty
  lossless.

## Future work

- Persistent nosql `NoSqlStorageProvider` (sembast) + `SecretBoxStorageCipher`
  (key from `SecureStorageWrapper`).
- Emit `watch` events on restore/import (bridge `SnapshotService` → providers).
- Migrate any ad-hoc persistence discovered later onto the KV tier.
