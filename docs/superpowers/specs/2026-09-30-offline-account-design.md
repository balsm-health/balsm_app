# Offline (device-only) account — design

Date: 2026-09-30
Status: Draft — awaiting review
Repos: `balsm_app` (Flutter), `Balsm-API-DotNet`, `Balsm-API-Doc`
Design source: DesignSync project `50dccb01…` → `Balsm App.html` / `auth.jsx` (`PhoneScreen` "Device only" tab, `GoOnlineSheet`)

## 1. Goal

Let a person create a Balsm account and use every on-device feature with no
network, then later verify their email and sync without losing data or
changing identity.

**Success criteria**

- Fresh install in airplane mode → account created → records, meds, check-ins,
  vitals etc. usable.
- Later, online: email → OTP → same account ID on the server, local data syncs.
- No offline-created ID can ever grant access to, or attach to, an existing
  server account.

**Decisions (confirmed with product owner)**

| # | Decision |
|---|---|
| D1 | Offline "password to lock the app" becomes the server account password on go-online. |
| D2 | If the email already has a Balsm account, the user chooses: merge this device's data into it, or discard this device's data. |
| D3 | Server-backed features stay visible while device-only; tapping them opens the Go-online sheet. |
| D4 | ID linkage approach A: server adopts the client-generated ID when free. |
| D5 | Password minimum is 8 characters everywhere (design copy changes from 6 → 8). |

**Out of scope**

- Offline sign-up via Google / Apple / magic link (need network by nature).
- Queuing server-side actions (shares, bookings) while offline.
- Recovering a device-only account whose password is forgotten (by design: unrecoverable).

## 2. User flow

1. **Welcome → Phone screen** gains the `Online | Device only` segmented control
   (match `auth.jsx` `PhoneScreen`: copy, info card, button labels).
2. **Device only + email + password (≥ 8)** →
   - generate `accountId` = UUIDv7 on device;
   - Argon2id-hash the password;
   - derive a key-encryption key (KEK) from the password and wrap the SQLCipher
     database key with it;
   - persist offline account record (see §4) to secure storage;
   - run the local disclosure gate (terms/privacy acceptance recorded locally,
     uploaded at go-online);
   - enter the app. Profile completed later from the Profile tab (as today).
3. **Cold start while device-only** → password unlock screen. After 5
   consecutive failures, escalating backoff: 30 s, 1 min, 5 min, 15 min, 1 h
   (cap). No recovery path; the screen restates the design's warning.
4. **Server-backed features while device-only** (Balsm Cloud sync target, care
   team sharing, appointments, care import, QR share to clinician) → tap opens
   `GoOnlineSheet`. Also reachable from Profile and Storage → Balsm Cloud row.
   iCloud / Google Drive backup remain available (they don't need a Balsm account).
5. **Go online** (`GoOnlineSheet`): email (prefilled) → `RequestOtp` →
   `VerifyOtp(clientAccountId)`.
   - `adoptedClientId = true` → `SetPassword(offlinePassword)` → wipe stored
     plaintext → mode `online` → upload pending disclosure acceptance → sync starts.
   - `adoptedClientId = false` and `isNewUser = true` (ID collision) → re-key
     locally to the returned `userId` (§4.3), then as above.
   - `isNewUser = false` (email already registered) → **Merge-or-discard screen** (§3).
   - `SetPassword` failure after verify: keep plaintext, retry on next launch;
     user is already signed in, so nothing blocks them.

## 3. Merge-or-discard screen (new — needs design)

Not in `Balsm App.html`. Must be designed in DesignSync before the Flutter
build of this screen; everything else can proceed in parallel.

Content requirements:

- Title: this email already has a Balsm account.
- Option **Merge** — "Add the data on this phone to your account." Existing
  account keeps its password; the offline password is discarded (say so).
- Option **Discard** — "Remove the data on this phone and use your account."
  Requires a second confirmation (destructive).
- User is already signed in to the existing account at this point; both
  options end in `online` mode.

Behaviour:

- **Merge**: upload every local record under the existing account's JWT, with
  owner = existing `userId`; retire the offline `accountId` locally (never sent
  again); wipe offline plaintext password.
- **Discard**: wipe local DB, vault files, offline secure-storage entries; then
  pull the existing account's data per its storage settings.
- Screen is resumable: if the app is killed here, next launch returns to it.

## 4. Flutter (`balsm_app`)

### 4.1 Offline account state

Secure storage keys (Keychain / Keystore via `flutter_secure_storage`):

| Key | Value | Lifetime |
|---|---|---|
| `balsm.account_mode` | `deviceOnly` \| `online` | permanent |
| `balsm.user_id` | UUIDv7 (reuses the existing key) | permanent |
| `balsm.offline.email` | normalized email | until online |
| `balsm.offline.pw_hash` | Argon2id encoded hash | until online (then local unlock uses the normal path) |
| `balsm.offline.pw_plain` | plaintext password | until `SetPassword` succeeds or merge/discard completes |
| `balsm.offline.wrapped_db_key` | SQLCipher key wrapped by password-derived KEK | permanent while device-only |
| `balsm.offline.lockout` | `{failures, until}` | permanent while device-only |
| `balsm.pending_merge` | `true` while merge-or-discard unresolved | until resolved |

### 4.2 Units

- `OfflineAccountService` (new, in `modules/auth` business layer — shared, live):
  `create(email, password)`, `unlock(password)`, `lockoutState()`,
  `goOnlineCompleted(result)`, `wipe()`. Pure logic over ports
  (`SecureStore`, `PasswordHasher`, `KeyWrapper`, `Clock`, `UuidGen`).
- `AuthApi` DTO: add `clientAccountId` to verify-OTP request, `adoptedClientId`
  to token response.
- UI in `app/lib/balsm_app/screens/auth_flow.dart` (the live auth UI — **not**
  `modules/auth/lib/src/presentation`):
  - `_PhoneScreen`: segmented Online / Device only, per design.
  - `_OfflineUnlockScreen`: new.
  - `GoOnlineSheet`: new, per design.
  - `_MergeOrDiscardScreen`: new, per §3 once designed.
- `PatientAppState`: expose `accountMode`; `AuthRouter` routes device-only
  cold start to unlock.
- Server-feature gate: a single `requireOnline(context, action)` helper used by
  each server-backed entry point.

### 4.3 Re-key (rare path)

Only when the server returns a different `userId` for a new email. Runs inside
one DB transaction: update owner columns, then rename vault paths, then write
`balsm.user_id`. On crash, next launch detects `balsm.user_id` ≠ owner in DB
and resumes. Covered by tests even though it should almost never happen.

## 5. API (`Balsm-API-DotNet`)

- `VerifyOtpRequest` / `VerifyOtpCommand`: add `Guid? ClientAccountId`.
- `AuthTokenResult`: add `bool AdoptedClientId` (defaults `false`; additive, old
  clients unaffected).
- `UserAccount.Create(Guid id, string countryCode, string preferredLanguage)` overload.
- `IAccountProvisioner.ProvisionAsync(..., Guid? id = null)`.
- `VerifyOtpHandler`:
  - existing email → unchanged; ignore `ClientAccountId`; `AdoptedClientId=false`.
  - new email + valid UUIDv7 `ClientAccountId` not present in `UserAccounts` →
    provision with that ID; `AdoptedClientId=true`.
  - new email + ID taken or invalid → provision with `Guid.NewGuid()`;
    `AdoptedClientId=false`. Never an error (don't leak which IDs exist).
  - Race on the same ID: PK unique violation → retry once with a fresh ID.
- Other auth handlers unchanged.
- `SetPassword` unchanged (min 8 already).
- `Balsm-API-Doc`: document the new field and flag.

## 6. Security

- Access is granted only by a verified email (OTP) + JWT. A client ID alone
  grants nothing and is never attached to an existing account.
- Offline password: Argon2id on device; KEK wraps the SQLCipher key so a
  stolen, locked device doesn't expose data.
- Plaintext password held in secure storage only until handed to `SetPassword`
  (or discarded on merge/discard), then deleted.
- Lockout state in secure storage (survives app reinstall on iOS; acknowledged).
- No email, `accountId` or password material in logs, Sentry breadcrumbs or
  analytics.
- Merge uploads only after OTP; retired offline ID is never transmitted again.
- Discard is two-step confirmed and wipes DB, vault and offline keys.

## 7. Design changes to apply

- `auth.jsx` `PhoneScreen`: "At least 6 characters" → "At least 8 characters"
  (both languages); `passwordOk` → `>= 8`.
- Add the Merge-or-discard screen (§3).
- Add the offline unlock screen if not already present in `Balsm App.html`
  (verify when implementing; design it if missing).

## 8. Testing

- **API**: handler tests — new email + free ID; new email + taken ID; new email
  + invalid ID; existing email + ID; no ID (current behaviour); PK race retry.
  Contract test for request/response shape.
- **Flutter unit**: `OfflineAccountService` create / unlock / lockout backoff /
  plaintext wiped after online / wipe; re-key resume after simulated crash.
- **Flutter widget**: Device-only tab validation (8 chars), unlock screen,
  `GoOnlineSheet` states, merge-or-discard incl. destructive confirm, server
  feature gate opens sheet.
- **Integration**: airplane-mode sign-up → add record → go online against fake
  API → record synced under same ID. Second run with existing email → merge
  path.
- **Manual**: real iPhone + Android, airplane mode sign-up, go online on staging
  (`api-stg-balsm-health.mosalam.com`).

## 9. Delivery order

1. API change + tests + API doc (independent, small).
2. Flutter `OfflineAccountService` + DTO change.
3. Device-only tab + unlock screen + server-feature gate.
4. `GoOnlineSheet` + adopt path + re-key path.
5. Merge-or-discard screen (after it's designed).
