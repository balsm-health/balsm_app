# Offline / device-only account

Support for accounts created without a network round-trip: they exist
on-device (`balsm.user_id`) but have no server session.

## On-device DB encryption

`packages/core/lib/src/db/db_key.dart` — `generateDbKeyHex()` produces 32
random bytes (`Random.secure()` in production) as a 64-char hex string, stored
under secure-storage key `kDbKeyStorageKey` = `balsm.db.key.v2` (`.v2`: the v1
key was never actually applied and wasn't random — not reused).

`packages/core/lib/src/db/database_connection_io.dart` (`openExecutor`)
applies it on open: reads `SecureStorageWrapper.storage` for the key; if
absent, deletes any pre-launch plaintext `balsm.db` (no real users existed
yet, so no migration — spec D7) and generates+stores a fresh one. The key is
applied via `PRAGMA key = "x'<hex>'"` in the drift `setup` callback, which
then checks `PRAGMA cipher_version` and throws if empty — refusing to open an
unencrypted (plain sqlite) database rather than silently storing plaintext.

## Account mode

`packages/core/lib/src/auth_context/account_mode.dart` — `enum AccountMode {
online, deviceOnly }`, persisted under secure-storage key `kAccountModeKey` =
`balsm.account_mode`. `AccountMode.fromWire(v)` treats a missing or unknown
value as `online`, so every existing install (written before this key
existed) keeps working unchanged. `deviceOnly` means: this account has a
`balsm.user_id` but no access/refresh token.

## Interceptor device-only guard

`packages/core/lib/src/network/auth_interceptor.dart` (`AuthInterceptor`):

- **`onRequest`** — for any non-bootstrap path, if the stored account mode is
  `deviceOnly`, the request is refused locally (`handler.reject(...)`, never
  reaches the adapter) with a `DeviceOnlyAccountException`. Bootstrap paths
  (`/auth/otp/*`, refresh, social/password sign-in, recovery-claim) are still
  sent — a device-only account still needs to be able to sign in for real.
- **Surfaced as offline, not cancelled** — the rejection uses
  `DioExceptionType.connectionError`. `ApiException.fromDioException`
  (`packages/balsm_api/lib/src/transport/api_exception.dart`) special-cases
  `DioExceptionType.cancel` to a silently-ignored `cancelled` code before
  looking at anything else, which would swallow this refusal; `connectionError`
  instead flows through `isOfflineError`
  (`packages/balsm_api/lib/src/transport/offline.dart`), so callers see
  `ApiException.isOffline == true` — exactly like being offline — while
  `DioException.error` still carries the `DeviceOnlyAccountException` for
  anything that wants the precise reason.
- **`_doRefresh` never signs a device-only account out** — it short-circuits
  to `null` for `deviceOnly` before reading the refresh token or device id, so
  it can never reach `_signOut()` (which deletes `balsm.user_id` and publishes
  `SessionExpired`) for this account mode. There is no session to refresh and
  nothing to sign out of.

`AuthInterceptor` and `SecureStorageWrapper` are wired to the same
`FlutterSecureStorage` instance in production (`SecureStorageWrapper.storage`,
passed into `BalsmApiController.create`), so the interceptor always reads the
mode `SecureStorageWrapper` writes.

## Offline account service

`modules/auth/lib/src/application/offline/offline_account_service.dart` —
`OfflineAccountService` creates and unlocks a device-only account with no
server round-trip. Secure-storage keys, all written/read via
`SecureStorageWrapper`:

- `balsm.user_id` — the account id (UUIDv7), shared with the rest of the app.
- `balsm.account_mode` — `kAccountModeKey` (see above); `create()` writes it
  last, so a crash mid-creation leaves an ordinary signed-out install rather
  than a half-created device-only one.
- `balsm.offline.email` — normalized (trimmed, lower-cased) email.
- `balsm.offline.pw_hash` — the Argon2id PHC string (below).
- `balsm.offline.pw_plain` — the plaintext password. Held only so the
  eventual go-online flow can set it as the real server password
  (`SetPassword`, Task 11), which then calls `clearPlainPassword()`. Never
  logged; deleted as soon as it is no longer needed.
- `balsm.offline.lockout` — JSON `{"failures": n, "until": <ISO-8601|null>}`,
  so a lockout survives an app restart.
- `balsm.pending_merge` — set when a device-only account needs to be merged
  into a server account after coming online (`setPendingMerge`).

`Argon2idOfflinePasswordHasher` (`offline_password_hasher.dart`) hashes with
OWASP's Argon2id minimum: `m=19456` (19 MiB), `t=2` iterations, `p=1` lane,
a 32-byte derived hash and a 16-byte random salt, encoded as a PHC string
(`$argon2id$v=19$m=19456,t=2,p=1$<salt>$<hash>`). Verification re-derives the
key from the stored salt and compares in constant time.

`unlock(password)` returns a `sealed class UnlockResult`: `Unlocked`,
`WrongPassword(failures)`, or `LockedUntil(until)`. The first 4 wrong
attempts just count failures; the 5th and each subsequent wrong attempt (while
not already locked) escalates through a fixed schedule — 30 s, 1 min, 5 min,
15 min, then a 1 h cap for the 9th failure and beyond. While `until` is in the
future, even the correct password is refused; a correct password at any other
time resets the failure count and clears `balsm.offline.lockout`.

`wipe()` deletes every `balsm.offline.*` key plus `balsm.pending_merge`,
`balsm.account_mode`, and `balsm.user_id` — a full reset of the device-only
account, as opposed to `markOnline()`, which only drops the offline-only
credential keys (`email`, `pw_hash`, `lockout`) and switches the mode to
`online`, keeping `balsm.user_id` and `balsm.offline.pw_plain` until the
go-online flow consumes it.

`create()` clears any stale `balsm.offline.lockout` / `balsm.pending_merge`
before writing its own keys (so a freshly created account never inherits a
previous account's lockout or merge flag), and `discardIncompleteCreate()` —
meant to be called once at app bootstrap, before anything reads the mode —
cleans up the orphaned offline-account keys left behind if `create()` crashed
before it could write `balsm.account_mode`, without ever deleting
`balsm.user_id` while a real online session's refresh token is present.

## Sign-in: Device only

`app/lib/balsm_app/screens/auth_flow.dart` (`_PhoneScreen`) adds a two-way
segmented control ("Online" / "Device only") above the email/password fields
on the sign-in screen. Switching to "Device only":

- Swaps the title, help copy and password label for device-only wording, and
  hides the "Forgot password?" link — a device-only account has no
  server-side record to recover a password from.
- Shows an info card under the password field warning that the password can't
  be recovered until the account goes online, and that losing the device
  before then loses the data with it.
- Requires an 8-character password minimum in **both** modes (D5 — the
  earlier 6-character design floor was raised so device-only and online share
  one rule).
- On submit, calls `OfflineAccountService.create(email, password)` directly —
  no network call. Success sets `PatientAppState.accountMode` to
  `AccountMode.deviceOnly` and proceeds through the same disclosure gate as
  every other sign-in path; while device-only, the disclosure API call is
  refused locally by the interceptor (see above) and tolerated, since
  acceptance is what's actually stored on-device.
- If creation itself fails (e.g. a secure-storage write error), a generic
  retry message is shown — never the exception's own text, so nothing from a
  storage error accidentally leaks onto the screen.
- Switching back to "Online" (or away from it) clears any offer/error left
  over from the other mode, so a failed online sign-in's "send a code?"
  prompt can't linger into the device-only path and reach its network call.

## App startup

`app/lib/brands/balsm/main_balsm.dart` (`bootstrap()`) runs the incomplete-create
cleanup first, before anything reads `balsm.user_id` or `balsm.account_mode`:
it constructs `OfflineAccountService` directly (the provider container doesn't
exist yet) and calls `discardIncompleteCreate()`, so a crashed `create()` never
gets mistaken for a real device-only account on this launch.

Only then does bootstrap read the account mode and decide whether the stored
id is revivable. A `deviceOnly` account keeps its `balsm.user_id` with no
refresh token — that is by design, not the interrupted-sign-out remnant the
revivability guard exists for — and `PatientAppState.load(...)` routes it to
`AppRoutes.unlock` (`app/lib/balsm_app/routes.dart`) so the shell asks for the
on-device password before anything else. An unresolved `balsm.pending_merge`
takes priority over that and resumes on `AppRoutes.mergeOrDiscard` instead,
whatever the account mode. Neither case reaches the ordinary signed-in shell
(`AppRoutes.app`) directly.

## Unlock

`app/lib/balsm_app/screens/auth_flow.dart` (`_UnlockScreen`) is what
`AppRoutes.unlock` renders. Built from `_PhoneScreen`'s own pieces (cream
background, the password field with its show/hide eye, the same device-only
warning card) since no DesignSync design exists for this screen yet — it is
provisional, and a real design should be requested before release.

- On `initState`, calls `OfflineAccountService.lockout()`; if already locked
  out (e.g. the app was killed mid-countdown), it starts the countdown
  immediately rather than waiting for a failed attempt.
- Submitting calls `OfflineAccountService.unlock(password)`, checked entirely
  on-device against the stored Argon2id hash:
  - `Unlocked` → clears the field, then goes straight to `AppRoutes.app` (no
    disclosure-gate replay — the device-only account already accepted
    disclosure locally when it was created). The password is never left
    sitting in the text controller after a successful unlock.
  - `WrongPassword` → shows a generic "wrong password" message and clears the
    field.
  - `LockedUntil` → clears the field and starts a countdown; the unlock
    button is disabled for the duration, and the message counts down once a
    second until it expires.
  - Any other failure (e.g. a secure-storage read error) is caught, the
    field is cleared, and a generic retry message (`auth.unlock_failed`) is
    shown — never the exception's own text, so nothing from a storage error
    leaks onto the screen or into logs.
- There is **no password-recovery path** on this screen (and none exists for
  a device-only account at all, per `device_warning`): the password is the
  only way in until the account goes online and a server-side reset becomes
  possible.

## Going online

`VerifyOtpRequest.clientAccountId` (`packages/balsm_api/lib/src/auth/requests.dart`)
is an optional field on the existing `POST /auth/otp/verify` request; it is
omitted from the JSON body entirely when null, and set to the device's
offline `balsm.user_id` when a device-only account is going online. The
response carries `AuthTokensResponse.adoptedClientId` (from wire field
`adopted_client_id`, defaulting to `false` for every other caller of this
endpoint).

`BalsmAuthAdapter.verifyOtpClaim(...)` (`modules/auth/lib/src/infrastructure/api/balsm_auth_adapter.dart`)
calls the same endpoint with the client's id attached, and
`SignInUseCase.goOnline(...)` (`modules/auth/lib/src/application/use_cases/sign_in_use_case.dart`)
interprets the result as one of three outcomes:

- **Adopted** (`GoOnlineAdopted`) — the server kept the device's offline id as
  the real account id. Nothing to re-key locally.
- **New id** (`GoOnlineNewId(userId)`) — the email had no account, but the
  server assigned a different id than the one offered (an id collision).
  Local data keyed to the old offline id needs to be re-keyed to `userId`.
- **Existing account** (`GoOnlineExistingAccount(userId)`) — the email
  already had a server account; the user must choose to merge or discard
  the local device-only data.

`goOnline` persists the returned tokens exactly like `verifyEmailOtp` (access
token, refresh token, user id all written via `SecureStorageWrapper`), but
does **not** publish `UserSignedIn` itself — the caller publishes it only
after handling any re-key/merge decision the outcome requires.

`adopted_client_id` is on the non-PHI telemetry allowlist (it is a boolean
outcome flag); `client_account_id` is not — it is a device-generated account
id and stays redacted like any other id-shaped field.

## Go online flow

`app/lib/balsm_app/auth/go_online_controller.dart` — `GoOnlineController`
(`goOnlineControllerProvider`) drives a device-only account online by email →
6-digit code. `sendCode(email)` calls `SignInUseCase.requestContinueOtp` with
the current country. `verify(email:, code:)` runs, in order:

1. Reads the pending offline credentials and the device's `balsm.user_id`
   (the local id) — before `goOnline`, which overwrites `balsm.user_id` with
   the server's id when it persists the session. (`GeneratedDatabase` is
   re-exported from `package:core` so the app can hand the drift DB to
   `rekeyOwner` without a direct drift dependency.)
2. `SignInUseCase.goOnline(email, code, clientAccountId: localId)`.
3. **Adopted** → no re-key.
4. **New id** → `rekeyOwner(db, from: localId, to: newId, dropOutbox: false)`
   moves every local row to the server id (one transaction; a failure is
   returned as a `StorageFailure` and nothing else happens).
5. For both: `OfflineAccountService.markOnline()`, then publishes
   `UserSignedIn(provider: 'email')` with the final id, then
   `finishPasswordIfPending()`, then `AcceptDisclosureUseCase.resync(...)`
   with the same disclosure id/version the post-sign-in gate uses
   (`kDisclosureId` / `kDisclosureVersion` in `auth_flow.dart`). Returns
   `GoOnlineOutcome.online`.
6. **Existing account** → `setPendingMerge(true)`; the target server id is
   kept on the controller (`pendingTargetId`) and in secure storage under
   `balsm.pending_merge_target`. Returns `GoOnlineOutcome.needsMergeChoice`.
   The account is **not** marked online and no `UserSignedIn` is published
   — the merge-or-discard screen finishes that.

A server lockout returns a failure and sets `lockedUntil` for the UI; any
other verify failure changes nothing locally.

`finishPasswordIfPending()` sends the password chosen offline
(`balsm.offline.pw_plain`) as the real server password via
`SignInUseCase.setPassword`. On success the plaintext is deleted
(`clearPlainPassword()`); on failure it is kept, and the account is still
online. The next launch retries it.

### Sheet and entry points

`app/lib/balsm_app/screens/go_online_sheet.dart` — `showGoOnlineSheet(context)`
walks **email → code → done** in the same sheet scaffold as forgot-password
(grab handle, title, the six `OtpBox`es over one hidden field, a 28 s resend
countdown, a success mark). The email is prefilled from the device-only
account (`pendingCredentials().email`); the sixth digit auto-submits. On
`online` it sets `PatientAppState.accountMode` to `online` (so every gate
below re-renders) and shows the done step. On `needsMergeChoice` it closes and
routes to `AppRoutes.mergeOrDiscard`. A lockout shows the standard
"temporarily locked" wait. `OtpBox` and the sign-in text field (`AuthInput`)
moved from `auth_flow.dart` to `app/lib/balsm_app/widgets/auth_fields.dart` so
both flows share them.

`requireOnline(context, ref)` is the server-feature gate: `true` at once for
an online account; for a device-only account it opens the sheet and returns
whether the account came back online. Gated entry points:

- `openCareTeam` (`care_team_screen.dart`) — every caller (Profile row, Home
  shortcut, deep link, dev service extension) now passes its `WidgetRef`.
- The care-team contacts import (`_import` in the same screen).
- The QR-share opener `openQrShare` (`personal_details.dart`) — both Profile
  entry points (app-bar button and handle pill).

Offered, not gated:

- **Profile** — while device-only, a "Go online" row (cloud icon, with a
  one-line subtitle) sits under the Storage row and opens the sheet.
- **Storage & sync** — while device-only, the Balsm Cloud account row shows a
  "Go online" pill at full opacity and opens the sheet. iCloud and Google
  Drive are unchanged ("Coming soon").

### Password retry at launch

`app/lib/brands/balsm/main_balsm.dart` — after the API client is initialised,
if the stored account mode is `online` and a session exists, bootstrap fires
`goOnlineControllerProvider.finishPasswordIfPending()` without awaiting it. It
is a no-op unless `balsm.offline.pw_plain` is still present (a previous
`SetPassword` failed).

### Copy note

`go_done_help` says the account "is now on Balsm" rather than the design's
"your data is syncing": no cloud can receive data yet, so the design's line
would be untrue. Flagged to design.

## Disclosure acceptance while device-only

`modules/disclosure/lib/src/application/use_cases/accept_disclosure_use_case.dart` —
`AcceptDisclosureUseCase.execute()` accepts a disclosure in three steps: (1) stores
the acceptance on-device via `DisclosureDao.insert()`, (2) syncs to the cloud with
a best-effort `POST /disclosure/accept` call, and (3) publishes a `DisclosureAccepted`
domain event. When the account is `deviceOnly`, step 2 fails (the interceptor rejects
the request locally), but steps 1 and 3 complete normally, so the disclosure is
marked accepted on-device.

`AcceptDisclosureUseCase.resync()` re-sends stored acceptances after going online,
retrieving them from local storage and calling `POST /disclosure/accept` with the
same details (disclosure id, version, country code, supervisory authority, preferred
language). It is best-effort — if the call fails or no acceptance is stored, it
returns `false` without throwing, allowing the go-online flow to proceed. Designed
to run after `goOnline` completes and tokens are live.

## Re-keying local data

`packages/core/lib/src/db/owner_rekey.dart` — `rekeyOwner(db, from, to, dropOutbox)` moves
every locally-owned row from account `from` to account `to`. It discovers tables by
detecting the `user_id` column rather than using a hard-coded list, so a module that
adds a `user_id` table later is covered without touching this function. All changes
happen in one transaction: a crash leaves either every row on the old id or every row
on the new id, never a mix. When `dropOutbox` is true, rows in `sync_outbox` owned by
`from` are deleted instead of re-keyed (on merge: the retired offline account's
pending account-level updates must not overwrite the existing account's server profile).
