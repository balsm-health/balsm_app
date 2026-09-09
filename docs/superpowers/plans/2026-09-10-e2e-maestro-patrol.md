# E2E Tests with Maestro and Patrol — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the patient app on-device end-to-end coverage of walkthrough → welcome → sign-in → disclosure gate → home shell, with no backend, driven by Patrol (behaviour) and Maestro (happy path + screenshots).

**Architecture:** Extract `main_balsm.dart`'s 171-line `main()` into `bootstrap({extraOverrides})`, which already builds a `ProviderContainer(overrides: [...])`. E2E binds the eight `Provider<XxxApi>` seams to in-memory fakes living in core's existing `test_kit` (gated by the `no_test_kit_in_release` lint). Patrol tests call `bootstrap` directly with per-test overrides; Maestro drives a `main_e2e.dart` build that has the fakes baked in.

**Tech Stack:** Flutter 3.41.9 (fvm-pinned), melos monorepo, Riverpod, `patrol` 4.9.0 + `patrol_cli`, Maestro (YAML), `integration_test`.

**Spec:** `docs/superpowers/specs/2026-09-10-e2e-maestro-patrol-design.md`

## Global Constraints

- Flutter runs via **fvm** — every command is `fvm flutter …` / `fvm dart …`.
- Formatter: `fvm dart format` with `page_width: 120` (set in `analysis_options.yaml`). A pre-commit hook blocks drift.
- **No PHI, real or fabricated.** The e2e fixture is: user id `00000000-0000-0000-0000-000000000001`, email `e2e@balsm.test`, country `EG`, language `en`, display name `E2E Tester`. No health data — the flows stop at the home shell.
- Test-support code lives under a path containing `test_kit`; the `no_test_kit_in_release` custom-lint rule blocks those imports when `FLAVOR != dev`.
- Modules depend only on `core` and `balsm_api`, never on each other (`balsm_boundary_lint`).
- Android has **no product flavors** — `patrol test` runs without `--flavor`.
- Android `applicationId` / iOS bundle id: `app.balsm.health`.
- Commit convention: `[Tag] Description` (`[Feature]`, `[Fix]`, `[Refactor]`, `[Docs]`, `[Test]`).

---

### Task 1: Extract `bootstrap()` from `main_balsm.dart`

Pure structural move — no behaviour change. It exists so both `main_balsm.dart` and the e2e entrypoint share one boot path.

**Files:**
- Modify: `app/lib/brands/balsm/main_balsm.dart:29-199`

**Interfaces:**
- Consumes: nothing.
- Produces: `Future<void> bootstrap({List<Override> extraOverrides = const []})` in `package:app/brands/balsm/main_balsm.dart`. Later tasks call it.

- [ ] **Step 1: Rename `main` and add the parameter**

In `app/lib/brands/balsm/main_balsm.dart`, change the function signature at line 29 from:

```dart
Future<void> main() async {
```

to:

```dart
/// Boots the app. [extraOverrides] is appended AFTER the production overrides,
/// so an entry for the same provider wins — that is the seam the e2e build and
/// the Patrol tests use to swap the API layer for fakes.
Future<void> bootstrap({List<Override> extraOverrides = const []}) async {
```

- [ ] **Step 2: Append the extra overrides to the container**

Find the `final container = ProviderContainer(overrides: [` list (starts line 61). It ends with `]);`. Change that closing to splat the parameter in last:

```dart
    ...extraOverrides,
  ]);
```

- [ ] **Step 3: Add the thin `main` back**

At the end of the file, add:

```dart
/// Production entrypoint. See [bootstrap].
Future<void> main() => bootstrap();
```

- [ ] **Step 4: Verify it still analyzes and the suites pass**

Run:
```bash
cd /Volumes/Dev/Balsm/balsm_app
fvm dart analyze app packages modules
fvm dart format --set-exit-if-changed app/lib/brands/balsm/main_balsm.dart
cd app && fvm flutter test
```
Expected: analyze reports only the pre-existing `app_database.g.dart` `unused_field` warning; formatter clean; all app tests pass.

- [ ] **Step 5: Verify the real app still boots**

Run:
```bash
cd /Volumes/Dev/Balsm/balsm_app
fvm dart run tool/build.dart run balsm dev
```
Expected: the app launches to the walkthrough or welcome screen exactly as before. This is the only check that catches a bad move — the unit suites never call `main()`. Stop it once you see the first screen.

- [ ] **Step 6: Commit**

```bash
git add app/lib/brands/balsm/main_balsm.dart
git commit -m "[Refactor] Extract bootstrap() from main_balsm so e2e can override providers"
```

---

### Task 2: Fake API layer in core's test_kit

**Files:**
- Create: `packages/core/lib/src/test_kit/fake_apis.dart`
- Modify: `packages/core/lib/core.dart:109` (add the export next to the existing test_kit exports)
- Test: `packages/core/test/test_kit/fake_apis_test.dart`

**Interfaces:**
- Consumes: `bootstrap` is not used here.
- Produces:
  - `class E2eFixture` with `static const userId = '00000000-0000-0000-0000-000000000001'`, `email`, `countryCode`, `language`, `displayName`.
  - `class FakeAuthApi implements AuthApi` with mutable fields `bool lockedOut`, `bool failNextSignIn`, `bool nextIsNewUser`.
  - `FakeAccountApi`, `FakeSessionsApi`, `FakeEmergencyQrApi`, `FakeDeletionApi`, `FakeDisclosureApi`, `FakeGeofenceApi`, `FakeCareDirectoryApi`.
  - `List<Override> e2eApiOverrides({FakeAuthApi? auth, FakeAccountApi? account})` — binds all eight `Provider<XxxApi>`, defaulting to fresh fakes.

- [ ] **Step 1: Write the failing test**

Create `packages/core/test/test_kit/fake_apis_test.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeAuthApi', () {
    test('password sign-in returns the fixture session', () async {
      final api = FakeAuthApi();

      final r = await api.passwordSignIn(
        const PasswordSignInRequest(email: 'a@b.c', password: 'pw', deviceId: 'd', deviceLabel: 'l'),
      );

      expect(r.userId, E2eFixture.userId);
      expect(r.isNewUser, isFalse);
    });

    test('nextIsNewUser drives the new-account branch', () async {
      final api = FakeAuthApi()..nextIsNewUser = true;

      final r = await api.passwordSignIn(
        const PasswordSignInRequest(email: 'a@b.c', password: 'pw', deviceId: 'd', deviceLabel: 'l'),
      );

      expect(r.isNewUser, isTrue);
    });

    test('lockedOut throws account_locked with a Retry-After', () async {
      final api = FakeAuthApi()..lockedOut = true;

      expect(
        () => api.passwordSignIn(
          const PasswordSignInRequest(email: 'a@b.c', password: 'pw', deviceId: 'd', deviceLabel: 'l'),
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'account_locked')
            .having((e) => e.retryAfterSeconds, 'retryAfterSeconds', 90)),
      );
    });

    test('failNextSignIn throws a generic unauthorized once', () async {
      final api = FakeAuthApi()..failNextSignIn = true;

      await expectLater(
        () => api.passwordSignIn(
          const PasswordSignInRequest(email: 'a@b.c', password: 'pw', deviceId: 'd', deviceLabel: 'l'),
        ),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'unauthorized')),
      );
      // One-shot: the retry succeeds, so a test can assert recovery.
      final r = await api.passwordSignIn(
        const PasswordSignInRequest(email: 'a@b.c', password: 'pw', deviceId: 'd', deviceLabel: 'l'),
      );
      expect(r.userId, E2eFixture.userId);
    });
  });

  test('FakeAccountApi.getSelf returns the fixture with no health data', () async {
    final self = await FakeAccountApi().getSelf();

    expect(self!.id, E2eFixture.userId);
    expect(self.countryCode, E2eFixture.countryCode);
    expect(self.dateOfBirth, isNull, reason: 'the e2e fixture carries no PHI');
    expect(self.nationalId, isNull);
  });

  test('e2eApiOverrides binds every Provider<XxxApi> to a fake', () {
    final container = ProviderContainer(overrides: e2eApiOverrides());
    addTearDown(container.dispose);

    expect(container.read(authApiProvider), isA<FakeAuthApi>());
    expect(container.read(accountApiProvider), isA<FakeAccountApi>());
    expect(container.read(sessionsApiProvider), isA<FakeSessionsApi>());
    expect(container.read(emergencyQrApiProvider), isA<FakeEmergencyQrApi>());
    expect(container.read(deletionApiProvider), isA<FakeDeletionApi>());
    expect(container.read(disclosureApiProvider), isA<FakeDisclosureApi>());
    expect(container.read(geofenceApiProvider), isA<FakeGeofenceApi>());
    expect(container.read(careDirectoryApiProvider), isA<FakeCareDirectoryApi>());
  });

  test('e2eApiOverrides accepts a pre-configured fake so a test can force state', () {
    final auth = FakeAuthApi()..lockedOut = true;
    final container = ProviderContainer(overrides: e2eApiOverrides(auth: auth));
    addTearDown(container.dispose);

    expect(identical(container.read(authApiProvider), auth), isTrue);
  });
}
```

- [ ] **Step 2: Run it to confirm it fails**

Run:
```bash
cd /Volumes/Dev/Balsm/balsm_app/packages/core
fvm flutter test test/test_kit/fake_apis_test.dart
```
Expected: FAIL to compile — `Undefined name 'FakeAuthApi'`, `E2eFixture`, `e2eApiOverrides`.

- [ ] **Step 3: Write `fake_apis.dart`**

Create `packages/core/lib/src/test_kit/fake_apis.dart`:

```dart
import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_providers.dart';

/// The single synthetic identity every e2e run uses. Deterministic so
/// assertions can name it. Carries NO health data — the flows under test stop
/// at the home shell, and inventing plausible PHI is what AGENTS.md forbids.
class E2eFixture {
  const E2eFixture._();

  static const userId = '00000000-0000-0000-0000-000000000001';
  static const email = 'e2e@balsm.test';
  static const countryCode = 'EG';
  static const language = 'en';
  static const displayName = 'E2E Tester';
  static const handle = 'e2e_tester';
  static const accessToken = 'e2e-access-token';
  static const refreshToken = 'e2e-refresh-token';
}

/// In-memory [AuthApi]. The public fields are the knobs a test flips to drive a
/// branch — there is no server to make one happen.
class FakeAuthApi implements AuthApi {
  /// Every sign-in throws `account_locked` with a 90s Retry-After.
  bool lockedOut = false;

  /// The next sign-in throws a generic `unauthorized`, then clears itself, so a
  /// test can assert the error shows AND that a retry recovers.
  bool failNextSignIn = false;

  /// Session returned by the next sign-in reports a brand-new account, which
  /// routes the UI to profile setup.
  bool nextIsNewUser = false;

  AuthTokensResponse _session() {
    if (lockedOut) {
      throw const ApiException(code: 'account_locked', statusCode: 423, retryAfterSeconds: 90);
    }
    if (failNextSignIn) {
      failNextSignIn = false;
      throw const ApiException(code: 'unauthorized', statusCode: 401);
    }
    return AuthTokensResponse(
      accessToken: E2eFixture.accessToken,
      refreshToken: E2eFixture.refreshToken,
      userId: E2eFixture.userId,
      isNewUser: nextIsNewUser,
    );
  }

  @override
  Future<void> requestOtp(RequestOtpRequest request, {CancelToken? cancelToken}) async {}

  @override
  Future<AuthTokensResponse> verifyOtp(VerifyOtpRequest request, {CancelToken? cancelToken}) async => _session();

  @override
  Future<AuthTokensResponse> verifyLink(VerifyLinkRequest request, {CancelToken? cancelToken}) async => _session();

  @override
  Future<AuthTokensResponse> signInWithGoogle(GoogleSignInRequest request, {CancelToken? cancelToken}) async =>
      _session();

  @override
  Future<AuthTokensResponse> signInWithApple(AppleSignInRequest request, {CancelToken? cancelToken}) async =>
      _session();

  @override
  Future<void> signOut({CancelToken? cancelToken}) async {}

  @override
  Future<RefreshedTokensResponse> refresh(RefreshTokenRequest request, {CancelToken? cancelToken}) async =>
      const RefreshedTokensResponse(accessToken: E2eFixture.accessToken, refreshToken: E2eFixture.refreshToken);

  @override
  Future<RefreshedTokensResponse> recoveryClaim(RecoveryClaimRequest request, {CancelToken? cancelToken}) async =>
      const RefreshedTokensResponse(accessToken: E2eFixture.accessToken, refreshToken: E2eFixture.refreshToken);

  @override
  Future<AuthTokensResponse> passwordSignIn(PasswordSignInRequest request, {CancelToken? cancelToken}) async =>
      _session();

  @override
  Future<void> setPassword(SetPasswordRequest request, {CancelToken? cancelToken}) async {}

  @override
  Future<void> resetPassword(ResetPasswordRequest request, {CancelToken? cancelToken}) async {}
}

/// In-memory [AccountApi] over a single mutable fixture account.
class FakeAccountApi implements AccountApi {
  /// Handles this fake reports as taken; everything else is available.
  final taken = <String>{'balsm', 'admin'};

  String? _handle = E2eFixture.handle;
  String? _displayName = E2eFixture.displayName;
  String _language = E2eFixture.language;
  String _countryCode = E2eFixture.countryCode;

  @override
  Future<AccountSelfResponse?> getSelf({CancelToken? cancelToken}) async => AccountSelfResponse(
        id: E2eFixture.userId,
        handle: _handle,
        displayName: _displayName,
        countryCode: _countryCode,
        preferredLanguage: _language,
      );

  @override
  Future<ClaimHandleResponse> claimHandle(ClaimHandleRequest request, {CancelToken? cancelToken}) async {
    _handle = request.handle;
    return ClaimHandleResponse(handle: _handle);
  }

  @override
  Future<void> updateProfile(UpdateProfileRequest request, {CancelToken? cancelToken}) async {
    _displayName = request.displayName ?? _displayName;
  }

  @override
  Future<void> changeLanguage(ChangeLanguageRequest request, {CancelToken? cancelToken}) async {
    _language = request.language;
  }

  @override
  Future<void> changeCountry(ChangeCountryRequest request, {CancelToken? cancelToken}) async {
    _countryCode = request.countryCode;
  }

  @override
  Future<HandleAvailabilityResponse> checkHandleAvailability(String handle, {CancelToken? cancelToken}) async =>
      HandleAvailabilityResponse(available: !taken.contains(handle.toLowerCase()));
}

class FakeSessionsApi implements SessionsApi {
  @override
  Future<List<SessionResponse>> listSessions({CancelToken? cancelToken}) async => const [];

  @override
  Future<void> revokeSession(String sessionId, {CancelToken? cancelToken}) async {}

  @override
  Future<RevokeAllSessionsResponse> revokeAllSessions({CancelToken? cancelToken}) async =>
      const RevokeAllSessionsResponse(revokedCount: 0);
}

class FakeEmergencyQrApi implements EmergencyQrApi {
  @override
  Future<MintQrResponse> mint(MintQrRequest request, {CancelToken? cancelToken}) async =>
      throw const ApiException(code: 'not_implemented', statusCode: 501);

  @override
  Future<ResolveQrResponse> resolve(String tokenId, {CancelToken? cancelToken}) async =>
      throw const ApiException(code: 'not_found', statusCode: 404);

  @override
  Future<void> revoke(RevokeQrRequest request, {CancelToken? cancelToken}) async {}
}

class FakeDeletionApi implements DeletionApi {
  @override
  Future<DeletionIntakeResponse> requestIntake({CancelToken? cancelToken}) async =>
      throw const ApiException(code: 'not_implemented', statusCode: 501);

  @override
  Future<DeletionCancelResponse> cancel({CancelToken? cancelToken}) async =>
      throw const ApiException(code: 'not_implemented', statusCode: 501);
}

class FakeDisclosureApi implements DisclosureApi {
  final accepted = <String>[];

  @override
  Future<void> accept(AcceptDisclosureRequest request, {CancelToken? cancelToken}) async {
    accepted.add(request.disclosureId);
  }
}

class FakeGeofenceApi implements GeofenceApi {
  /// Empty by default: the fixture country must not be blocked.
  List<String> deniedCodes = const [];

  @override
  Future<DeniedCountriesResponse> getDeniedCountries({CancelToken? cancelToken}) async =>
      DeniedCountriesResponse(deniedCodes: deniedCodes);
}

class FakeCareDirectoryApi implements CareDirectoryApi {
  @override
  Future<List<CareEntityResponse>> nearby(NearbyCareQuery query, {CancelToken? cancelToken}) async => const [];
}

/// Binds every `Provider<XxxApi>` to a fake. Pass a pre-configured fake to
/// force a branch; omit it for a fresh default.
///
/// This is the canonical list — the e2e entrypoint and the Patrol tests both
/// use it so they cannot drift apart.
List<Override> e2eApiOverrides({
  FakeAuthApi? auth,
  FakeAccountApi? account,
  FakeSessionsApi? sessions,
  FakeEmergencyQrApi? emergencyQr,
  FakeDeletionApi? deletion,
  FakeDisclosureApi? disclosure,
  FakeGeofenceApi? geofence,
  FakeCareDirectoryApi? careDirectory,
}) =>
    [
      authApiProvider.overrideWithValue(auth ?? FakeAuthApi()),
      accountApiProvider.overrideWithValue(account ?? FakeAccountApi()),
      sessionsApiProvider.overrideWithValue(sessions ?? FakeSessionsApi()),
      emergencyQrApiProvider.overrideWithValue(emergencyQr ?? FakeEmergencyQrApi()),
      deletionApiProvider.overrideWithValue(deletion ?? FakeDeletionApi()),
      disclosureApiProvider.overrideWithValue(disclosure ?? FakeDisclosureApi()),
      geofenceApiProvider.overrideWithValue(geofence ?? FakeGeofenceApi()),
      careDirectoryApiProvider.overrideWithValue(careDirectory ?? FakeCareDirectoryApi()),
    ];
```

- [ ] **Step 4: Export it from core**

In `packages/core/lib/core.dart`, directly after line 109 (`export 'src/test_kit/golden_helpers.dart';`) add:

```dart
export 'src/test_kit/fake_apis.dart';
```

- [ ] **Step 5: Reconcile the DTO constructors against reality**

The response and request DTO constructor names above were read from
`packages/balsm_api/lib/src/*/responses.dart` and `requests.dart`, but three are
used here for the first time. Confirm each compiles and fix the call site (not
the DTO) if a named parameter differs:

```bash
cd /Volumes/Dev/Balsm/balsm_app
grep -n "class RevokeAllSessionsResponse" -A6 packages/balsm_api/lib/src/sessions/responses.dart
grep -n "class UpdateProfileRequest\|class ChangeLanguageRequest\|class ChangeCountryRequest\|class ClaimHandleRequest" -A8 packages/balsm_api/lib/src/account/requests.dart
grep -n "class AcceptDisclosureRequest" -A6 packages/balsm_api/lib/src/disclosure/requests.dart
grep -n "class PasswordSignInRequest" -A8 packages/balsm_api/lib/src/auth/requests.dart
```

- [ ] **Step 6: Run the test to verify it passes**

Run:
```bash
cd /Volumes/Dev/Balsm/balsm_app/packages/core
fvm flutter test test/test_kit/fake_apis_test.dart
```
Expected: PASS, 7 tests.

- [ ] **Step 7: Verify the lint gate still holds and nothing else broke**

Run:
```bash
cd /Volumes/Dev/Balsm/balsm_app
fvm dart analyze packages/core
fvm dart format --set-exit-if-changed packages/core/lib/src/test_kit/fake_apis.dart packages/core/test/test_kit/fake_apis_test.dart
cd packages/core && fvm flutter test test/config test/network test/localization
```
Expected: analyze clean apart from the pre-existing `app_database.g.dart` warning; formatter clean; tests pass.

- [ ] **Step 8: Commit**

```bash
git add packages/core/lib/src/test_kit/fake_apis.dart packages/core/lib/core.dart packages/core/test/test_kit/fake_apis_test.dart
git commit -m "[Test] Add in-memory fakes for the eight API seams

Deterministic fixture account with no health data, plus knobs for the
states an e2e test needs to force: lockout, a one-shot sign-in failure,
and a new-vs-returning account. e2eApiOverrides is the canonical binding
so the e2e entrypoint and the Patrol tests cannot drift apart."
```

---

### Task 3: `main_e2e.dart` — the build Maestro drives

**Files:**
- Create: `app/lib/brands/balsm/main_e2e.dart`

**Interfaces:**
- Consumes: `bootstrap({extraOverrides})` (Task 1), `e2eApiOverrides()` (Task 2).
- Produces: an entrypoint at `lib/brands/balsm/main_e2e.dart` that Maestro-targeted builds use via `-t`.

- [ ] **Step 1: Write the entrypoint**

Create `app/lib/brands/balsm/main_e2e.dart`:

```dart
import 'package:core/core.dart' show e2eApiOverrides;

import 'main_balsm.dart';

/// E2E entrypoint: the real app boot with the API layer swapped for in-memory
/// fakes, so the whole first-run path runs with no backend.
///
/// Maestro is black-box and cannot inject anything, so it needs a binary that
/// is already stubbed — this one. Patrol does NOT use this entrypoint; its
/// tests call [bootstrap] directly, which is what lets a single test force one
/// specific failure.
///
/// Build:
///   fvm flutter build apk --debug \
///     -t lib/brands/balsm/main_e2e.dart \
///     --dart-define-from-file=env/balsm/dev.json \
///     --dart-define-from-file=env/shared.json
Future<void> main() => bootstrap(extraOverrides: e2eApiOverrides());
```

- [ ] **Step 2: Verify it compiles into a real build**

Run:
```bash
cd /Volumes/Dev/Balsm/balsm_app/app
fvm flutter build apk --debug \
  -t lib/brands/balsm/main_e2e.dart \
  --dart-define-from-file=env/balsm/dev.json \
  --dart-define-from-file=env/shared.json
```
Expected: build succeeds. This is the test for this task — compiling the entrypoint is what proves the Task 1 seam and the Task 2 overrides fit together.

If the build fails with a `no_test_kit_in_release` lint error, confirm `env/balsm/dev.json` sets `FLAVOR` to `dev`; the rule only permits `test_kit` imports in dev.

- [ ] **Step 3: Commit**

```bash
git add app/lib/brands/balsm/main_e2e.dart
git commit -m "[Test] Add main_e2e entrypoint: real boot, faked API layer"
```

---

### Task 4: Patrol on Android + the first behaviour test

**Files:**
- Modify: `app/pubspec.yaml` (dev_dependencies + a `patrol:` config block)
- Modify: `app/android/app/build.gradle.kts:37-52` (defaultConfig)
- Create: `app/android/app/src/androidTest/java/app/balsm/health/MainActivityTest.java`
- Create: `app/integration_test/patrol/sign_in_test.dart`

**Interfaces:**
- Consumes: `bootstrap` (Task 1), `FakeAuthApi` / `e2eApiOverrides` (Task 2).
- Produces: the `app/integration_test/patrol/` directory convention and a working `patrol test` command.

- [ ] **Step 1: Add the dependencies**

In `app/pubspec.yaml` under `dev_dependencies:` add:

```yaml
  patrol: ^4.9.0
```

And at the top level of the same file (a sibling of `dependencies:`), add:

```yaml
patrol:
  app_name: Balsm
  android:
    package_name: app.balsm.health
  ios:
    bundle_id: app.balsm.health
```

Then:
```bash
cd /Volumes/Dev/Balsm/balsm_app/app && fvm flutter pub get
fvm dart pub global activate patrol_cli
```

- [ ] **Step 2: Wire the Android instrumentation runner**

In `app/android/app/build.gradle.kts`, inside `defaultConfig { … }` (after the
`manifestPlaceholders["BASE_URL"]` line), add:

```kotlin
        // Patrol's instrumentation runner — required for `patrol test`.
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
```

And inside the top-level `android { … }` block, add:

```kotlin
    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }
```

- [ ] **Step 3: Add the JUnit runner shim**

Create `app/android/app/src/androidTest/java/app/balsm/health/MainActivityTest.java`:

```java
package app.balsm.health;

import androidx.test.platform.app.InstrumentationRegistry;
import pl.leancode.patrol.PatrolJUnitRunner;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;

@RunWith(Parameterized.class)
public class MainActivityTest {
    @Parameterized.Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation =
            (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    private final String dartTestName;

    @org.junit.Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation =
            (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.runDartTest(dartTestName);
    }
}
```

Confirm the package path matches `MainActivity.kt`'s package — the gradle
`namespace` is `health.balsm.app`, NOT the `applicationId`. Check and move the
file to match:

```bash
cd /Volumes/Dev/Balsm/balsm_app
find app/android/app/src/main -name "MainActivity.kt" -exec head -3 {} \;
```
If the package is `health.balsm.app`, the test file belongs at
`app/android/app/src/androidTest/java/health/balsm/app/MainActivityTest.java`
with `package health.balsm.app;`.

- [ ] **Step 4: Write the failing test**

Create `app/integration_test/patrol/sign_in_test.dart`:

```dart
import 'package:app/brands/balsm/main_balsm.dart' as app;
import 'package:core/core.dart';
import 'package:patrol/patrol.dart';

/// New-account sign-in must land on profile setup, because that is where the
/// fail-closed DOB/age gate runs. A build that sent new users straight to the
/// shell would bypass it, which is the whole reason this test exists.
void main() {
  patrolTest('a new account lands on profile setup', ($) async {
    final auth = FakeAuthApi()..nextIsNewUser = true;
    await app.bootstrap(extraOverrides: e2eApiOverrides(auth: auth));
    await $.pumpAndSettle();

    // Walkthrough → welcome.
    if ($('Skip').exists) {
      await $('Skip').tap();
    }
    await $('Get started').tap();

    // Email + password is the default sign-in mode.
    await $(#emailField).enterText(E2eFixture.email);
    await $(#passwordField).enterText('e2e-password');
    await $('Sign in').tap();

    // Profile setup asks for the name and the date of birth.
    expect($('Date of birth'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Run it to confirm it fails**

Start an Android emulator, then:
```bash
cd /Volumes/Dev/Balsm/balsm_app/app
patrol test -t integration_test/patrol/sign_in_test.dart \
  --dart-define-from-file=env/balsm/dev.json \
  --dart-define-from-file=env/shared.json
```
Expected: FAIL. The likely first failure is the `#emailField` / `#passwordField`
keys not existing — the sign-in screen's fields have no `Key` yet.

- [ ] **Step 6: Add the widget keys the test selects on**

Find the sign-in email and password `TextField`s in
`app/lib/balsm_app/screens/auth_flow.dart` (the `_PhoneScreen` password path,
around line 400) and give each a key:

```dart
key: const Key('emailField'),
```
```dart
key: const Key('passwordField'),
```

Keys are the stable selector — label text changes with translation and with
copy edits, and a test that selects on visible English text breaks the moment
someone runs the Arabic flow.

- [ ] **Step 7: Run the test to verify it passes**

Run:
```bash
cd /Volumes/Dev/Balsm/balsm_app/app
patrol test -t integration_test/patrol/sign_in_test.dart \
  --dart-define-from-file=env/balsm/dev.json \
  --dart-define-from-file=env/shared.json
```
Expected: PASS.

If the app reaches the home shell instead of profile setup, the `nextIsNewUser`
knob is not reaching the sign-in path — check that `e2eApiOverrides(auth: auth)`
passes the same instance the test configured.

- [ ] **Step 8: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/android/app/build.gradle.kts \
  app/android/app/src/androidTest app/integration_test/patrol/sign_in_test.dart \
  app/lib/balsm_app/screens/auth_flow.dart
git commit -m "[Test] Patrol on Android + first behaviour test

New-account sign-in must reach profile setup, where the fail-closed
DOB/age gate runs. Adds Key()s to the sign-in fields so selectors survive
translation."
```

---

### Task 5: The remaining Patrol behaviour tests

**Files:**
- Create: `app/integration_test/patrol/returning_account_test.dart`
- Create: `app/integration_test/patrol/lockout_test.dart`
- Create: `app/integration_test/patrol/sign_in_failure_test.dart`
- Create: `app/integration_test/patrol/disclosure_gate_test.dart`

**Interfaces:**
- Consumes: `bootstrap`, `e2eApiOverrides`, `FakeAuthApi`, `E2eFixture`, and the `#emailField` / `#passwordField` keys added in Task 4.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write the returning-account test**

Create `app/integration_test/patrol/returning_account_test.dart`:

```dart
import 'package:app/brands/balsm/main_balsm.dart' as app;
import 'package:core/core.dart';
import 'package:patrol/patrol.dart';

/// A returning account accepts the disclosure once and reaches the shell. This
/// is the counterpart to the new-account test: the same sign-in must NOT stop
/// at profile setup for someone who already has an account.
void main() {
  patrolTest('a returning account reaches the shell through the gate', ($) async {
    await app.bootstrap(extraOverrides: e2eApiOverrides());
    await $.pumpAndSettle();

    if ($('Skip').exists) {
      await $('Skip').tap();
    }
    await $('Get started').tap();
    await $(#emailField).enterText(E2eFixture.email);
    await $(#passwordField).enterText('e2e-password');
    await $('Sign in').tap();

    // Not profile setup — the fixture reports an existing account.
    expect($('Date of birth'), findsNothing);

    // The fail-closed gate stands between sign-in and the shell; accept it.
    await $('Accept').tap();
    await $.pumpAndSettle();

    expect($(#appShell), findsOneWidget);
  });
}
```

If `Accept` is not the gate's button label, read the real one from
`_DisclosureGateScreen` in `app/lib/balsm_app/screens/auth_flow.dart` and use
that. Add `key: const Key('appShell')` to the shell's root widget in
`app/lib/balsm_app/shell.dart` — asserting on a key rather than on visible text
keeps the test working in Arabic.

- [ ] **Step 2: Write the lockout test**

Create `app/integration_test/patrol/lockout_test.dart`:

```dart
import 'package:app/brands/balsm/main_balsm.dart' as app;
import 'package:core/core.dart';
import 'package:patrol/patrol.dart';

/// A locked account must surface the countdown and stay put. Navigating anyway
/// would hand out a session the server already refused.
void main() {
  patrolTest('a lockout shows the countdown and does not navigate', ($) async {
    final auth = FakeAuthApi()..lockedOut = true;
    await app.bootstrap(extraOverrides: e2eApiOverrides(auth: auth));
    await $.pumpAndSettle();

    if ($('Skip').exists) {
      await $('Skip').tap();
    }
    await $('Get started').tap();
    await $(#emailField).enterText(E2eFixture.email);
    await $(#passwordField).enterText('e2e-password');
    await $('Sign in').tap();

    expect($(RegExp('Account temporarily locked')), findsOneWidget);
    expect($('Date of birth'), findsNothing);
  });
}
```

- [ ] **Step 3: Write the sign-in failure test**

Create `app/integration_test/patrol/sign_in_failure_test.dart`:

```dart
import 'package:app/brands/balsm/main_balsm.dart' as app;
import 'package:core/core.dart';
import 'package:patrol/patrol.dart';

/// A rejected sign-in shows the error and stays on the form. The fake's
/// failure knob is one-shot, so the retry proves the screen recovers rather
/// than latching into an error state.
void main() {
  patrolTest('a failed sign-in shows the error, and a retry recovers', ($) async {
    final auth = FakeAuthApi()..failNextSignIn = true;
    await app.bootstrap(extraOverrides: e2eApiOverrides(auth: auth));
    await $.pumpAndSettle();

    if ($('Skip').exists) {
      await $('Skip').tap();
    }
    await $('Get started').tap();
    await $(#emailField).enterText(E2eFixture.email);
    await $(#passwordField).enterText('wrong-password');
    await $('Sign in').tap();

    expect($('Invalid email or password.'), findsOneWidget);

    // Same form, second attempt — the knob cleared itself.
    await $('Sign in').tap();
    expect($('Invalid email or password.'), findsNothing);
  });
}
```

- [ ] **Step 4: Write the disclosure gate test**

Create `app/integration_test/patrol/disclosure_gate_test.dart`:

```dart
import 'package:app/brands/balsm/main_balsm.dart' as app;
import 'package:core/core.dart';
import 'package:patrol/patrol.dart';

/// The disclosure gate is fail-closed: backing out without accepting must not
/// grant access to the app shell. It sits between every sign-in path and 'app',
/// so a leak here defeats it for OTP and password sign-in alike.
void main() {
  patrolTest('declining the disclosure never reaches the app shell', ($) async {
    await app.bootstrap(extraOverrides: e2eApiOverrides());
    await $.pumpAndSettle();

    if ($('Skip').exists) {
      await $('Skip').tap();
    }
    await $('Get started').tap();
    await $(#emailField).enterText(E2eFixture.email);
    await $(#passwordField).enterText('e2e-password');
    await $('Sign in').tap();

    // Returning account → the gate. Back out instead of accepting.
    await $.native.pressBack();
    await $.pumpAndSettle();

    expect($(#appShell), findsNothing, reason: 'the fail-closed gate must not be bypassable');
  });
}
```

- [ ] **Step 5: Run all four**

Run:
```bash
cd /Volumes/Dev/Balsm/balsm_app/app
patrol test -t integration_test/patrol/ \
  --dart-define-from-file=env/balsm/dev.json \
  --dart-define-from-file=env/shared.json
```
Expected: 5 tests pass (the 4 new ones plus Task 4's).

If the disclosure test finds the gate already accepted, the previous test left
an acceptance row in the on-device database. Add `clearPackageData` handling by
confirming Task 4 Step 2's `testInstrumentationRunnerArguments` took effect, or
uninstall between runs with `adb uninstall app.balsm.health`.

- [ ] **Step 6: Commit**

```bash
git add app/integration_test/patrol/ app/lib/balsm_app/shell.dart
git commit -m "[Test] Patrol: returning account, lockout, sign-in failure, disclosure gate"
```

---

### Task 6: The Maestro suite

**Files:**
- Modify: `app/.maestro/wt_flow.yaml` (currently untracked — this commits it)
- Create: `app/.maestro/sign_in_flow.yaml`
- Create: `app/.maestro/sign_in_flow_ar.yaml`

**Interfaces:**
- Consumes: the `main_e2e.dart` build (Task 3). Maestro drives an installed binary; it does not import Dart.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Install and launch the e2e build**

Run:
```bash
cd /Volumes/Dev/Balsm/balsm_app/app
fvm flutter install --debug -t lib/brands/balsm/main_e2e.dart \
  --dart-define-from-file=env/balsm/dev.json \
  --dart-define-from-file=env/shared.json
```
Expected: the stubbed build installs on the running emulator or device.

- [ ] **Step 2: Confirm the existing walkthrough flow still passes**

Run:
```bash
cd /Volumes/Dev/Balsm/balsm_app/app
maestro test .maestro/wt_flow.yaml
```
Expected: PASS with three screenshots written. This flow already existed and is
being brought under version control unchanged.

- [ ] **Step 3: Write the happy-path flow**

Create `app/.maestro/sign_in_flow.yaml`:

```yaml
# Happy path against the stubbed build (main_e2e.dart): welcome → sign-in →
# disclosure → home, with a screenshot at each step. Behaviour and error paths
# belong to Patrol; this flow answers "does the happy path still render".
appId: app.balsm.health
---
- launchApp:
    clearState: true
- runFlow:
    when:
      visible: "Skip"
    commands:
      - tapOn: "Skip"
- assertVisible: "Get started"
- takeScreenshot: si-01-welcome
- tapOn: "Get started"
- assertVisible: "Password"
- takeScreenshot: si-02-signin
- tapOn:
    id: "emailField"
- inputText: "e2e@balsm.test"
- tapOn:
    id: "passwordField"
- inputText: "e2e-password"
- takeScreenshot: si-03-filled
- tapOn: "Sign in"
- takeScreenshot: si-04-after-signin
```

- [ ] **Step 4: Write the Arabic pass**

Create `app/.maestro/sign_in_flow_ar.yaml`:

```yaml
# Same path in Arabic. RTL flips the layout, and Arabic strings are longer than
# their English counterparts — this is where truncation and overflow show up.
appId: app.balsm.health
---
- launchApp:
    clearState: true
- runFlow:
    when:
      visible: "Skip"
    commands:
      - tapOn: "Skip"
- tapOn: "العربية"
- takeScreenshot: ar-01-welcome
- tapOn:
    id: "emailField"
- inputText: "e2e@balsm.test"
- tapOn:
    id: "passwordField"
- inputText: "e2e-password"
- takeScreenshot: ar-02-signin
```

The language pill shows the *other* language, so in English it reads `العربية`.
The existing widget test `app/test/social_sign_in_test.dart` and
`app/integration_test/auth_ui_test.dart` both rely on that same behaviour.

- [ ] **Step 5: Run the whole suite**

Run:
```bash
cd /Volumes/Dev/Balsm/balsm_app/app
maestro test .maestro/
```
Expected: 3 flows pass.

If `tapOn: id:` does not match, Maestro reads Flutter's semantics identifiers
rather than widget `Key`s. Confirm with `maestro studio` and, if needed, wrap
each field in a `Semantics(identifier: 'emailField', …)` in
`app/lib/balsm_app/screens/auth_flow.dart` next to the `Key` added in Task 4.

- [ ] **Step 6: Commit**

```bash
git add app/.maestro/
git commit -m "[Test] Maestro suite: walkthrough, happy-path sign-in, Arabic pass"
```

---

### Task 7: melos scripts and the deferred-iOS runbook

**Files:**
- Modify: `melos.yaml:29-30`
- Modify: `docs/superpowers/specs/2026-09-10-e2e-maestro-patrol-design.md` (status line)
- Create: `docs/e2e-testing.md`

**Interfaces:**
- Consumes: everything above.
- Produces: `melos e2e`, `melos e2e:patrol`, `melos e2e:maestro`.

- [ ] **Step 1: Narrow `e2e` and add the two new scripts**

In `melos.yaml`, replace lines 29-30:

```yaml
  e2e:
    run: melos exec --scope=app -- "flutter test integration_test"
```

with:

```yaml
  # Widget-level on-device test. Narrowed to the one file: Patrol tests live in
  # integration_test/patrol/ and need Patrol's own runner, so the plain runner
  # must not pick them up.
  e2e:
    run: melos exec --scope=app -- "flutter test integration_test/auth_ui_test.dart"
  # Behaviour tests (branches, forced failures, native dialogs). Android only
  # until the iOS RunnerUITests target exists — see docs/e2e-testing.md.
  e2e:patrol:
    run: melos exec --scope=app -- "patrol test -t integration_test/patrol/ --dart-define-from-file=env/balsm/dev.json --dart-define-from-file=env/shared.json"
  # Happy-path + screenshots against an installed main_e2e.dart build.
  e2e:maestro:
    run: melos exec --scope=app -- "maestro test .maestro/"
```

- [ ] **Step 2: Verify the narrowed script still passes**

Run:
```bash
cd /Volumes/Dev/Balsm/balsm_app
fvm dart run melos e2e
```
Expected: `auth_ui_test.dart` runs and passes; no Patrol file is picked up.

- [ ] **Step 3: Write the runbook**

Create `docs/e2e-testing.md`:

````markdown
# E2E testing

Two tools, one stubbed build. Design: `docs/superpowers/specs/2026-09-10-e2e-maestro-patrol-design.md`.

| Tool | Owns | Platforms |
|---|---|---|
| Patrol | Behaviour: branches, forced failures, native dialogs, widget assertions | Android |
| Maestro | Happy path and screenshots | Android + iOS |

Rule of thumb: if it needs to reach inside the app, it is Patrol. If it is
"does the happy path still render", it is Maestro.

## No backend

`e2eApiOverrides()` (in `packages/core/lib/src/test_kit/fake_apis.dart`) binds
all eight `Provider<XxxApi>` seams to in-memory fakes. The on-device database
and secure storage stay real — the disclosure gate reading real acceptance rows
is the behaviour under test.

The fixture is `E2eFixture`: user `00000000-0000-0000-0000-000000000001`,
`e2e@balsm.test`, country `EG`. No health data, per `AGENTS.md`.

## Running

```bash
melos e2e            # widget-level on-device test
melos e2e:patrol     # Patrol behaviour tests (Android, emulator running)
melos e2e:maestro    # Maestro flows (install the e2e build first, below)
```

Maestro needs the stubbed binary installed:

```bash
cd app
fvm flutter install --debug -t lib/brands/balsm/main_e2e.dart \
  --dart-define-from-file=env/balsm/dev.json \
  --dart-define-from-file=env/shared.json
```

None of this runs in CI yet — that was a deliberate call, and the risk is a
suite that rots unrun. Adding an Android emulator job is a self-contained
follow-up.

## Enabling Patrol on iOS

Deferred because it needs a `RunnerUITests` target, which is a GUI operation —
hand-editing `project.pbxproj` fails in subtle ways. Ten minutes in Xcode:

1. Open `app/ios/Runner.xcworkspace`.
2. File → New → Target → **UI Testing Bundle**. Name it `RunnerUITests`, set
   Target to be Tested to `Runner`.
3. Set the new target's bundle id to `app.balsm.health.RunnerUITests`.
4. Delete the generated `RunnerUITests.swift` and add Patrol's, per
   <https://patrol.leancode.co/documentation/native/setup-ios>.
5. Run `patrol test -t integration_test/patrol/ -d <simulator-udid>`.

The Dart tests need no changes — they already run unmodified on iOS.
````

- [ ] **Step 4: Mark the spec implemented**

In `docs/superpowers/specs/2026-09-10-e2e-maestro-patrol-design.md`, change:

```markdown
**Status:** Approved, not yet implemented
```

to:

```markdown
**Status:** Implemented 2026-09-10 — Patrol on Android; Patrol on iOS still deferred (runbook in `docs/e2e-testing.md`)
```

- [ ] **Step 5: Full verification sweep**

Run:
```bash
cd /Volumes/Dev/Balsm/balsm_app
fvm dart analyze app packages modules
fvm dart run melos test
fvm dart run melos boundaries
fvm dart run melos e2e
```
Expected: analyze clean apart from the pre-existing `app_database.g.dart`
warning; all unit suites pass; boundary lint clean; `e2e` passes.

- [ ] **Step 6: Commit**

```bash
git add melos.yaml docs/e2e-testing.md docs/superpowers/specs/2026-09-10-e2e-maestro-patrol-design.md
git commit -m "[Docs] E2E runbook + melos scripts for Patrol and Maestro"
```
