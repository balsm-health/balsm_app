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
