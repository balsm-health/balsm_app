---
context: Personal Health
plane: consumer
features:
  - "P001: on-device health profile - blood type, allergies, chronic conditions, emergency contacts"
---

# profile

HealthProfile aggregate (PHI, on-device only via SQLCipher). Max 50 allergies / 3 emergency contacts enforced in use cases; publishes HealthProfileUpdated.

## Care-team cloud sync

`DriftCareProvidersDataSource` takes an optional `SyncOutboxDao`. When present,
every `put` and `delete` also queues a push (FR-506); when absent the data source
behaves exactly as it did before sync existed, which is what keeps tests and any
build without sync working unchanged.

The local write always happens first and the enqueue never gates it — the cloud
is a mirror, not the write path (ADR-11). Adding a provider with no signal must
succeed.

`put` is an upsert, so one enqueue point covers both add and edit; `putBulk` and
`deleteMany` delegate to `put`/`delete`, so they are covered automatically. The
queued payload matches `UpsertCareProviderRequest.toJson` in `balsm_api` and is
built here rather than on the entity, keeping the domain free of transport shape.

### CareTeamSyncService

`src/infrastructure/sync/` converges the two sides. `sync()` drains then pulls —
push first, so a local edit is never clobbered by a pull of the row it just
changed.

Three guards carry the correctness:

- **Drain stops at the first failure.** Skipping ahead would send a delete before
  the upsert that created its row: the server would tombstone a row it never saw,
  and the next pull would carry that tombstone back, removing a provider the
  patient still has.
- **Merge bypasses the outbox**, writing straight to drift. Routing a pulled row
  back through the data source would enqueue an outbound push for a row that just
  came *from* the server, and the two sides would push each other forever.
- **Strictly-newer wins**, so re-pulling rows already applied is a no-op rather
  than a rewrite.

The cursor lives in `sync_cursor` in the PHI database, keyed by (entity, profile)
— not in SharedPreferences. It is derived from PHI timestamps and must be wiped
with the rows it describes; a cursor that outlived a local wipe would make the
next pull skip every row the device no longer has.

