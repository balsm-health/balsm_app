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
