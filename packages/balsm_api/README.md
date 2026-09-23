---
context: infrastructure
plane: consumer
features:
  - "P001: typed HTTP clients for the Balsm .NET API (auth, account, sessions, deletion, disclosure, emergency QR)"
---

# balsm_api

Transport layer: Dio-based BalsmApiClient, typed per-context clients, DTOs, ApiException, PhiLeakInterceptor. DTOs are Strings/primitives by design - domain modules wrap them into typed VOs (anti-corruption).

## care_team

`src/care_team/` is the client for `/care-team/*` — the patient's own roster of
providers, mirrored to the Balsm cloud.

It is deliberately **not** part of `care_directory`. That one serves Balsm-owned
NON-PHI reference data about public health places; this one carries the
patient's PHI. Same prefix in English, opposite data-ownership plane.

- `pull` is incremental on `?since=` and returns tombstones (`is_deleted: true`)
  so a delete on one device reaches the others.
- `upsert` is idempotent on the device-minted id, which is what makes the
  at-least-once outbox drain safe to retry.
- `delete` treats a `404` as success — the row is already gone, which is the
  outcome the caller wanted — but rethrows anything else so the outbox retries.

