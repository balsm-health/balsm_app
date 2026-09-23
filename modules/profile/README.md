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

