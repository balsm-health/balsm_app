---
context: Identity & Access
plane: cross-plane
features:
  - "P003b: add a family member who has their own Balsm account by scanning their profile QR; they approve or decline in their own app"
  - "P003b: incoming and outgoing link requests pulled on app start, resume, Family screen and pull-to-refresh (no push)"
  - "P003b: cancel a pending request; either side unlinks a link"
  - "P003b: opt-in per link, end-to-end sealed emergency card share (X25519 + HKDF-SHA256 + AES-256-GCM) readable only on the other person's phone"
---

# family_link

Links between two Balsm accounts (Identity & Access — `Caregiver` /
`Guardianship`). The requester scans the other person's profile QR; the
server resolves the QR's `jti` to that account and holds a `pending` request
until the recipient approves (`linked`) or declines. Either side can end a
link (`unlinked`); the requester can withdraw a pending one (`cancelled`).
Contract: Balsm-API-DotNet `docs/architecture/c4/family-link/`.

What a link shares: the relation label, status, dates, each side's display
name / @handle (the recipient's only after approval), and — only if its owner
switches it on for that link — an **emergency card sealed for the other
person's device key**. The server stores ciphertext it cannot open; health
data never leaves a phone in readable form.

## Layers

- `domain/` — `FamilyLink` (the caller's view of one link), `LinkRelation`
  (the relation chips' wire codes), `EmergencyCardPayload` (the shared card's
  fields and their fingerprint), `SealedCard`.
- `application/` — ports: `CardSealer` (seal / open), `DeviceKeyStore` (this
  phone's X25519 key pair), `LinkLocalStore` (per-link device state: sharing
  switch, last sealed fingerprint, uploaded key, what the requester's own scan
  showed), `OwnEmergencyCardReader` (the account holder's own card — bound by
  the app shell to the profile and account modules; this module imports
  neither). Use cases: request by scanned jti, refresh both lists (uploads
  this phone's key where it changed and re-seals stale shared cards), approve,
  decline, cancel, unlink, set card sharing, read a shared card.
- `infrastructure/` — `EciesCardSealer` (ephemeral X25519 → HKDF-SHA256, info
  `balsm-family-card-v1`, salt = link id → AES-256-GCM, AAD
  `linkId|ownerAccountId|version`), secure-store-backed key and link stores.
- `presentation/` — Riverpod providers the app shell's screens watch.

Screens live in the app shell (`app/lib/balsm_app/screens/family/`), behind
the `family_link` and `mother_child` flags.
