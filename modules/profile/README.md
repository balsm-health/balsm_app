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

### Review fixes (2026-09-24)

Four findings from the whole-branch review, all of which the original tests
structurally could not catch:

- **Partition key is the user, not the profile.** The profile id is minted
  on-device, so a replacement phone asked for rows under an id the server had
  never seen and got nothing while reporting success. Pulled rows are now mapped
  onto whatever profile id this device minted.
- **The drain no longer jams.** A permanent rejection (4xx other than 408/429)
  drops the entry and continues; only retryable failures stop the drain to
  preserve order. A `409 Tombstoned` — the exact case the plan named — used to
  block every later change forever, because the pull that would have resolved it
  ran after the drain that never finished.
- **The queue is user-scoped.** The database survives sign-out, so an unscoped
  drain pushed one patient's PHI under the next patient's token on a shared phone.
- **A pull notifies the caller.** `customStatement` does not fire drift stream
  queries, so merged rows stayed invisible until an app restart and
  pull-to-refresh appeared to do nothing.

Care-team sync also has its own `careTeamSyncStatusProvider` rather than stamping
the Drive backup's `syncStatusProvider`, which was telling patients with no Drive
session that their data was backed up.

- **Existing rosters are backfilled once.** Before this, only providers added
  *after* the upgrade were ever pushed — so the patient in the spec's opening
  scenario (six providers, lost phone) was exactly the one the feature did not
  cover. `_backfillOnce` queues the pre-sync rows on first sync per profile,
  skipping any id already queued, and marks itself done in `sync_cursor`.
- **Local writes stamp `updated_at`.** Without it the LWW comparison weighed a
  server timestamp against a local *creation* time, so a device with a slightly
  fast clock silently dropped remote edits and deletes and never revisited them —
  the cursor had already moved past.

## Importing from the phone's contacts

`ImportedContact` is the draft a picked contact becomes before the patient
confirms it. It is deliberately not a half-built `CareProvider`: nothing is
persisted until the review sheet is confirmed, so an abandoned import leaves no
trace.

`guessCareProviderType` reads the name and proposes a type (EN + AR patterns for
doctor, pharmacy, lab, nurse, physio, clinic, carer). Two rules matter:

- The doctor match is **prefix-anchored**, so "Andrew" and "Sandra" are not doctors.
- The fallback is `other`, never a clinical role. A personal contact silently
  filed as a doctor is a wrong record about who treats this patient.

`contactPhoneKey` is the last nine digits — the identity `+201002345678`,
`01002345678` and `+20 100 234 5678` share — used to show a contact as already on
the team rather than offering a duplicate.

Only what the address book holds is carried over. Specialty, clinic, address and
notes stay null rather than being inferred: an invented clinic is worse than a
blank one.

`ImportCareContactsUseCase` writes the confirmed drafts through
`CareProvidersDataSource.putBulk`, so an imported row queues a cloud push exactly
as a hand-typed one does — there is no separate import path to the server.

It skips rather than fails, in three cases: a contact already on the team
(matched on phone), a blank name, and anything past the 100-provider ceiling. A
patient near the ceiling who picks five more gets the ones that fit; refusing the
whole batch would throw away the work of choosing. One `HealthProfileUpdated`
per batch, not per row.

`ContactPicker` / `NativeContactPicker` use `FlutterContacts.openExternalPick`,
not `getContacts`: the OS renders its own list, hands back only the chosen
contact, and **asks for no permission**. The app never sees the rest of the
address book, so there is nothing to disclose in a data-safety filing.

Reading the address book directly would need `READ_CONTACTS` /
`NSContactsUsageDescription` and a Contacts collection disclosure in both
stores. That is a compliance decision, not a code one — if the product wants
bulk "Select all", it goes to the compliance owner first.

The platform pickers are single-select (Android's `ACTION_PICK` has no multi
mode), so the sheet lets the patient pick again to add more.

