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
