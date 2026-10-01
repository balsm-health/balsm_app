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

1. Resolves the device's own id (the local id) from secure-storage key
   `balsm.offline.local_id`. On the first attempt that key is absent, so the
   current `balsm.user_id` is read and pinned there — before `goOnline`, which
   overwrites `balsm.user_id` with the server's id when it persists the
   session. Every retry, and the merge screen, therefore work from the
   device's id, never the server's. (`GeneratedDatabase` is re-exported from
   `package:core` so the app can hand the drift DB to `rekeyOwner` without a
   direct drift dependency.)
2. `SignInUseCase.goOnline(email, code, clientAccountId: localId)`.
3. **Adopted** → no re-key.
4. **New id** → `rekeyOwner(db, from: localId, to: newId, dropOutbox: false)`
   moves every local row to the server id, then
   `UserFileStore.rekeyOwnerFiles(from: localId, to: newId)` moves the vault
   files and their key (see "Re-keying local data"). Both are idempotent; if
   either fails, verify returns a `StorageFailure`, the pin stays on the
   device's id, and nothing else happens — a retry re-runs both. Only after
   both succeed is `balsm.offline.local_id` updated to the new id, so a crash
   after this point never re-keys from a stale id.
5. For both: `OfflineAccountService.markOnline()`, then publishes
   `UserSignedIn(provider: 'email')` with the final id, then
   `finishPasswordIfPending()`, then sets `balsm.offline.disclosure_pending`
   and runs `AcceptDisclosureUseCase.resync(...)` with the same disclosure
   id/version the post-sign-in gate uses (`kDisclosureId` /
   `kDisclosureVersion` in `auth_flow.dart`); the flag is cleared only when
   resync returns `true`. Finally `balsm.offline.local_id` is deleted.
   Returns `GoOnlineOutcome.online`.
6. **Existing account** → `setPendingMerge(true)`; the target server id is
   kept on the controller (`pendingTargetId`) and in secure storage under
   `balsm.pending_merge_target`, and `balsm.offline.local_id` stays pinned to
   the device's id for the merge. Returns `GoOnlineOutcome.needsMergeChoice`.
   The account is **not** marked online and no `UserSignedIn` is published
   — the merge-or-discard screen finishes that, and clears the pin.

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
"temporarily locked" wait; a server refusal (e.g. a wrong code) shows the
server's message; anything else — including an unexpected exception — shows
the generic `offline.go_failed`, re-enables the sheet, and re-reads the
account mode from storage so the UI agrees with it if `markOnline()` had
already run. `OtpBox` and the sign-in text field (`AuthInput`)
moved from `auth_flow.dart` to `app/lib/balsm_app/widgets/auth_fields.dart` so
both flows share them.

`requireOnline(context)` is the server-feature gate: `true` at once for an
online account; for a device-only account it opens the sheet and returns
whether the account came back online. It gates sharing and sync only — never
on-device data (spec D3), so the care team and its contacts import stay open
to a device-only account. Gated entry point:

- The QR-share opener `openQrShare` (`personal_details.dart`) — both Profile
  entry points (app-bar button and handle pill).

Offered, not gated:

- **Profile** — while device-only, a "Go online" row (cloud icon, with a
  one-line subtitle) sits under the Storage row and opens the sheet.
- **Storage & sync** — while device-only, the Balsm Cloud account row shows a
  "Go online" pill at full opacity, with the `go_row_sub` line in place of
  "Available soon", and opens the sheet. iCloud and Google Drive are
  unchanged ("Coming soon").

### Retry at launch

`app/lib/brands/balsm/main_balsm.dart` — after the API client is initialised,
if the stored account mode is `online` and a session exists, bootstrap fires
`goOnlineControllerProvider.retryPending()` without awaiting it. It retries
`finishPasswordIfPending()` (a no-op unless `balsm.offline.pw_plain` is still
present because a previous `SetPassword` failed) and, when
`balsm.offline.disclosure_pending` is set, the disclosure resync. It never
throws (each step catches), and the call site adds a `catchError` backstop, so
a keychain error can't become an unhandled zone error. Nothing is logged.

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

Attachments live outside the DB. `EncryptedFileStore`
(`packages/core/lib/src/data_source/impl/encrypted_file_store.dart`) partitions
them under `<root>/<userId>/` and encrypts them with a per-owner key stored in
secure storage as `balsm.file_key.<userId>`, so after an id change they would
be unreachable. `UserFileStore.rekeyOwnerFiles(from:, to:)` hands them over:
it renames `<root>/<from>/` to `<root>/<to>/` (the store's own injected root)
and moves the key (writes `balsm.file_key.<to>`, then deletes
`balsm.file_key.<from>`). Each half is skipped when its source is already
gone, so a second call or a retry after a crash finishes the job. If the
target already has a different key or a partition, it throws
`StateError('target owner already has files')` — combining two owners' files
(merge) is not done here. Ids must be single path segments. The in-memory
store used on web has no per-owner partition and treats it as a no-op.

## Merge or discard

When going online finds that the email already has a Balsm account
(`GoOnlineExistingAccount`), the patient is signed in to that account's
session but the account is not yet online on this phone: `balsm.pending_merge`
is set, the existing account's id is in `balsm.pending_merge_target`, and the
device's own id stays pinned in `balsm.offline.local_id`. The patient then
chooses what happens to the data on this phone.

### Merging the database

`packages/core/lib/src/db/owner_rekey.dart` — `mergeOwner(db, from:, to:)`
moves the offline account's rows into the existing account in one
transaction:

1. **Profile consolidation.** `health_profile` has no UNIQUE(user_id), so a
   plain re-key would leave the merged account with two self profiles when the
   existing account has used this phone before. If `to` already owns a
   `health_profile` row, every `health_profile_id` column (tables discovered
   by column, like `user_id`) that points at the offline profile is re-pointed
   to the existing profile, and the offline profile row is deleted. The
   existing profile's own head fields (blood type, height, weight) are kept.
   If `to` has no profile, the offline profile simply moves over with the
   re-key.
2. **Re-key.** Every `user_id` row moves from `from` to `to`, and the offline
   account's `sync_outbox` rows are dropped (as `rekeyOwner(dropOutbox: true)`).

A crash rolls the whole merge back; a second run finds nothing owned by
`from` and does nothing. `ownedTables(db)` / `tablesWithColumn(db, column)`
are the shared column-discovery queries.

### Discarding the database

`discardOwner(db, owner:)` deletes, in one transaction, every row keyed to
one of the owner's health profiles, then every `user_id` row the owner has.
Rows that depend on those through a foreign key (for example dose events under
a medication, or files under a care provider) are deleted first, found by
following `pragma_foreign_key_list` down, so a non-cascading foreign key never
blocks the delete and nothing is left orphaned even with foreign keys off.
The `dose_events` append-only trigger (FR-019) guards history against edits;
a discard is the patient removing everything this phone holds for the
offline account (twice confirmed), so the trigger is dropped for that one
delete and re-created straight after, inside the same transaction. Rows owned
by any other account are never touched. Idempotent.

### Merging and deleting files

`UserFileStore.mergeOwnerFiles(from:, to:)`: when the existing account has
neither a file key nor a vault partition on this phone, this is
`rekeyOwnerFiles` (the partition is renamed and the key moved). Otherwise the
two owners' files can't share a key, so each offline file is decrypted with
the offline key and saved under the existing account with its own key, then
the offline copy is deleted — one file at a time, so after a crash each file
is readable under at least one owner and a re-run finishes the job. The
offline partition is removed before the offline key. Stored paths
(`<owner>/<name>.enc`) keep working: the store resolves a path by its file
name inside the active owner's partition.

`UserFileStore.deleteOwnerFiles(owner:)` removes the owner's partition and
file key. The in-memory store used on web is not partitioned by owner; both
are no-ops there.

### Controller

`GoOnlineController.merge()` and `GoOnlineController.discard()`
(`app/lib/balsm_app/auth/go_online_controller.dart`) read the device's id
from `balsm.offline.local_id` (never `balsm.user_id`, which `goOnline` has
already overwritten with the existing account's id) and the existing account's
id from `balsm.pending_merge_target`; if either is missing they return a
`ValidationFailure` and touch nothing. Then:

- **Merge** — `mergeOwner(db, from: localId, to: target)`, then
  `UserFileStore.mergeOwnerFiles(from: localId, to: target)`.
- **Discard** — refuses (`StorageFailure`) if the device id equals the target,
  so the signed-in account's own data can never be deleted; otherwise
  `discardOwner(db, owner: localId)`, then
  `UserFileStore.deleteOwnerFiles(owner: localId)`.

If the data step throws, the result is a `StorageFailure` and nothing else
changes; the screen offers a retry. After it succeeds, both: write
`balsm.user_id = target` (already true, rewritten for safety),
`clearPlainPassword()` — the existing account keeps its own password (D2);
`SetPassword` is never called — `markOnline()`, publish
`UserSignedIn(provider: 'email')` for the existing account, then
`setPendingMerge(false)` and delete `balsm.pending_merge_target` and
`balsm.offline.local_id`. Merge also sets `balsm.offline.disclosure_pending`
before clearing the pending keys and runs the disclosure resync after, exactly
as the go-online flow does (the launch retry picks up a failure). Discard
does not resync: the existing account's own acceptance is on the server.

Both are resumable: the pending keys are cleared last, so a crash anywhere
before that boots back to the merge screen (`PatientAppState.load` routes a
pending merge there), and running either choice again finishes — the data
steps find nothing left under the device id. The offline email for the
`UserSignedIn` event is read before `markOnline()` deletes it; on a resume past
that point it is empty. Nothing is logged.

### Screen (provisional)

`_MergeOrDiscardScreen` in `app/lib/balsm_app/screens/auth_flow.dart`;
`AuthRouter` maps `AppRoutes.mergeOrDiscard` to it. **Provisional:** there is
no DesignSync design for this screen yet (spec §3). Like Unlock, it is built
from existing auth pieces — cream background, title and help text, the info
card (here carrying the note that the existing account keeps its password),
and a primary ("Add this phone's data to my account") and secondary ("Remove
this phone's data") action. The copy in the `offline` string group
(`merge_*`, `discard_*`) is provisional too. Release stays blocked until the
designed screen replaces this one.

- **Merge** runs `merge()` straight away.
- **Remove** first opens a confirmation sheet (title, "can't be undone" body,
  a danger "Remove" button and Cancel); only the explicit Remove runs
  `discard()`. Cancel or dismissing the sheet does nothing.
- On success the screen sets `PatientAppState.accountMode` to `online` and
  enters the app through the same disclosure gate as every sign-in
  (`enterAfterSignIn`).
- On failure (a failed result or an unexpected exception) it stays put and
  shows `offline.merge_failed` — never the exception's text — and both
  choices stay available, so the patient can try again or choose the other.

A restart while the merge is pending boots straight back to this screen
(`PatientAppState.load` with `pendingMerge: true`).
