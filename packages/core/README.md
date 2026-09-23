---
context: shared-kernel
plane: consumer
features:
  - "P001: shared kernel - domain VOs (UniqueId/UserId/EntityId), event bus, AppDatabase (SQLCipher), data-source ports, localization (i69n), design kit, telemetry, notifications, backup"
  - "P001: sync outbox - durable FIFO push queue backing care-team cloud sync (FR-506)"
---

# core

Patient-app shared kernel. Cross-context ports (currentUserIdProvider, currentEntityIdProvider, readAccountRepositoryProvider), cross-context events (CountryChanged, LanguageChanged), typed identity VOs, storage interface layer, UI kit. Must never depend on a module.

## Sync outbox

`src/sync/` is the durable push queue behind cloud sync (FR-506).
`SyncOutboxDao.enqueue` appends one row per local write; a sync service drains
it oldest-first and calls `complete` or `fail`.

Ordering is strict FIFO by rowid **across the whole queue**, not per entity.
That is the point: an upsert followed by a delete of the same id must reach the
server in that order. Drained out of order, the delete would tombstone a row the
server never created and the next pull would carry that tombstone back, removing
a provider the patient still has.

The payload is a JSON copy of a PHI row, so `sync_outbox` lives in the SQLCipher
database like every other table here and is never logged.
