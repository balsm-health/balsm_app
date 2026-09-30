# Offline (Device-Only) Account Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a person create a Balsm account with no network, use every on-device feature, and later verify their email so the server adopts the same account ID.

**Architecture:** The phone mints a UUIDv7 account ID and keeps an Argon2id password hash in the shared secure store; `balsm.account_mode = deviceOnly` tells bootstrap, the auth interceptor and the UI that there are no tokens. Going online is email → OTP with an optional `client_account_id`; the API provisions the account under that ID when it is free. If the server returns a different ID (collision, or the email already has an account and the user picks Merge), every local table's `user_id` is re-keyed in one transaction. PHI never leaves the device — "merge" is a local re-key, not an upload.

**Tech Stack:** .NET 10 / EF Core / xUnit + FluentAssertions (API); Flutter via `fvm`, Riverpod, drift + SQLCipher, `flutter_secure_storage`, `cryptography` (Argon2id), mocktail (app).

**Spec:** `balsm_app/docs/superpowers/specs/2026-09-30-offline-account-design.md` (decisions D1–D8).

## Global Constraints

- Password minimum is **8** characters everywhere (D5). Offline create rejects `< 8`.
- Offline password is an **app-lock gate only**; it never derives or wraps the DB key (D8).
- DB key: 32 bytes from `Random.secure()`, stored in `SecureStorageWrapper.storage` under `balsm.db.key.v2`, applied with `PRAGMA key`. No plaintext→encrypted migration (D7); a pre-fix plaintext `balsm.db` with no v2 key is deleted and recreated (app not launched).
- Device-only sync targets: `local` always; `icloud`/`gdrive` keep their current "Coming soon" state; `balsmCloud` Connect opens the Go-online sheet (D6).
- Health data never leaves the device (repo `CLAUDE.md`). Never log email, user ID, password or tokens.
- Secure-storage keys (exact): `balsm.account_mode` (`deviceOnly`|`online`), `balsm.user_id`, `balsm.offline.email`, `balsm.offline.pw_hash`, `balsm.offline.pw_plain`, `balsm.offline.lockout`, `balsm.pending_merge`, `balsm.db.key.v2`.
- Lockout: after 5 consecutive failures, waits of 30 s, 1 min, 5 min, 15 min, then 1 h (cap) for each further failure.
- All secure-storage access goes through `SecureStorageWrapper` (`packages/core/lib/src/secure_storage/secure_storage_wrapper.dart`) — never a fresh `FlutterSecureStorage()` (different Android backing file).
- UI strings go in i69n bundles (`app/lib/balsm_app/i18n/strings.i69n.jsonc` + `strings_ar.i69n.jsonc`), then `fvm dart run build_runner build` in `app/`. No inline `ar ? … : …`.
- Live auth UI is `app/lib/balsm_app/screens/auth_flow.dart`. Do **not** edit `modules/auth/lib/src/presentation/` screens (dead code). `modules/auth` application/infrastructure layers **are** live.
- Design source is DesignSync project `50dccb01-9a43-45e3-b077-cb8d0be4a1f3` (`auth.jsx` `PhoneScreen`, `GoOnlineSheet`). Subagents cannot read it — every design value needed is copied into this plan.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Any 401 while device-only** must not sign the user out or delete `balsm.user_id` (today `AuthInterceptor._doRefresh` → `_signOut` does exactly that). Pinned in Task 3.
2. **Cold start while device-only** must not wipe `balsm.user_id` for lacking a refresh token (today `main_balsm.dart` bootstrap does). Pinned in Task 8.
3. **App killed mid go-online** (after verify, before `SetPassword`, or on the merge-or-discard screen) must resume, not strand the user. Pinned in Tasks 11 and 12 (`pw_plain` retry; `pending_merge` routing).
4. **Re-key interrupted** (crash mid-transaction) must leave either all old or all new owner IDs. Pinned in Task 6 (single transaction + rollback test).
5. **Lockout survives restart** — killing the app must not reset the failure counter. Pinned in Task 4.

---

### Task 1: API — adopt a client-proposed account ID on OTP verify

Repo: `Balsm-API-DotNet`.

**Files:**
- Modify: `src/Balsm.SharedKernel/Contracts/IUserAccountProvisioner.cs`
- Modify: `src/Modules/Account/Balsm.Account.Domain/Entities/UserAccount.cs:30-31`
- Modify: `src/Modules/Account/Balsm.Account.Infrastructure/Services/UserAccountProvisioner.cs`
- Modify: `src/Modules/Auth/Balsm.Auth.Application/Commands/VerifyOtpCommand.cs`
- Modify: `src/Modules/Auth/Balsm.Auth.Infrastructure/Handlers/VerifyOtpHandler.cs`
- Modify: `src/Modules/Auth/Balsm.Auth.Api/Controllers/AuthController.cs:89-103,260`
- Modify: `docs/api/insomnia/auth.yaml`, `docs/api/openapi/v1/all.json`
- Test: `tests/Modules/Balsm.Auth.Tests/MergedAuthFlowTests.cs`

**Interfaces:**
- Produces (wire): `POST /auth/otp/verify` body gains optional `client_account_id` (UUID string); response `data` gains `adopted_client_id` (bool).
- Produces (C#): `IUserAccountProvisioner.ProvisionWithPreferredIdAsync(string countryCode, string preferredLanguage, Guid preferredId, CancellationToken ct = default) : Task<Guid>`; `VerifyOtpCommand(..., Guid? ClientAccountId = null)`; `AuthTokenResult(..., bool AdoptedClientId = false)`.

- [ ] **Step 1: Write failing tests** — append to `MergedAuthFlowTests.cs` inside the class, after the existing verify tests:

```csharp
    // ── Offline accounts: the client may propose its own id ───────────────

    private static readonly Guid OfflineId = Guid.CreateVersion7();

    [Fact]
    public async Task VerifyOtp_NewEmail_AdoptsAFreeClientId()
    {
        var code = await SeedChallengeAsync("offline@test.com");

        var result = await VerifyHandler().Handle(
            new VerifyOtpCommand("offline@test.com", code, TestDeviceId, "iPhone", OfflineId),
            CancellationToken.None);

        result.IsNewUser.Should().BeTrue();
        result.AdoptedClientId.Should().BeTrue();
        result.UserId.Should().Be(OfflineId);
        (await _accountDb.UserAccounts.AnyAsync(a => a.Id == OfflineId)).Should().BeTrue();
    }

    [Fact]
    public async Task VerifyOtp_NewEmail_TakenClientId_GetsAFreshIdNotTheOwners()
    {
        var ownerId = await SeedIdentityAsync("owner@test.com");
        var code = await SeedChallengeAsync("attacker@test.com");

        var result = await VerifyHandler().Handle(
            new VerifyOtpCommand("attacker@test.com", code, TestDeviceId, "iPhone", ownerId),
            CancellationToken.None);

        result.IsNewUser.Should().BeTrue();
        result.AdoptedClientId.Should().BeFalse();
        result.UserId.Should().NotBe(ownerId, "a known id must never attach to someone else's account");
    }

    [Fact]
    public async Task VerifyOtp_NewEmail_NonV7ClientId_GetsAFreshId()
    {
        var code = await SeedChallengeAsync("v4@test.com");
        var v4 = Guid.NewGuid();

        var result = await VerifyHandler().Handle(
            new VerifyOtpCommand("v4@test.com", code, TestDeviceId, "iPhone", v4),
            CancellationToken.None);

        result.AdoptedClientId.Should().BeFalse();
        result.UserId.Should().NotBe(v4);
    }

    [Fact]
    public async Task VerifyOtp_ExistingEmail_IgnoresClientId()
    {
        var userId = await SeedIdentityAsync("returning2@test.com");
        var code = await SeedChallengeAsync("returning2@test.com");

        var result = await VerifyHandler().Handle(
            new VerifyOtpCommand("returning2@test.com", code, TestDeviceId, "iPhone", OfflineId),
            CancellationToken.None);

        result.IsNewUser.Should().BeFalse();
        result.AdoptedClientId.Should().BeFalse();
        result.UserId.Should().Be(userId);
        (await _accountDb.UserAccounts.AnyAsync(a => a.Id == OfflineId)).Should().BeFalse();
    }

    [Fact]
    public async Task VerifyOtp_NoClientId_BehavesAsBefore()
    {
        var code = await SeedChallengeAsync("plain@test.com");

        var result = await VerifyHandler().Handle(
            new VerifyOtpCommand("plain@test.com", code, TestDeviceId, "iPhone"),
            CancellationToken.None);

        result.IsNewUser.Should().BeTrue();
        result.AdoptedClientId.Should().BeFalse();
    }
```

Replace the file-local fake at the bottom of the file (currently `file sealed class AccountProvisioner`) with one that mirrors production:

```csharp
file sealed class AccountProvisioner(AccountDbContext db) : Balsm.SharedKernel.Contracts.IUserAccountProvisioner
{
    public async Task<Guid> ProvisionAsync(string countryCode, string preferredLanguage, CancellationToken ct = default)
    {
        var account = UserAccount.Create(countryCode: countryCode, preferredLanguage: preferredLanguage);
        db.UserAccounts.Add(account);
        await db.SaveChangesAsync(ct);
        return account.Id;
    }

    public Task<Guid> ProvisionWithPreferredIdAsync(
        string countryCode, string preferredLanguage, Guid preferredId, CancellationToken ct = default) =>
        new Balsm.Account.Infrastructure.Services.UserAccountProvisioner(db)
            .ProvisionWithPreferredIdAsync(countryCode, preferredLanguage, preferredId, ct);
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `dotnet test tests/Modules/Balsm.Auth.Tests --filter "FullyQualifiedName~MergedAuthFlowTests.VerifyOtp"`
Expected: build FAIL — `VerifyOtpCommand` has no 5th parameter / `AdoptedClientId` not defined.

- [ ] **Step 3: Implement**

`IUserAccountProvisioner.cs` — add inside the interface:

```csharp
    /// <summary>
    /// Creates an account under <paramref name="preferredId"/> when that id is a
    /// UUIDv7 and unused; otherwise under a fresh id. Returns the id actually used.
    /// Never fails because the preferred id is taken — callers must not learn
    /// which ids exist.
    /// </summary>
    Task<Guid> ProvisionWithPreferredIdAsync(
        string countryCode, string preferredLanguage, Guid preferredId, CancellationToken ct = default);
```

`UserAccount.cs` — add below the existing `Create`:

```csharp
    /// Offline-created accounts: the device minted the id before the server
    /// existed in the conversation. Only the provisioner calls this, after
    /// checking the id is free.
    public static UserAccount CreateWithId(Guid id, string countryCode, string preferredLanguage)
    {
        var account = Create(countryCode, preferredLanguage);
        account.Id = id;
        return account;
    }
```

`UserAccountProvisioner.cs` — add the method (add `using Microsoft.EntityFrameworkCore;`):

```csharp
    public async Task<Guid> ProvisionWithPreferredIdAsync(
        string countryCode, string preferredLanguage, Guid preferredId, CancellationToken ct = default)
    {
        if (preferredId.Version != 7 || await db.UserAccounts.IgnoreQueryFilters().AnyAsync(a => a.Id == preferredId, ct))
            return await ProvisionAsync(countryCode, preferredLanguage, ct);

        var account = UserAccount.CreateWithId(preferredId, countryCode, preferredLanguage);
        db.UserAccounts.Add(account);
        try
        {
            await db.SaveChangesAsync(ct);
            return account.Id;
        }
        catch (DbUpdateException)
        {
            // Lost a race for the same id: fall back, never error.
            db.Entry(account).State = EntityState.Detached;
            return await ProvisionAsync(countryCode, preferredLanguage, ct);
        }
    }
```

`VerifyOtpCommand.cs`:

```csharp
public sealed record VerifyOtpCommand(
    string Email, string Code, Guid DeviceId, string DeviceLabel,
    Guid? ClientAccountId = null) : IRequest<AuthTokenResult>;

public sealed record AuthTokenResult(
    string AccessToken, string RefreshToken, Guid UserId, bool IsNewUser,
    bool AdoptedClientId = false);
```

`VerifyOtpHandler.cs` — replace the `else` branch and the return:

```csharp
        else
        {
            userId = cmd.ClientAccountId is { } proposed
                ? await accountProvisioner.ProvisionWithPreferredIdAsync("EG", "ar-EG", proposed, ct)
                : await accountProvisioner.ProvisionAsync("EG", "ar-EG", ct);
            var identity = UserIdentity.Create(userId, "email", email, email);
            identity.ConfirmEmail(DateTime.UtcNow);
            authDb.UserIdentities.Add(identity);
        }
```

```csharp
        var adopted = isNewUser && cmd.ClientAccountId is { } asked && asked == userId;
        return new AuthTokenResult(accessToken, refreshRaw, userId, IsNewUser: isNewUser, AdoptedClientId: adopted);
```

`AuthController.cs` — request record and mapping:

```csharp
public sealed record VerifyOtpRequest(string Email, string Code, Guid DeviceId, string DeviceLabel, Guid? ClientAccountId = null);
```

```csharp
        var result = await mediator.Send(
            new VerifyOtpCommand(req.Email, req.Code, req.DeviceId, req.DeviceLabel, req.ClientAccountId), ct);
```

and inside the response `data` object add `adopted_client_id = result.AdoptedClientId`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `dotnet test tests/Modules/Balsm.Auth.Tests`
Expected: all PASS (new five plus every existing test — `AuthFlowTests.cs` has its own fake provisioner; if it fails to compile, add the same `ProvisionWithPreferredIdAsync` delegating method to it).

- [ ] **Step 5: Update API docs**

In `docs/api/openapi/v1/all.json`, find the `/auth/otp/verify` request schema and add property `"client_account_id": { "type": "string", "format": "uuid", "nullable": true, "description": "Offline-created account id (UUIDv7). Adopted only for a new email when unused." }`; in its response `data` schema add `"adopted_client_id": { "type": "boolean" }`. In `docs/api/insomnia/auth.yaml`, add `"client_account_id": null` to the verify example body.

- [ ] **Step 6: Commit**

```bash
git add src tests docs/api
git commit -m "feat(auth): adopt client-proposed account id on OTP verify

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Core — actually encrypt the on-device database

Repo: `balsm_app`.

**Files:**
- Create: `packages/core/lib/src/db/db_key.dart`
- Modify: `packages/core/lib/src/db/database_connection_io.dart:27-40`
- Test: `packages/core/test/db/db_key_test.dart`

**Interfaces:**
- Produces: `String generateDbKeyHex([Random? random])` (64 lowercase hex chars); `const kDbKeyStorageKey = 'balsm.db.key.v2'`.

- [ ] **Step 1: Write the failing test** — `packages/core/test/db/db_key_test.dart`:

```dart
import 'dart:math';

import 'package:core/src/db/db_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is 64 lowercase hex chars', () {
    expect(generateDbKeyHex(), matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('is not a repeated byte (regression: microsecond-filled key)', () {
    final key = generateDbKeyHex();
    final bytes = {for (var i = 0; i < 64; i += 2) key.substring(i, i + 2)};
    expect(bytes.length, greaterThan(8));
  });

  test('two keys differ', () {
    expect(generateDbKeyHex(), isNot(generateDbKeyHex()));
  });

  test('uses the given source', () {
    expect(generateDbKeyHex(Random(1)), generateDbKeyHex(Random(1)));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd packages/core && fvm flutter test test/db/db_key_test.dart`
Expected: FAIL — `db_key.dart` not found.

- [ ] **Step 3: Implement** — `packages/core/lib/src/db/db_key.dart`:

```dart
import 'dart:math';

/// Secure-storage key for the SQLCipher key. `.v2` because the v1 key was
/// never applied and was not random; it must not be reused.
const kDbKeyStorageKey = 'balsm.db.key.v2';

/// 32 random bytes as hex. [random] is for tests only; production uses
/// [Random.secure].
String generateDbKeyHex([Random? random]) {
  final r = random ?? Random.secure();
  return List<int>.generate(32, (_) => r.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}
```

Replace `openExecutor` in `database_connection_io.dart`:

```dart
import '../secure_storage/secure_storage_wrapper.dart';
import 'db_key.dart';

/// Native (iOS/Android/desktop) executor — the real on-device SQLCipher store.
QueryExecutor openExecutor() => LazyDatabase(() async {
      _ensureSqlCipherLoaded();
      // The shared store — see SecureStorageWrapper for why a fresh
      // FlutterSecureStorage() reads a different file on Android.
      const storage = SecureStorageWrapper.storage;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/balsm.db');

      var key = await storage.read(key: kDbKeyStorageKey);
      if (key == null) {
        // Pre-launch builds wrote an unencrypted balsm.db. It cannot be opened
        // with a key, and there are no real users to migrate (spec D7).
        if (file.existsSync()) file.deleteSync();
        key = generateDbKeyHex();
        await storage.write(key: kDbKeyStorageKey, value: key);
      }
      final hexKey = key;
      return NativeDatabase(
        file,
        setup: (db) {
          db.execute("PRAGMA key = \"x'$hexKey'\"");
          // Fails loudly if SQLCipher isn't the loaded sqlite (plain sqlite
          // returns no row here and would silently store plaintext).
          final v = db.select('PRAGMA cipher_version');
          if (v.isEmpty) throw StateError('SQLCipher not loaded; refusing to open an unencrypted database');
        },
      );
    });
```

Delete the now-unused `flutter_secure_storage` import if the analyzer flags it.

- [ ] **Step 4: Run tests**

Run: `cd packages/core && fvm flutter test test/db/db_key_test.dart && fvm flutter analyze`
Expected: PASS, no analyzer issues.

- [ ] **Step 5: Manual device check** (record result in the PR)

Install on the iOS simulator, add a medication, then: `find ~/Library/Developer/CoreSimulator -name balsm.db -newer /tmp -exec sqlite3 {} .tables \;`
Expected: `Error: file is not a database`.

- [ ] **Step 6: Commit**

```bash
git add packages/core/lib/src/db packages/core/test/db
git commit -m "fix(core): apply a random SQLCipher key to the on-device DB

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Core — account mode, and an interceptor that never signs a device-only user out

**Files:**
- Create: `packages/core/lib/src/auth_context/account_mode.dart`
- Modify: `packages/core/lib/core.dart` (export)
- Modify: `packages/core/lib/src/network/auth_interceptor.dart:78-92,135-141`
- Test: `packages/core/test/auth_context/account_mode_test.dart`, `packages/core/test/network/auth_interceptor_test.dart`

**Interfaces:**
- Produces: `enum AccountMode { online, deviceOnly }` with `String get wire` and `static AccountMode fromWire(String?)` (null/unknown → `online`); `const kAccountModeKey = 'balsm.account_mode'`; `class DeviceOnlyAccountException implements Exception`.

- [ ] **Step 1: Write failing tests**

`packages/core/test/auth_context/account_mode_test.dart`:

```dart
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wire round-trip', () {
    for (final m in AccountMode.values) {
      expect(AccountMode.fromWire(m.wire), m);
    }
  });
  test('missing or unknown means online (existing installs)', () {
    expect(AccountMode.fromWire(null), AccountMode.online);
    expect(AccountMode.fromWire('garbage'), AccountMode.online);
  });
}
```

Append to `packages/core/test/network/auth_interceptor_test.dart` inside `main()` (reuse its `storageWith`, `_FakeAdapter`, `_json` helpers and the way existing tests build the client + interceptor — copy the construction lines from the nearest existing `test(` block):

```dart
  group('device-only account', () {
    test('an authenticated request is refused locally, never sent', () async {
      final storage = storageWith({'balsm.account_mode': 'deviceOnly', 'balsm.user_id': 'u1'});
      final adapter = _FakeAdapter((_) => _json('{}'));
      final bus = EventBus();
      final events = <AppEvent>[];
      bus.on<SessionExpired>().listen(events.add);
      final client = BalsmApiClient(baseUrl: 'https://x.test')..dio.httpClientAdapter = adapter;
      client.dio.interceptors.add(AuthInterceptor(client: client, storage: storage, bus: bus));

      await expectLater(
        client.dio.get<void>('/account/me'),
        throwsA(isA<DioException>().having((e) => e.error, 'error', isA<DeviceOnlyAccountException>())),
      );
      expect(adapter.requests, isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      expect(await storage.read(key: 'balsm.user_id'), 'u1');
    });

    test('bootstrap (OTP) requests still go out', () async {
      final storage = storageWith({'balsm.account_mode': 'deviceOnly'});
      final adapter = _FakeAdapter((_) => _json('{"data":{}}'));
      final client = BalsmApiClient(baseUrl: 'https://x.test')..dio.httpClientAdapter = adapter;
      client.dio.interceptors.add(AuthInterceptor(client: client, storage: storage, bus: EventBus()));

      await client.dio.post<void>('/auth/otp/request', data: const {});
      expect(adapter.requests, hasLength(1));
    });
  });
```

If `BalsmApiClient`'s constructor differs from `BalsmApiClient(baseUrl: …)`, use exactly what the existing tests in this file use.

- [ ] **Step 2: Run to verify they fail**

Run: `cd packages/core && fvm flutter test test/auth_context/account_mode_test.dart test/network/auth_interceptor_test.dart`
Expected: FAIL — `AccountMode` / `DeviceOnlyAccountException` undefined.

- [ ] **Step 3: Implement**

`packages/core/lib/src/auth_context/account_mode.dart`:

```dart
/// Whether the signed-in account has server credentials.
///
/// `deviceOnly` accounts were created offline: they have a `balsm.user_id`
/// but no access/refresh token, and must never reach an authenticated
/// endpoint (a 401 there would run the sign-out path and orphan their data).
enum AccountMode {
  online,
  deviceOnly;

  String get wire => name;

  static AccountMode fromWire(String? v) => v == deviceOnly.name ? deviceOnly : online;
}

/// Secure-storage key holding [AccountMode.wire].
const kAccountModeKey = 'balsm.account_mode';

/// Raised locally instead of sending an authenticated request for a
/// device-only account. Callers treat it like being offline.
class DeviceOnlyAccountException implements Exception {
  const DeviceOnlyAccountException();
  @override
  String toString() => 'DeviceOnlyAccountException';
}
```

Export from `packages/core/lib/core.dart`: `export 'src/auth_context/account_mode.dart';`

In `auth_interceptor.dart` add `import '../auth_context/account_mode.dart';` and change `onRequest`:

```dart
  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isBootstrap(options.path)) {
      if (AccountMode.fromWire(await _storage.read(key: kAccountModeKey)) == AccountMode.deviceOnly) {
        return handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: const DeviceOnlyAccountException(),
        ));
      }
      var token = await _storage.read(key: _kAccess);
```

(rest of the method unchanged). In `_doRefresh`, before the existing `if (refresh == null …)` guard:

```dart
    if (AccountMode.fromWire(await _storage.read(key: kAccountModeKey)) == AccountMode.deviceOnly) {
      return null; // no session to refresh, and nothing to sign out of
    }
```

- [ ] **Step 4: Run tests**

Run: `cd packages/core && fvm flutter test && fvm flutter analyze`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/core
git commit -m "feat(core): account mode; interceptor refuses device-only requests locally

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Auth module — offline account service (create, unlock, lockout)

**Files:**
- Create: `modules/auth/lib/src/application/offline/offline_password_hasher.dart`
- Create: `modules/auth/lib/src/application/offline/offline_account_service.dart`
- Modify: `modules/auth/pubspec.yaml` (add `cryptography` at the version already in `packages/core/pubspec.yaml`)
- Modify: `modules/auth/lib/auth.dart` (exports)
- Modify: `modules/auth/lib/src/presentation/providers/auth_providers.dart` (provider)
- Test: `modules/auth/test/application/offline_account_service_test.dart`

**Interfaces:**
- Consumes: `SecureStorageWrapper` (`readToken/writeToken/deleteToken`), `AccountMode`, `kAccountModeKey`, `EventBus`, `UserSignedIn(userId:, email:, provider:)`, `UuidV7.generate()`, `UserId.value(String)` — all from `core`.
- Produces:
  - `abstract class OfflinePasswordHasher { Future<String> hash(String pw); Future<bool> verify(String pw, String encoded); }` and `Argon2idOfflinePasswordHasher`.
  - `class OfflineAccountService({required SecureStorageWrapper storage, required OfflinePasswordHasher hasher, required EventBus eventBus, DateTime Function()? now})` with:
    - `Future<String> create({required String email, required String password})` → new account id; throws `ArgumentError` if `password.length < 8`.
    - `Future<UnlockResult> unlock(String password)`; `sealed class UnlockResult` = `Unlocked` | `WrongPassword(int failures)` | `LockedUntil(DateTime until)`.
    - `Future<LockedUntil?> lockout()`.
    - `Future<AccountMode> mode()`.
    - `Future<({String email, String password})?> pendingCredentials()` → from `balsm.offline.email` / `balsm.offline.pw_plain`.
    - `Future<void> clearPlainPassword()`.
    - `Future<void> markOnline()` → mode `online`, deletes `balsm.offline.email`, `pw_hash`, `lockout` (keeps `pw_plain` — Task 11 clears it after `SetPassword`).
    - `Future<void> setPendingMerge(bool)`, `Future<bool> pendingMerge()`.
    - `Future<void> wipe()` → deletes every `balsm.offline.*` key, `balsm.pending_merge`, `balsm.account_mode`, `balsm.user_id`.
  - `final offlineAccountServiceProvider = Provider<OfflineAccountService>`.

- [ ] **Step 1: Write the failing test** — `modules/auth/test/application/offline_account_service_test.dart`:

```dart
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MemStorage extends Mock implements SecureStorageWrapper {
  final m = <String, String>{};
  @override
  Future<String?> readToken(String key) async => m[key];
  @override
  Future<void> writeToken(String key, String value) async => m[key] = value;
  @override
  Future<void> deleteToken(String key) async => m.remove(key);
}

/// Fast stand-in: Argon2id itself is exercised in the last test.
class _PlainHasher implements OfflinePasswordHasher {
  @override
  Future<String> hash(String pw) async => 'h:$pw';
  @override
  Future<bool> verify(String pw, String encoded) async => encoded == 'h:$pw';
}

void main() {
  late _MemStorage storage;
  late EventBus bus;
  late DateTime clock;
  late OfflineAccountService svc;

  setUp(() {
    storage = _MemStorage();
    bus = EventBus();
    clock = DateTime.utc(2026, 10, 1, 12);
    svc = OfflineAccountService(storage: storage, hasher: _PlainHasher(), eventBus: bus, now: () => clock);
  });

  test('create stores id, mode, email, hash and plaintext; publishes UserSignedIn', () async {
    final events = <UserSignedIn>[];
    bus.on<UserSignedIn>().listen(events.add);

    final id = await svc.create(email: ' Layla@Example.com ', password: 'correct-horse');
    await Future<void>.delayed(Duration.zero);

    expect(storage.m['balsm.user_id'], id);
    expect(storage.m['balsm.account_mode'], 'deviceOnly');
    expect(storage.m['balsm.offline.email'], 'layla@example.com');
    expect(storage.m['balsm.offline.pw_hash'], 'h:correct-horse');
    expect(storage.m['balsm.offline.pw_plain'], 'correct-horse');
    expect(events.single.userId.value, id);
    expect(await svc.mode(), AccountMode.deviceOnly);
  });

  test('create rejects passwords under 8', () async {
    await expectLater(svc.create(email: 'a@b.co', password: '1234567'), throwsArgumentError);
    expect(storage.m, isEmpty);
  });

  test('unlock with the right password resets failures', () async {
    await svc.create(email: 'a@b.co', password: 'correct-horse');
    await svc.unlock('wrong-one');
    expect(await svc.unlock('correct-horse'), isA<Unlocked>());
    expect(storage.m.containsKey('balsm.offline.lockout'), isFalse);
  });

  test('five failures lock for 30s, then 1m, 5m, 15m, 1h cap', () async {
    await svc.create(email: 'a@b.co', password: 'correct-horse');
    for (var i = 1; i <= 4; i++) {
      expect(await svc.unlock('nope'), isA<WrongPassword>());
    }
    const waits = [30, 60, 300, 900, 3600, 3600];
    for (final secs in waits) {
      final r = await svc.unlock('nope');
      expect(r, isA<LockedUntil>());
      expect((r as LockedUntil).until, clock.add(Duration(seconds: secs)));
      clock = r.until; // wait it out
    }
  });

  test('while locked out, even the right password is refused', () async {
    await svc.create(email: 'a@b.co', password: 'correct-horse');
    for (var i = 0; i < 5; i++) {
      await svc.unlock('nope');
    }
    expect(await svc.unlock('correct-horse'), isA<LockedUntil>());
  });

  test('lockout survives a new service instance (app restart)', () async {
    await svc.create(email: 'a@b.co', password: 'correct-horse');
    for (var i = 0; i < 5; i++) {
      await svc.unlock('nope');
    }
    final restarted = OfflineAccountService(storage: storage, hasher: _PlainHasher(), eventBus: bus, now: () => clock);
    expect(await restarted.lockout(), isNotNull);
  });

  test('markOnline keeps id and plaintext, drops offline-only keys', () async {
    final id = await svc.create(email: 'a@b.co', password: 'correct-horse');
    await svc.markOnline();
    expect(storage.m['balsm.user_id'], id);
    expect(storage.m['balsm.account_mode'], 'online');
    expect(storage.m['balsm.offline.pw_plain'], 'correct-horse');
    expect(storage.m.keys.where((k) => k.startsWith('balsm.offline.') && k != 'balsm.offline.pw_plain'), isEmpty);
    await svc.clearPlainPassword();
    expect(await svc.pendingCredentials(), isNull);
  });

  test('wipe removes every offline key and the user id', () async {
    await svc.create(email: 'a@b.co', password: 'correct-horse');
    await svc.setPendingMerge(true);
    await svc.wipe();
    expect(storage.m, isEmpty);
  });

  test('Argon2id hasher round-trips and rejects a wrong password', () async {
    final h = Argon2idOfflinePasswordHasher();
    final enc = await h.hash('correct-horse');
    expect(enc, startsWith(r'$argon2id$'));
    expect(await h.verify('correct-horse', enc), isTrue);
    expect(await h.verify('correct-hors3', enc), isFalse);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd modules/auth && fvm flutter test test/application/offline_account_service_test.dart`
Expected: FAIL — `OfflineAccountService` undefined.

- [ ] **Step 3: Implement**

`offline_password_hasher.dart`:

```dart
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

abstract class OfflinePasswordHasher {
  Future<String> hash(String password);
  Future<bool> verify(String password, String encoded);
}

/// Argon2id, PHC-style string: `$argon2id$v=19$m=19456,t=2,p=1$<salt>$<hash>`.
/// Parameters are OWASP's minimum for Argon2id (19 MiB, 2 passes, 1 lane).
class Argon2idOfflinePasswordHasher implements OfflinePasswordHasher {
  static const _m = 19456, _t = 2, _p = 1, _len = 32;

  Argon2id get _algo => Argon2id(memory: _m, iterations: _t, parallelism: _p, hashLength: _len);

  @override
  Future<String> hash(String password) async {
    final r = Random.secure();
    final salt = List<int>.generate(16, (_) => r.nextInt(256));
    final key = await _algo.deriveKeyFromPassword(password: password, nonce: salt);
    final bytes = await key.extractBytes();
    String b64(List<int> v) => base64.encode(v).replaceAll('=', '');
    return '\$argon2id\$v=19\$m=$_m,t=$_t,p=$_p\$${b64(salt)}\$${b64(bytes)}';
  }

  @override
  Future<bool> verify(String password, String encoded) async {
    final parts = encoded.split(r'$');
    if (parts.length != 6 || parts[1] != 'argon2id') return false;
    List<int> unb64(String s) => base64.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));
    final salt = unb64(parts[4]);
    final expected = unb64(parts[5]);
    final key = await _algo.deriveKeyFromPassword(password: password, nonce: salt);
    final actual = await key.extractBytes();
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }
}
```

`offline_account_service.dart`:

```dart
import 'dart:convert';

import 'package:core/core.dart';

import 'offline_password_hasher.dart';

sealed class UnlockResult {
  const UnlockResult();
}

class Unlocked extends UnlockResult {
  const Unlocked();
}

class WrongPassword extends UnlockResult {
  const WrongPassword(this.failures);
  final int failures;
}

class LockedUntil extends UnlockResult {
  const LockedUntil(this.until);
  final DateTime until;
}

/// Device-only account: created with no network, unlocked by a password that
/// is checked on the device. PHI constraint: never log email, id or password.
class OfflineAccountService {
  OfflineAccountService({
    required SecureStorageWrapper storage,
    required OfflinePasswordHasher hasher,
    required EventBus eventBus,
    DateTime Function()? now,
  })  : _s = storage,
        _hasher = hasher,
        _bus = eventBus,
        _now = now ?? (() => DateTime.now().toUtc());

  final SecureStorageWrapper _s;
  final OfflinePasswordHasher _hasher;
  final EventBus _bus;
  final DateTime Function() _now;

  static const kUserId = 'balsm.user_id';
  static const kEmail = 'balsm.offline.email';
  static const kHash = 'balsm.offline.pw_hash';
  static const kPlain = 'balsm.offline.pw_plain';
  static const kLockout = 'balsm.offline.lockout';
  static const kPendingMerge = 'balsm.pending_merge';

  static const minPasswordLength = 8;
  static const _freeAttempts = 4; // the 5th failure starts the first wait
  static const _waits = [30, 60, 300, 900, 3600];

  Future<String> create({required String email, required String password}) async {
    if (password.length < minPasswordLength) {
      throw ArgumentError.value('<redacted>', 'password', 'must be at least $minPasswordLength characters');
    }
    final id = UuidV7.generate().toString();
    final normalized = email.trim().toLowerCase();
    final hash = await _hasher.hash(password);
    await _s.writeToken(kEmail, normalized);
    await _s.writeToken(kHash, hash);
    await _s.writeToken(kPlain, password);
    await _s.writeToken(kUserId, id);
    // Mode last: a crash before this leaves an ordinary signed-out install.
    await _s.writeToken(kAccountModeKey, AccountMode.deviceOnly.wire);
    _bus.publish(UserSignedIn(userId: UserId.value(id), email: normalized, provider: 'device'));
    return id;
  }

  Future<AccountMode> mode() async => AccountMode.fromWire(await _s.readToken(kAccountModeKey));

  Future<LockedUntil?> lockout() async {
    final st = await _readLockout();
    if (st.until != null && _now().isBefore(st.until!)) return LockedUntil(st.until!);
    return null;
  }

  Future<UnlockResult> unlock(String password) async {
    final locked = await lockout();
    if (locked != null) return locked;
    final hash = await _s.readToken(kHash);
    if (hash != null && await _hasher.verify(password, hash)) {
      await _s.deleteToken(kLockout);
      return const Unlocked();
    }
    final st = await _readLockout();
    final failures = st.failures + 1;
    DateTime? until;
    if (failures > _freeAttempts) {
      final i = (failures - _freeAttempts - 1).clamp(0, _waits.length - 1);
      until = _now().add(Duration(seconds: _waits[i]));
    }
    await _s.writeToken(kLockout, jsonEncode({'failures': failures, 'until': until?.toIso8601String()}));
    return until == null ? WrongPassword(failures) : LockedUntil(until);
  }

  Future<({String email, String password})?> pendingCredentials() async {
    final pw = await _s.readToken(kPlain);
    if (pw == null) return null;
    return (email: await _s.readToken(kEmail) ?? '', password: pw);
  }

  Future<void> clearPlainPassword() => _s.deleteToken(kPlain);

  Future<void> markOnline() async {
    await _s.writeToken(kAccountModeKey, AccountMode.online.wire);
    await _s.deleteToken(kEmail);
    await _s.deleteToken(kHash);
    await _s.deleteToken(kLockout);
  }

  Future<void> setPendingMerge(bool pending) =>
      pending ? _s.writeToken(kPendingMerge, 'true') : _s.deleteToken(kPendingMerge);

  Future<bool> pendingMerge() async => await _s.readToken(kPendingMerge) == 'true';

  Future<void> wipe() async {
    for (final k in [kEmail, kHash, kPlain, kLockout, kPendingMerge, kAccountModeKey, kUserId]) {
      await _s.deleteToken(k);
    }
  }

  Future<({int failures, DateTime? until})> _readLockout() async {
    final raw = await _s.readToken(kLockout);
    if (raw == null) return (failures: 0, until: null);
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final u = m['until'] as String?;
    return (failures: m['failures'] as int? ?? 0, until: u == null ? null : DateTime.parse(u));
  }
}
```

Note the lockout test expects the 5th failure → 30 s, 6th → 60 s, …, 9th and later → 3600 s: `failures - 5` indexes `_waits` (5→0, 6→1, 7→2, 8→3, 9+→4).

Add to `modules/auth/lib/auth.dart`:

```dart
export 'src/application/offline/offline_account_service.dart';
export 'src/application/offline/offline_password_hasher.dart';
```

Add to `auth_providers.dart`:

```dart
final offlineAccountServiceProvider = Provider<OfflineAccountService>((ref) {
  return OfflineAccountService(
    storage: ref.watch(secureStorageProvider),
    hasher: Argon2idOfflinePasswordHasher(),
    eventBus: ref.watch(eventBusProvider),
  );
});
```

- [ ] **Step 4: Run tests**

Run: `cd modules/auth && fvm flutter pub get && fvm flutter test && fvm flutter analyze`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/auth
git commit -m "feat(auth): offline account service with Argon2id unlock and lockout

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: API client + sign-in use case — go online with a client ID

**Files:**
- Modify: `packages/balsm_api/lib/src/auth/requests.dart:32-49` (`VerifyOtpRequest`)
- Modify: `packages/balsm_api/lib/src/auth/responses.dart:4-23` (`AuthTokensResponse`)
- Modify: `packages/balsm_api/lib/src/transport/non_phi_allowlist.dart:38` (allow `adopted_client_id` in logs; `client_account_id` stays redacted)
- Modify: `modules/auth/lib/src/infrastructure/api/balsm_auth_adapter.dart`
- Modify: `modules/auth/lib/src/application/use_cases/sign_in_use_case.dart`
- Test: `packages/balsm_api/test/auth/dio_auth_api_test.dart`, `modules/auth/test/application/sign_in_use_case_test.dart`

**Interfaces:**
- Consumes: wire contract from Task 1.
- Produces:
  - `VerifyOtpRequest({…, String? clientAccountId})` → emits `client_account_id` only when non-null.
  - `AuthTokensResponse.adoptedClientId` (bool, default false).
  - `BalsmAuthAdapter.verifyOtpClaim(String email, String code, String deviceId, String deviceLabel, String clientAccountId)` → `Future<({AuthTokens tokens, bool adoptedClientId})>`.
  - `SignInUseCase.goOnline({required String email, required String code, required String clientAccountId})` → `Future<AppResult<GoOnlineResult>>`; `sealed class GoOnlineResult` = `GoOnlineAdopted` | `GoOnlineNewId(String userId)` | `GoOnlineExistingAccount(String userId)` | `GoOnlineLockout(LockedOut session)`.
  - `goOnline` persists tokens exactly like `verifyEmailOtp`, but does **not** publish `UserSignedIn` (the id switch is published by the caller after any re-key).

- [ ] **Step 1: Write failing tests**

Append to `packages/balsm_api/test/auth/dio_auth_api_test.dart` (follow the file's existing verify test for the fake adapter setup):

```dart
  test('VerifyOtpRequest sends client_account_id only when set', () {
    expect(const VerifyOtpRequest(email: 'e', code: 'c', deviceId: 'd', deviceLabel: 'l').toJson(),
        isNot(contains('client_account_id')));
    expect(const VerifyOtpRequest(email: 'e', code: 'c', deviceId: 'd', deviceLabel: 'l', clientAccountId: 'x').toJson()['client_account_id'],
        'x');
  });

  test('AuthTokensResponse reads adopted_client_id, defaulting false', () {
    final base = {'access_token': 'a', 'refresh_token': 'r', 'user_id': 'u'};
    expect(AuthTokensResponse.fromJson(base).adoptedClientId, isFalse);
    expect(AuthTokensResponse.fromJson({...base, 'adopted_client_id': true}).adoptedClientId, isTrue);
  });
```

Append to `modules/auth/test/application/sign_in_use_case_test.dart` inside `main()` (reuse its `adapter`, `storage`, `bus`, `events`, `usecase` from `setUp`; mirror how existing tests stub `storage.readToken(_did)`):

```dart
  group('goOnline', () {
    ({AuthTokens tokens, bool adoptedClientId}) claim({required String userId, required bool isNew, required bool adopted}) => (
          tokens: (accessToken: 'at', refreshToken: 'rt', userId: userId, isNewUser: isNew),
          adoptedClientId: adopted,
        );

    setUp(() {
      when(() => storage.readToken(_did)).thenAnswer((_) async => 'device-1');
      when(() => storage.writeToken(any(), any())).thenAnswer((_) async {});
    });

    test('adopted → GoOnlineAdopted, tokens persisted, no UserSignedIn yet', () async {
      when(() => adapter.verifyOtpClaim('a@b.co', '123456', 'device-1', any(), 'off-1'))
          .thenAnswer((_) async => claim(userId: 'off-1', isNew: true, adopted: true));

      final r = await usecase.goOnline(email: 'a@b.co', code: '123456', clientAccountId: 'off-1');

      expect(r.valueOrNull, isA<GoOnlineAdopted>());
      verify(() => storage.writeToken(_at, 'at')).called(1);
      verify(() => storage.writeToken(_rt, 'rt')).called(1);
      verify(() => storage.writeToken(_uid, 'off-1')).called(1);
      expect(events.whereType<UserSignedIn>(), isEmpty);
    });

    test('new account under a different id → GoOnlineNewId', () async {
      when(() => adapter.verifyOtpClaim(any(), any(), any(), any(), any()))
          .thenAnswer((_) async => claim(userId: 'srv-9', isNew: true, adopted: false));
      final r = await usecase.goOnline(email: 'a@b.co', code: '123456', clientAccountId: 'off-1');
      expect((r.valueOrNull as GoOnlineNewId).userId, 'srv-9');
    });

    test('existing account → GoOnlineExistingAccount', () async {
      when(() => adapter.verifyOtpClaim(any(), any(), any(), any(), any()))
          .thenAnswer((_) async => claim(userId: 'srv-1', isNew: false, adopted: false));
      final r = await usecase.goOnline(email: 'a@b.co', code: '123456', clientAccountId: 'off-1');
      expect((r.valueOrNull as GoOnlineExistingAccount).userId, 'srv-1');
    });
  });
```

If `AppResult` has no `valueOrNull`, use the accessor the existing tests in this file use to read a success value.

- [ ] **Step 2: Run to verify they fail**

Run: `cd packages/balsm_api && fvm flutter test test/auth/dio_auth_api_test.dart; cd ../../modules/auth && fvm flutter test test/application/sign_in_use_case_test.dart`
Expected: FAIL — unknown `clientAccountId`, `adoptedClientId`, `verifyOtpClaim`, `goOnline`.

- [ ] **Step 3: Implement**

`requests.dart` `VerifyOtpRequest`:

```dart
class VerifyOtpRequest {
  const VerifyOtpRequest({
    required this.email,
    required this.code,
    required this.deviceId,
    required this.deviceLabel,
    this.clientAccountId,
  });
  final String email;
  final String code;
  final String deviceId;
  final String deviceLabel;

  /// Offline-created account id the server may adopt (new emails only).
  final String? clientAccountId;

  Map<String, dynamic> toJson() => {
        'email': email,
        'code': code,
        'device_id': deviceId,
        'device_label': deviceLabel,
        if (clientAccountId != null) 'client_account_id': clientAccountId,
      };
}
```

`responses.dart` `AuthTokensResponse`: add `this.adoptedClientId = false,` to the constructor, `final bool adoptedClientId;`, and in `fromJson`: `adoptedClientId: (json['adopted_client_id'] as bool?) ?? false,`.

`non_phi_allowlist.dart:38`: add `'adopted_client_id',` to the list next to `'is_new_user'`.

`balsm_auth_adapter.dart` — add after `verifyOtp`:

```dart
  /// POST /auth/otp/verify for a device-only account going online. Returns
  /// whether the server kept the device's id.
  Future<({AuthTokens tokens, bool adoptedClientId})> verifyOtpClaim(
    String email,
    String code,
    String deviceId,
    String deviceLabel,
    String clientAccountId, {
    CancelToken? cancelToken,
  }) =>
      _guard(() async {
        final r = await _api.verifyOtp(
          VerifyOtpRequest(
            email: email,
            code: code,
            deviceId: deviceId,
            deviceLabel: deviceLabel,
            clientAccountId: clientAccountId,
          ),
          cancelToken: cancelToken,
        );
        return (tokens: _toAuthTokens(r), adoptedClientId: r.adoptedClientId);
      });
```

`sign_in_use_case.dart` — add result types near `SignInResult`:

```dart
sealed class GoOnlineResult {
  const GoOnlineResult();
}

/// Server kept the device's id: nothing to re-key.
class GoOnlineAdopted extends GoOnlineResult {
  const GoOnlineAdopted();
}

/// New server account under a different id (collision): re-key locally.
class GoOnlineNewId extends GoOnlineResult {
  const GoOnlineNewId(this.userId);
  final String userId;
}

/// The email already had an account; the user must choose merge or discard.
class GoOnlineExistingAccount extends GoOnlineResult {
  const GoOnlineExistingAccount(this.userId);
  final String userId;
}

class GoOnlineLockout extends GoOnlineResult {
  const GoOnlineLockout(this.session);
  final LockedOut session;
}
```

(`LockedOut` here is the existing session type used by `SignInLockout`. Task 4's unlock result is deliberately named `LockedUntil` to avoid clashing with it.)

Add the method after `verifyEmailOtp`:

```dart
  /// Device-only account going online. Persists the session like
  /// [verifyEmailOtp] but leaves publishing [UserSignedIn] to the caller,
  /// which may first need to re-key local data to the returned id.
  Future<AppResult<GoOnlineResult>> goOnline({
    required String email,
    required String code,
    required String clientAccountId,
  }) async {
    try {
      final deviceId = await _ensureDeviceId();
      final r = await _adapter.verifyOtpClaim(email, code, deviceId, _deviceLabel(), clientAccountId);
      await _persistTokens(
        accessToken: r.tokens.accessToken,
        refreshToken: r.tokens.refreshToken,
        userId: r.tokens.userId,
      );
      if (!r.tokens.isNewUser) return AppResult.success(GoOnlineExistingAccount(r.tokens.userId));
      if (r.adoptedClientId) return AppResult.success(const GoOnlineAdopted());
      return AppResult.success(GoOnlineNewId(r.tokens.userId));
    } on AuthException catch (e) {
      if (e.code == 'account_locked') {
        final locked = await _handleLockout(e, email);
        final v = locked.valueOrNull;
        if (v is SignInLockout) return AppResult.success(GoOnlineLockout(v.session));
      }
      return AppResult.failure(NetworkFailure(e.message));
    } catch (_) {
      return AppResult.failure(const NetworkFailure());
    }
  }
```

(Adapt `locked.valueOrNull` to however `_handleLockout`'s `AppResult` is unwrapped elsewhere in this file.)

- [ ] **Step 4: Run tests**

Run: `cd packages/balsm_api && fvm flutter test && cd ../../modules/auth && fvm flutter test && fvm flutter analyze`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/balsm_api modules/auth
git commit -m "feat(auth): goOnline verifies OTP with the device's account id

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Core — re-key local data to a new owner id

**Files:**
- Create: `packages/core/lib/src/db/owner_rekey.dart`
- Modify: `packages/core/lib/core.dart` (export)
- Test: `packages/core/test/db/owner_rekey_test.dart`

**Interfaces:**
- Produces: `Future<int> rekeyOwner(GeneratedDatabase db, {required String from, required String to, required bool dropOutbox})` — updates `user_id` in every table that has that column, in one transaction; returns rows changed. When `dropOutbox` is true, deletes `sync_outbox` rows owned by `from` instead of re-keying them (merge: the retired offline account's pending account-level updates must not overwrite the existing account's server profile).

- [ ] **Step 1: Write the failing test** — `packages/core/test/db/owner_rekey_test.dart`:

```dart
import 'package:core/core.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Db extends GeneratedDatabase {
  _Db() : super(NativeDatabase.memory());
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  int get schemaVersion => 1;
}

Future<_Db> _seed() async {
  final db = _Db();
  await db.customStatement('CREATE TABLE health_profile (id TEXT, user_id TEXT)');
  await db.customStatement('CREATE TABLE prescription (id TEXT, user_id TEXT)');
  await db.customStatement('CREATE TABLE sync_outbox (id INTEGER PRIMARY KEY, user_id TEXT)');
  await db.customStatement('CREATE TABLE lookup (id TEXT)'); // no user_id: untouched
  await db.customStatement("INSERT INTO health_profile VALUES ('p1','off'), ('p2','other')");
  await db.customStatement("INSERT INTO prescription VALUES ('r1','off')");
  await db.customStatement("INSERT INTO sync_outbox (user_id) VALUES ('off'), ('other')");
  await db.customStatement("INSERT INTO lookup VALUES ('x')");
  return db;
}

Future<List<String?>> _owners(_Db db, String table) async =>
    (await db.customSelect('SELECT user_id FROM $table ORDER BY rowid').get()).map((r) => r.read<String?>('user_id')).toList();

void main() {
  test('re-keys every user_id table, only the matching rows', () async {
    final db = await _seed();
    await rekeyOwner(db, from: 'off', to: 'srv', dropOutbox: false);
    expect(await _owners(db, 'health_profile'), ['srv', 'other']);
    expect(await _owners(db, 'prescription'), ['srv']);
    expect(await _owners(db, 'sync_outbox'), ['srv', 'other']);
  });

  test('merge drops the retired account\'s outbox rows', () async {
    final db = await _seed();
    await rekeyOwner(db, from: 'off', to: 'srv', dropOutbox: true);
    expect(await _owners(db, 'sync_outbox'), ['other']);
    expect(await _owners(db, 'prescription'), ['srv']);
  });

  test('all-or-nothing: a failure rolls every table back', () async {
    final db = await _seed();
    await db.customStatement(
        "CREATE TRIGGER boom BEFORE UPDATE ON prescription BEGIN SELECT RAISE(ABORT, 'boom'); END");
    await expectLater(rekeyOwner(db, from: 'off', to: 'srv', dropOutbox: false), throwsA(anything));
    expect(await _owners(db, 'health_profile'), ['off', 'other']);
  });

  test('same id is a no-op', () async {
    final db = await _seed();
    expect(await rekeyOwner(db, from: 'off', to: 'off', dropOutbox: true), 0);
    expect(await _owners(db, 'sync_outbox'), ['off', 'other']);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd packages/core && fvm flutter test test/db/owner_rekey_test.dart`
Expected: FAIL — `rekeyOwner` undefined.

- [ ] **Step 3: Implement** — `packages/core/lib/src/db/owner_rekey.dart`:

```dart
import 'package:drift/drift.dart';

/// Moves every locally-owned row from account [from] to account [to].
///
/// Discovers tables by column rather than a hard-coded list, so a module that
/// adds a `user_id` table later is covered without touching this. One
/// transaction: a crash leaves either every row on [from] or every row on [to].
Future<int> rekeyOwner(
  GeneratedDatabase db, {
  required String from,
  required String to,
  required bool dropOutbox,
}) async {
  if (from == to) return 0;
  return db.transaction(() async {
    final tables = await db
        .customSelect(
          "SELECT m.name AS t FROM sqlite_master m "
          "WHERE m.type = 'table' AND m.name NOT LIKE 'sqlite_%' "
          "AND EXISTS (SELECT 1 FROM pragma_table_info(m.name) c WHERE c.name = 'user_id')",
        )
        .get();
    var changed = 0;
    for (final row in tables) {
      final t = row.read<String>('t');
      if (dropOutbox && t == 'sync_outbox') {
        changed += await db.customUpdate('DELETE FROM "$t" WHERE user_id = ?',
            variables: [Variable.withString(from)], updateKind: UpdateKind.delete);
      } else {
        changed += await db.customUpdate('UPDATE "$t" SET user_id = ? WHERE user_id = ?',
            variables: [Variable.withString(to), Variable.withString(from)], updateKind: UpdateKind.update);
      }
    }
    return changed;
  });
}
```

Export: `export 'src/db/owner_rekey.dart';` in `packages/core/lib/core.dart`.

- [ ] **Step 4: Run tests**

Run: `cd packages/core && fvm flutter test test/db/owner_rekey_test.dart && fvm flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/core
git commit -m "feat(core): transactional re-key of locally owned rows

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Disclosure — resend a locally stored acceptance

**Files:**
- Modify: `modules/disclosure/lib/src/application/use_cases/accept_disclosure_use_case.dart`
- Test: `modules/disclosure/test/…/accept_disclosure_use_case_test.dart` (existing file for this use case; create it under `test/application/` if absent)

**Interfaces:**
- Produces: `AcceptDisclosureUseCase.resync({required DisclosureId disclosureId, required String version}) → Future<bool>` — re-sends the stored acceptance to the API; `true` on success, `false` if none stored or the call failed. Never throws.

- [ ] **Step 1: Write failing tests** (mock `DisclosureDao` and `DisclosureApi` with mocktail, as the existing tests for this use case do):

```dart
  group('resync', () {
    test('sends the stored acceptance', () async {
      when(() => dao.watchAcceptance(any(), any())).thenAnswer((_) => Stream.value(DisclosureAcceptance(
            disclosureId: const DisclosureId.value('consolidated'),
            version: 'v1',
            countryCodeAtAccept: 'EG',
            supervisoryAuthorityNameAtAccept: 'PDPC',
            preferredLanguageAtAccept: 'ar',
            acceptedAt: DateTime.utc(2026, 10, 1),
          )));
      when(() => api.accept(any())).thenAnswer((_) async {});
      expect(await usecase.resync(disclosureId: const DisclosureId.value('consolidated'), version: 'v1'), isTrue);
      final sent = verify(() => api.accept(captureAny())).captured.single as AcceptDisclosureRequest;
      expect(sent.countryCode, 'EG');
    });

    test('nothing stored → false, no call', () async {
      when(() => dao.watchAcceptance(any(), any())).thenAnswer((_) => Stream.value(null));
      expect(await usecase.resync(disclosureId: const DisclosureId.value('consolidated'), version: 'v1'), isFalse);
      verifyNever(() => api.accept(any()));
    });

    test('API failure → false, no throw', () async {
      when(() => dao.watchAcceptance(any(), any())).thenAnswer((_) => Stream.value(DisclosureAcceptance(
            disclosureId: const DisclosureId.value('consolidated'),
            version: 'v1',
            countryCodeAtAccept: 'EG',
            supervisoryAuthorityNameAtAccept: 'PDPC',
            preferredLanguageAtAccept: 'ar',
            acceptedAt: DateTime.utc(2026, 10, 1),
          )));
      when(() => api.accept(any())).thenThrow(Exception('offline'));
      expect(await usecase.resync(disclosureId: const DisclosureId.value('consolidated'), version: 'v1'), isFalse);
    });
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd modules/disclosure && fvm flutter test`
Expected: FAIL — `resync` undefined.

- [ ] **Step 3: Implement** — add to `AcceptDisclosureUseCase`:

```dart
  /// Re-sends an acceptance recorded while the account had no server session
  /// (device-only). Best-effort, like step 2 of [execute].
  Future<bool> resync({required DisclosureId disclosureId, required String version}) async {
    final a = await _dao.watchAcceptance(disclosureId, version).first;
    if (a == null) return false;
    try {
      await _api.accept(AcceptDisclosureRequest(
        disclosureId: a.disclosureId.value,
        version: a.version,
        countryCode: a.countryCodeAtAccept,
        supervisoryAuthority: a.supervisoryAuthorityNameAtAccept,
        preferredLanguage: a.preferredLanguageAtAccept,
      ));
      return true;
    } catch (_) {
      return false;
    }
  }
```

- [ ] **Step 4: Run tests**

Run: `cd modules/disclosure && fvm flutter test && fvm flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add modules/disclosure
git commit -m "feat(disclosure): resync a locally stored acceptance

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: App shell — boot, routes and state for device-only accounts

**Files:**
- Modify: `app/lib/balsm_app/routes.dart` (`AppRoutes`)
- Modify: `app/lib/balsm_app/app_state.dart:40-45,104-135`
- Modify: `app/lib/brands/balsm/main_balsm.dart:90-125`
- Test: `app/test/…/app_state_test.dart` (existing `PatientAppState.load` tests — find with `grep -rl "PatientAppState.load" app/test`)

**Interfaces:**
- Consumes: `AccountMode`, `kAccountModeKey` (Task 3); `OfflineAccountService.kPendingMerge` (Task 4).
- Produces:
  - `AppRoutes.unlock = 'unlock'`, `AppRoutes.mergeOrDiscard = 'merge'`.
  - `PatientAppState.accountMode` (`AccountMode`, default `online`) + `void setAccountMode(AccountMode)` (notifies).
  - `PatientAppState.load(prefs, {required bool hasSession, AccountMode accountMode = AccountMode.online, bool pendingMerge = false})`: device-only with a user id → route `unlock`; `pendingMerge` → route `mergeOrDiscard`; otherwise unchanged.

- [ ] **Step 1: Write failing tests** — add to the existing `PatientAppState.load` test file (reuse its prefs fake):

```dart
  test('device-only account boots to unlock, even with no refresh token', () async {
    final s = await PatientAppState.load(prefsSignedIn, hasSession: true, accountMode: AccountMode.deviceOnly);
    expect(s.route, AppRoutes.unlock);
    expect(s.accountMode, AccountMode.deviceOnly);
  });

  test('unresolved merge resumes on the merge-or-discard screen', () async {
    final s = await PatientAppState.load(prefsSignedIn, hasSession: true, pendingMerge: true);
    expect(s.route, AppRoutes.mergeOrDiscard);
  });

  test('online behaviour unchanged', () async {
    final s = await PatientAppState.load(prefsSignedIn, hasSession: true);
    expect(s.route, AppRoutes.app);
  });
```

(`prefsSignedIn` = the fake the file already uses for a signed-in prefs group.)

- [ ] **Step 2: Run to verify they fail**

Run: `cd app && fvm flutter test <that file>`
Expected: FAIL — `AppRoutes.unlock` / `accountMode` undefined.

- [ ] **Step 3: Implement**

`routes.dart` inside `AppRoutes`:

```dart
  /// Device-only account cold start: password unlock before the shell.
  static const unlock = 'unlock';

  /// Going online found an existing account: merge this device's data or discard it.
  static const mergeOrDiscard = 'merge';
```

`app_state.dart`: add field and setter near `route`:

```dart
  /// Whether this account has server credentials (see core `AccountMode`).
  AccountMode accountMode = AccountMode.online;

  void setAccountMode(AccountMode m) {
    if (accountMode == m) return;
    accountMode = m;
    notifyListeners();
  }
```

and extend `load` with the two named parameters; at the start of the routing block (before the existing `if (await prefs.signedIn() && hasSession)`):

```dart
    s.accountMode = accountMode;
    if (hasSession && pendingMerge) {
      s.route = AppRoutes.mergeOrDiscard;
    } else if (hasSession && accountMode == AccountMode.deviceOnly) {
      s.route = AppRoutes.unlock;
    } else /* existing branches follow unchanged */
```

`main_balsm.dart` bootstrap — after reading `userId`, read the mode and let device-only accounts through without a refresh token:

```dart
  final accountMode = AccountMode.fromWire(await secureStorage.read(key: kAccountModeKey));
  final pendingMerge = await secureStorage.read(key: 'balsm.pending_merge') == 'true';
  final refreshToken = await secureStorage.read(key: 'balsm.refresh_token');
  final hasId = userId != null && userId.isNotEmpty;
  // A device-only account has an id and no tokens by design — that is not the
  // interrupted-sign-out remnant this guard exists for.
  final revivable = hasId &&
      (accountMode == AccountMode.deviceOnly || (refreshToken != null && refreshToken.isNotEmpty));
```

Pass `accountMode: accountMode, pendingMerge: pendingMerge` into the existing `PatientAppState.load(...)` call.

- [ ] **Step 4: Run tests**

Run: `cd app && fvm flutter test && fvm flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app
git commit -m "feat(app): boot device-only accounts to unlock; keep their id

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: App UI — "Device only" tab on the sign-in screen

**Files:**
- Modify: `app/lib/balsm_app/screens/auth_flow.dart` (`_PhoneScreen`, lines ~465-735)
- Modify: `app/lib/balsm_app/i18n/strings.i69n.jsonc`, `strings_ar.i69n.jsonc` (`auth` section), then regenerate
- Test: `app/test/…/auth_flow_test.dart` (existing widget tests for `_PhoneScreen`; find with `grep -rl "_PhoneScreen\|AppRoutes.phone" app/test`)

**Interfaces:**
- Consumes: `offlineAccountServiceProvider` (Task 4), `PatientAppState.setAccountMode` (Task 8), existing `_Segmented<V>` widget in the same file, existing `enterAfterSignIn(context, ref, s)`.
- Produces: `enum _AuthMode { online, deviceOnly }` (file-private).

Design copy (from DesignSync `auth.jsx` `PhoneScreen`; 6→8 per D5). Add under `auth` in both bundles:

| key | en | ar |
|---|---|---|
| `mode_online` | Online | متصل |
| `mode_device` | Device only | على الجهاز فقط |
| `device_title` | Account on this device | حساب على هذا الجهاز |
| `device_help` | No internet or verification code needed. Your data stays on this device only — when you go online later, we'll send a code to your email to verify and sync. | بدون إنترنت وبدون رمز تحقق. تبقى بياناتك على هذا الجهاز فقط، وعند الاتصال بالإنترنت لاحقًا نرسل رمزًا إلى بريدك للتحقق والمزامنة. |
| `device_pw_label` | Password to lock the app | كلمة مرور لقفل التطبيق |
| `pw_min_hint` | At least 8 characters | 8 أحرف على الأقل |
| `device_warning` | Your email isn't verified yet, so your password can't be recovered until you go online. If you lose this device before then, your data goes with it. | بريدك غير مُتحقَّق منه بعد، لذا لا يمكن استعادة كلمة المرور حتى تتصل بالإنترنت. إن فقدت جهازك قبل ذلك، تُفقد بياناتك. |
| `device_create` | Create account on device | إنشاء الحساب على الجهاز |

Layout (design): segmented control first, 14 px below the app bar, two equal segments with icons `cloud` / `smartphone` (Lucide), 40 px tall; then title, help, email field, password field; in device mode the password label changes, the "Forgot password?" link is hidden, and an info card (icon `info` 16 px, `--balsm-cream-50` background, 12 px padding) with `device_warning` appears under the password field; primary button label becomes `device_create`.

- [ ] **Step 1: Write failing widget tests** (use the file's existing pump helper for `_PhoneScreen`, and override `offlineAccountServiceProvider` with a mocktail mock):

```dart
  testWidgets('Device only: hides forgot-password, shows warning, enforces 8 chars', (t) async {
    await pumpPhoneScreen(t);
    await t.tap(find.text('Device only'));
    await t.pumpAndSettle();
    expect(find.text('Forgot password?'), findsNothing);
    expect(find.textContaining("can't be recovered"), findsOneWidget);

    await t.enterText(find.byType(TextField).at(0), 'layla@example.com');
    await t.enterText(find.byType(TextField).at(1), '1234567');
    await t.pump();
    expect(t.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Create account on device')).onPressed, isNull);
  });

  testWidgets('Device only: creates the account locally and never calls the API', (t) async {
    when(() => offline.create(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => 'off-1');
    await pumpPhoneScreen(t);
    await t.tap(find.text('Device only'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).at(0), 'layla@example.com');
    await t.enterText(find.byType(TextField).at(1), 'correct-horse');
    await t.tap(find.text('Create account on device'));
    await t.pumpAndSettle();

    verify(() => offline.create(email: 'layla@example.com', password: 'correct-horse')).called(1);
    verifyNever(() => signIn.requestContinueOtp(any(), any()));
    expect(appState.accountMode, AccountMode.deviceOnly);
  });
```

Use whatever button type and pump helper the existing tests use — match them, don't introduce new ones.

- [ ] **Step 2: Run to verify they fail**

Run: `cd app && fvm flutter test <that file>`
Expected: FAIL — no "Device only" text.

- [ ] **Step 3: Implement**

Add the i18n keys above to both jsonc files, then `cd app && fvm dart run build_runner build --delete-conflicting-outputs`.

In `_PhoneScreenState` add `_AuthMode _mode = _AuthMode.online;`. At the top of the scroll body insert:

```dart
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _Segmented<_AuthMode>(
                leftValue: _AuthMode.online,
                rightValue: _AuthMode.deviceOnly,
                value: _mode,
                leftLabel: s.strings.auth.mode_online,
                rightLabel: s.strings.auth.mode_device,
                leftIcon: LucideIcons.cloud,
                rightIcon: LucideIcons.smartphone,
                onChanged: (m) => setState(() => _mode = m),
              ),
            ),
```

(Match `_Segmented`'s real parameter names — read its constructor at ~line 1586; if it has no icon parameters, add optional `leftIcon`/`rightIcon` there, rendered 16 px before the label with 7 px gap, per design.)

Switch title/help/password label/forgot link/button label on `_mode == _AuthMode.deviceOnly` using the new strings, show the warning card under the password field in device mode, and gate the button with `password.length >= OfflineAccountService.minPasswordLength` (8) in **both** modes (D5 — also update the online hint text to `pw_min_hint`).

Device-mode submit:

```dart
  Future<void> _createOnDevice(PatientAppState s) async {
    setState(() => _busy = true);
    try {
      await ref.read(offlineAccountServiceProvider).create(email: _email.text, password: _password.text);
      if (!mounted) return;
      s.setAccountMode(AccountMode.deviceOnly);
      TextInput.finishAutofillContext();
      await enterAfterSignIn(context, ref, s); // disclosure gate: stored locally, API call is refused locally (Task 3)
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
```

(Use the state's existing controller and busy-flag names.)

- [ ] **Step 4: Run tests**

Run: `cd app && fvm flutter test && fvm flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app
git commit -m "feat(app): create a device-only account from the sign-in screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: App UI — unlock screen (provisional design)

No unlock screen exists in `Balsm App.html`. Build it from the sign-in screen's own pieces so it looks native; ask for a DesignSync design before release (tracked in the handoff, not a blocker to build).

**Files:**
- Modify: `app/lib/balsm_app/screens/auth_flow.dart` (new `_UnlockScreen`; add `AppRoutes.unlock => const _UnlockScreen()` to `AuthRouter`)
- Modify: i18n `auth` section (both bundles)
- Test: same widget test file as Task 9

**Interfaces:**
- Consumes: `offlineAccountServiceProvider` → `unlock`, `lockout`; `UnlockResult` types (Task 4).

Strings:

| key | en | ar |
|---|---|---|
| `unlock_title` | Unlock Balsm | افتح بلسم |
| `unlock_help` | Enter the password you set on this device. | أدخل كلمة المرور التي عيّنتها على هذا الجهاز. |
| `unlock_wrong` | Wrong password. | كلمة مرور غير صحيحة. |
| `unlock_locked` | Too many attempts. Try again in {secs}s. | محاولات كثيرة. أعد المحاولة بعد {secs} ث. |
| `unlock_btn` | Unlock | فتح |

Layout: same scaffold as `_PhoneScreen` (cream background, no back button, no step dots), title + help, one password field with the existing show/hide eye, `device_warning` info card below it, primary button `unlock_btn` in the footer. While locked, the button is disabled and `unlock_locked` counts down each second.

- [ ] **Step 1: Write failing widget tests**

```dart
  testWidgets('unlock: right password enters the app', (t) async {
    when(() => offline.lockout()).thenAnswer((_) async => null);
    when(() => offline.unlock('correct-horse')).thenAnswer((_) async => const Unlocked());
    await pumpAuthRouter(t, route: AppRoutes.unlock);
    await t.enterText(find.byType(TextField), 'correct-horse');
    await t.tap(find.text('Unlock'));
    await t.pumpAndSettle();
    expect(appState.route, AppRoutes.app);
  });

  testWidgets('unlock: lockout disables the button and counts down', (t) async {
    final until = DateTime.now().toUtc().add(const Duration(seconds: 30));
    when(() => offline.lockout()).thenAnswer((_) async => LockedUntil(until));
    await pumpAuthRouter(t, route: AppRoutes.unlock);
    await t.pump();
    expect(find.textContaining('Try again in'), findsOneWidget);
    // button disabled — assert with the same button finder as Task 9's tests
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd app && fvm flutter test <that file>`
Expected: FAIL.

- [ ] **Step 3: Implement** `_UnlockScreen` (`ConsumerStatefulWidget`): on `initState` call `lockout()` and start a 1 s `Timer.periodic` while locked; on submit call `unlock(pw)` → `Unlocked` → `AppScope.of(context).go(AppRoutes.app)`; `WrongPassword` → show `unlock_wrong`, clear field; `LockedUntil` → start countdown. Cancel the timer in `dispose`. Add i18n keys and regenerate.

- [ ] **Step 4: Run tests**

Run: `cd app && fvm flutter test && fvm flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app
git commit -m "feat(app): password unlock for device-only accounts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: App — go online (sheet, controller, entry points, server-feature gate)

**Files:**
- Create: `app/lib/balsm_app/auth/go_online_controller.dart`
- Create: `app/lib/balsm_app/screens/go_online_sheet.dart`
- Modify: `app/lib/balsm_app/screens/profile_screen.dart` (entry row when device-only)
- Modify: `app/lib/balsm_app/screens/storage_sheet.dart:287-330` (Balsm Cloud row in device-only)
- Modify: `app/lib/balsm_app/screens/care_team_screen.dart:33` (`openCareTeam`), `:150` (care import), `app/lib/balsm_app/screens/personal_details.dart:~1010` (QR share sheet opener)
- Modify: `app/lib/brands/balsm/main_balsm.dart` (retry pending `SetPassword` at launch)
- Modify: i18n (new `offline` section, both bundles)
- Test: `app/test/auth/go_online_controller_test.dart`, widget test for the sheet

**Interfaces:**
- Consumes: `SignInUseCase.requestContinueOtp(email, countryCode)`, `SignInUseCase.goOnline(...)`, `SignInUseCase.setPassword(password:)` (Task 5 / existing); `OfflineAccountService` (Task 4); `rekeyOwner` (Task 6); `AcceptDisclosureUseCase.resync` (Task 7); `appDatabaseProvider` (existing drift DB provider in core — use its real name); `eventBusProvider`; `UserSignedIn`.
- Produces:
  - `enum GoOnlineOutcome { online, needsMergeChoice }`.
  - `class GoOnlineController` with `Future<AppResult<void>> sendCode(String email)` and `Future<AppResult<GoOnlineOutcome>> verify({required String email, required String code})`; `Future<void> finishPasswordIfPending()`.
  - `final goOnlineControllerProvider`.
  - `Future<void> showGoOnlineSheet(BuildContext context)`.
  - `Future<bool> requireOnline(BuildContext context, WidgetRef ref)` — returns `true` if online; if device-only, opens the sheet and returns whether the user came back online.

`verify` sequence (exact):
1. `offline = await svc.pendingCredentials()`; `localId = balsm.user_id`.
2. `r = await signIn.goOnline(email, code, clientAccountId: localId)`.
3. `GoOnlineAdopted` → step 5.
4. `GoOnlineNewId(id)` → `await rekeyOwner(db, from: localId, to: id, dropOutbox: false)` → step 5.
5. `await svc.markOnline()`; publish `UserSignedIn(userId: UserId.value(finalId), email: email, provider: 'email')`; `await finishPasswordIfPending()`; `await disclosure.resync(...)` with the same id/version constants `enterAfterSignIn` uses; return `online`.
6. `GoOnlineExistingAccount(id)` → `await svc.setPendingMerge(true)`; store the target id in memory on the controller (`pendingTargetId`) and in secure storage `balsm.pending_merge_target`; return `needsMergeChoice`. Do **not** publish `UserSignedIn` and do **not** call `markOnline` yet (Task 12 finishes).

`finishPasswordIfPending`: if `pendingCredentials()` non-null → `setPassword(password:)`; on success `clearPlainPassword()`; on failure keep it (retried at next launch from `main_balsm.dart` when mode is `online` and `balsm.offline.pw_plain` exists).

Strings (`offline` section; from design `GoOnlineSheet`):

| key | en | ar |
|---|---|---|
| `go_title` | Go online | الاتصال بالإنترنت |
| `go_help` | We'll send a code to your email to verify it, then the data on this device starts syncing. | نرسل رمزًا إلى بريدك للتحقق منه، ثم تبدأ مزامنة بياناتك الموجودة على هذا الجهاز. |
| `go_send` | Send code | إرسال الرمز |
| `go_code_help` | Enter the 6-digit code we sent to | أدخل الرمز المكوّن من 6 أرقام الذي أرسلناه إلى |
| `go_verify` | Verify and go online | تحقق واتصل |
| `go_done_title` | You're online | أنت متصل الآن |
| `go_done_help` | Email verified. Your account is now on Balsm, and you can choose where each type of data is stored. | تم التحقق من بريدك. حسابك الآن على بلسم، ويمكنك اختيار مكان حفظ كل نوع من البيانات. |
| `go_done` | Done | تم |
| `go_row` | Go online | الاتصال بالإنترنت |
| `go_row_sub` | Verify your email to use Balsm Cloud and sharing | تحقّق من بريدك لاستخدام بلسم كلاود والمشاركة |
| `go_cloud_pill` | Go online | اتصل |

(`go_done_help` deliberately says "your account is now on Balsm" rather than the design's "your data is syncing": no cloud can receive data yet — D6 — so the design's line would be untrue. Flag this copy change to design.)

Sheet layout: reuse the existing sheet scaffold used by `_ForgotPasswordSheet` in `auth_flow.dart` (same title bar, OTP boxes `_OtpBox`, 28 s resend countdown, success mark), with steps `email → code → done`; email prefilled from `pendingCredentials().email`. Auto-submit on the 6th digit. On `needsMergeChoice`, close the sheet and `AppScope.of(context).go(AppRoutes.mergeOrDiscard)`.

- [ ] **Step 1: Write failing controller tests** — `app/test/auth/go_online_controller_test.dart` (mocktail mocks for `SignInUseCase`, `OfflineAccountService`, `AcceptDisclosureUseCase`; a memory `_Db` like Task 6's test with one `prescription(user_id)` table):

```dart
  test('adopted: no re-key, marks online, sets password, clears plaintext, publishes sign-in', () async {
    stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    when(() => signIn.goOnline(email: 'a@b.co', code: '123456', clientAccountId: 'off-1'))
        .thenAnswer((_) async => AppResult.success(const GoOnlineAdopted()));
    when(() => signIn.setPassword(password: 'correct-horse')).thenAnswer((_) async => AppResult.success(null));

    final r = await controller.verify(email: 'a@b.co', code: '123456');

    expect(r.valueOrNull, GoOnlineOutcome.online);
    verify(() => offline.markOnline()).called(1);
    verify(() => offline.clearPlainPassword()).called(1);
    expect(await owners(db), ['off-1']);
    expect(events.whereType<UserSignedIn>().single.userId.value, 'off-1');
  });

  test('new id: re-keys local rows before publishing sign-in', () async {
    stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    when(() => signIn.goOnline(email: any(named: 'email'), code: any(named: 'code'), clientAccountId: any(named: 'clientAccountId')))
        .thenAnswer((_) async => AppResult.success(const GoOnlineNewId('srv-9')));
    when(() => signIn.setPassword(password: any(named: 'password'))).thenAnswer((_) async => AppResult.success(null));

    await controller.verify(email: 'a@b.co', code: '123456');

    expect(await owners(db), ['srv-9']);
    expect(events.whereType<UserSignedIn>().single.userId.value, 'srv-9');
  });

  test('SetPassword failure keeps plaintext for retry; user is still online', () async {
    stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    when(() => signIn.goOnline(email: any(named: 'email'), code: any(named: 'code'), clientAccountId: any(named: 'clientAccountId')))
        .thenAnswer((_) async => AppResult.success(const GoOnlineAdopted()));
    when(() => signIn.setPassword(password: any(named: 'password')))
        .thenAnswer((_) async => AppResult.failure(const NetworkFailure()));

    final r = await controller.verify(email: 'a@b.co', code: '123456');

    expect(r.valueOrNull, GoOnlineOutcome.online);
    verifyNever(() => offline.clearPlainPassword());
  });

  test('existing account: sets pending merge, no re-key, no sign-in event', () async {
    stubCreds(email: 'a@b.co', password: 'correct-horse', localId: 'off-1');
    when(() => signIn.goOnline(email: any(named: 'email'), code: any(named: 'code'), clientAccountId: any(named: 'clientAccountId')))
        .thenAnswer((_) async => AppResult.success(const GoOnlineExistingAccount('srv-1')));

    final r = await controller.verify(email: 'a@b.co', code: '123456');

    expect(r.valueOrNull, GoOnlineOutcome.needsMergeChoice);
    verify(() => offline.setPendingMerge(true)).called(1);
    verifyNever(() => offline.markOnline());
    expect(await owners(db), ['off-1']);
    expect(events.whereType<UserSignedIn>(), isEmpty);
  });
```

Plus widget tests: the sheet walks email → code → done against a mocked controller; `requireOnline` returns `true` immediately when online and opens the sheet when device-only; storage sheet in device-only shows `go_cloud_pill` on the Balsm Cloud row while iCloud and Google Drive still show "Coming soon".

- [ ] **Step 2: Run to verify they fail**

Run: `cd app && fvm flutter test test/auth/go_online_controller_test.dart`
Expected: FAIL — controller undefined.

- [ ] **Step 3: Implement** the controller exactly per the sequence above, the sheet per the layout above, and wire entry points:
  - `profile_screen.dart`: when `AppScope.of(context).accountMode == AccountMode.deviceOnly`, show a row (same row widget as the neighbouring Storage row) with icon `cloud`, `go_row` / `go_row_sub`, tapping `showGoOnlineSheet`.
  - `storage_sheet.dart` `_CloudRow` (the widget at ~287): for `StorageTarget.balsmCloud` while device-only, render the pill `go_cloud_pill` at full opacity and make the row open `showGoOnlineSheet`. iCloud/Google Drive rows unchanged.
  - `openCareTeam`, the care-import opener, and the QR-share opener: first line `if (!await requireOnline(context, ref)) return;` (convert the opener to take a `WidgetRef` where needed).
  - `main_balsm.dart`: after container init, if mode is `online`, `unawaited(container.read(goOnlineControllerProvider).finishPasswordIfPending())`.
  - Add the `offline` i18n section and regenerate.

- [ ] **Step 4: Run tests**

Run: `cd app && fvm flutter test && fvm flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app
git commit -m "feat(app): go online from a device-only account

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: App — merge-or-discard screen ⛔ blocked on design

**Do not start the UI until the screen exists in DesignSync `Balsm App.html`** (spec §3). The controller part can be built first; the user-facing feature cannot release until this task is done.

**Files:**
- Modify: `app/lib/balsm_app/auth/go_online_controller.dart` (add `merge()` / `discard()`)
- Modify: `app/lib/balsm_app/screens/auth_flow.dart` (new `_MergeOrDiscardScreen`; `AppRoutes.mergeOrDiscard =>` in `AuthRouter`)
- Modify: i18n (`offline` section — copy from the delivered design)
- Test: `app/test/auth/go_online_controller_test.dart`, widget test

**Interfaces:**
- Consumes: `balsm.pending_merge_target` (Task 11), `rekeyOwner` (Task 6), `OfflineAccountService.wipe/markOnline/clearPlainPassword/setPendingMerge`, `appDatabaseProvider`, vault directory helper used by `saveVaultBytes`.
- Produces: `Future<void> GoOnlineController.merge()`; `Future<void> GoOnlineController.discard()`.

`merge()`: `target = balsm.pending_merge_target` → `rekeyOwner(db, from: localId, to: target, dropOutbox: true)` → `balsm.user_id = target` → `clearPlainPassword()` (existing account keeps its own password, D2) → `markOnline()` → `setPendingMerge(false)`, delete `pending_merge_target` → publish `UserSignedIn(target)` → `disclosure.resync`.

`discard()`: delete every row where `user_id = localId` in every `user_id` table (reuse the discovery query from Task 6 — extract it to `Future<List<String>> ownedTables(GeneratedDatabase)` in `owner_rekey.dart` and use it from both) and delete the vault files those rows referenced → `balsm.user_id = target` → `clearPlainPassword()` → `markOnline()` → clear pending flags → publish `UserSignedIn(target)`.

- [ ] **Step 1: Write failing tests**

```dart
  test('merge: local rows move to the existing account, outbox dropped, offline password discarded', () async {
    await seedPendingMerge(localId: 'off-1', target: 'srv-1');
    await controller.merge();
    expect(await owners(db), ['srv-1']);
    expect(await outboxOwners(db), isEmpty);
    verify(() => offline.clearPlainPassword()).called(1);
    verify(() => offline.setPendingMerge(false)).called(1);
    verifyNever(() => signIn.setPassword(password: any(named: 'password')));
    expect(events.whereType<UserSignedIn>().single.userId.value, 'srv-1');
  });

  test('discard: local rows are gone, user signed in to existing account', () async {
    await seedPendingMerge(localId: 'off-1', target: 'srv-1');
    await controller.discard();
    expect(await owners(db), isEmpty);
    expect(events.whereType<UserSignedIn>().single.userId.value, 'srv-1');
  });
```

Widget test: Discard requires a second confirmation before `discard()` is called; killing and re-pumping `AuthRouter` with `pendingMerge: true` lands back on this screen (covered by Task 8's load test + a pump here).

- [ ] **Step 2: Run to verify they fail** — `cd app && fvm flutter test test/auth/go_online_controller_test.dart` → FAIL.
- [ ] **Step 3: Implement** controller methods as specified; build the screen from the delivered design.
- [ ] **Step 4: Run tests** — `cd app && fvm flutter test && fvm flutter analyze` → PASS.
- [ ] **Step 5: Commit**

```bash
git add app packages/core
git commit -m "feat(app): merge or discard device data when the email already has an account

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: End-to-end check

**Files:**
- Test: `app/integration_test/offline_account_test.dart` (use the e2e fake-API seam: `extraOverrides` in `main_balsm.dart`)

- [ ] **Step 1: Write the integration test**: boot with no session → Device only → create account → add a medication → relaunch → unlock → go online against a fake `AuthApi` whose verify returns `adopted_client_id: true` → the medication is still listed and `balsm.user_id` is unchanged. Second case: fake returns `is_new_user: false` → merge screen → Merge → medication still listed under the returned id.
- [ ] **Step 2: Run** — `cd app && fvm flutter test integration_test/offline_account_test.dart -d <simulator id>` → PASS.
- [ ] **Step 3: Manual** on a real iPhone and Android device: airplane mode → create → use → disable airplane mode → go online against staging (`api-stg-balsm-health.mosalam.com`). Record results in the PR.
- [ ] **Step 4: Commit**

```bash
git add app/integration_test
git commit -m "test(app): offline account end to end

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Outside this plan (owner: product/design)

- DesignSync `auth.jsx`: "At least 6 characters" → "At least 8 characters", `passwordOk` → `>= 8` (D5).
- Design the **unlock** screen (Task 10 ships a provisional one).
- Design the **merge-or-discard** screen (Task 12 is blocked on it).
- Confirm the `go_done_help` copy change (Task 11).
