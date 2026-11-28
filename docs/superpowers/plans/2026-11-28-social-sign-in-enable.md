# Enable Sign in with Apple + Google — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn on Apple (iOS) + Google (iOS/Android/macOS) sign-in laid out per the Auth Flow design, and make Apple grant revocation on account deletion real.

**Architecture:** API: port the `SocialSignIn:Enabled` gate + boot audience check from `feature/social-sign-in` (`8cb9743`) by hand; capture an Apple refresh token at `/auth/apple`, store it encrypted on `UserIdentity`, revoke it from the deletion purge through a SharedKernel contract. App: one shared `SocialSignInBlock` widget (buttons + divider + error) used by the Welcome and email screens; platform/config rules in one pure function.

**Tech Stack:** .NET 10 / EF Core (SQLite + Npgsql migrations) / xUnit; Flutter (fvm) / Riverpod / i69n / mocktail.

**Spec:** `docs/superpowers/specs/2026-11-28-social-sign-in-enable-design.md`

**Repos/branches:** API work in `../Balsm-API-DotNet` on its current feature branch `claude/design-implementation-7civd6` (commit straight to it). App work in `balsm_app` on `claude/design-implementation-7civd6`. Do **not** stage the pre-existing unrelated changes in `app/ios/Runner.xcodeproj/project.pbxproj` and `Package.resolved`.

## Global Constraints

- Apple: iOS only. Google: iOS, Android, macOS. Never web, Windows, Linux.
- Apple's token audience is the bundle id `app.balsm.health` (`Apple:ClientId`); Google's is the **web** client id on every platform.
- Endpoints return `404` while `SocialSignIn:Enabled` is false; `400 {"error":{"code":"CountryCodeRequired"}}` on blank `country_code`.
- Never log, store in plaintext, or send to telemetry an ID token, authorization code, Apple refresh token, or email.
- Cancelling a provider sheet shows nothing.
- Copy (en / ar), from the design:
  - `w_apple`: "Continue with Apple" / "المتابعة باستخدام Apple"
  - `w_google`: "Continue with Google" / "المتابعة باستخدام Google"
  - `w_or_email`: "or with email" / "أو بالبريد الإلكتروني"
- Apple button: black fill (`AppColors.nearBlack`), white text + Apple mark. Google: white fill, ink-200 border, Google "G". Height 52 (Welcome), 48 (email screen, `compact`). Gap 10 between buttons.
- `EdgeInsetsDirectional` only; no inline `ar ? … : …` strings; run `dart run build_runner build` in `app/` after editing `.jsonc`.
- API: every endpoint change updates `docs/api/insomnia/auth.yaml`; migrations implement `Up()` and `Down()` for both SQLite and Npgsql sets; `dotnet format` before commit.
- App: one `changelog.d/<n>.added.md` note; never touch `version:` or `CHANGELOG.md`.

## Review Focus

1. **iOS build with Google ids still empty** — Google button must stay hidden on iOS and no placeholder URL scheme may enter `Info.plist` (ASC error 90158). Test in Task 6.
2. **Apple returns no email on a repeat authorization** — existing account must still sign in by `sub`; handler must not require email. Test in Task 3.
3. **Apple code exchange fails or Apple key config absent** — sign-in still returns tokens; identity keeps no refresh token. Test in Task 3.
4. **Account purged without any Apple identity, or with an identity but no token** — purge continues, status `no_apple_identity` / `no_refresh_token`, other accounts in the batch still purged. Test in Task 4.
5. **Two taps on different providers** — while one provider flow runs, both buttons are disabled. Test in Task 6.
6. **Same person, two spellings of one Gmail address** — sign-up with a dotted/cased variant must hit the existing account, not create a second. Test in Task 2.

---

### Task 1: API — social sign-in gate + boot audience check

**Files:**
- Modify: `src/Modules/Auth/Balsm.Auth.Api/Controllers/AuthController.cs` (`Google`, `Apple` actions; `OidcRequest` at line ~298)
- Modify: `src/Balsm.Infrastructure/DependencyInjection.cs` (after `services.AddScoped<AppleOidcValidator>()`)
- Modify: `src/Balsm.API/appsettings.Development.json`, `src/Balsm.API/appsettings.Local.json` (`"SocialSignIn": { "Enabled": true }`)
- Modify: `docs/api/insomnia/auth.yaml` (both social bodies snake_case incl. `country_code`; Apple body adds `authorization_code`; add a 404-while-disabled note in each description)
- Test: `tests/Balsm.API.IntegrationTests/AuthSocialSignInEndpointTests.cs`, `tests/Balsm.API.Tests/SocialSignInBootValidationTests.cs`

**Interfaces:**
- Produces: `public sealed record OidcRequest(string IdToken, Guid DeviceId, string DeviceLabel, string CountryCode, string? AuthorizationCode = null);`
- Produces: `internal static void RequireSocialSignInAudiences(IConfiguration configuration)` (throws `InvalidOperationException` naming every missing key of `Google:ClientId`, `Apple:ClientId`), called only when `SocialSignIn:Enabled` is true.

Port the code from `git show 8cb9743 -- src/Balsm.Infrastructure/DependencyInjection.cs src/Modules/Auth/Balsm.Auth.Api/Controllers/AuthController.cs` (reference only — do not merge the branch). Drop the old comment about team ownership; the gate now exists so ops can switch the feature off without a release.

- [ ] **Step 1: Write failing tests**
  - `PostGoogle_WhenDisabled_Returns404` / `PostApple_WhenDisabled_Returns404` (factory with `SocialSignIn:Enabled=false`)
  - `PostApple_WhenCountryCodeBlank_Returns400CountryCodeRequired` (enabled; body `country_code: ""`; assert JSON `error.code == "CountryCodeRequired"`)
  - `AddSharedInfrastructure_WhenEnabledAndGoogleClientIdMissing_ThrowsNamingKey` (message contains `Google:ClientId`)
  - `AddSharedInfrastructure_WhenDisabledAndIdsMissing_DoesNotThrow`
- [ ] **Step 2: Run** `dotnet test tests/Balsm.API.IntegrationTests --filter "FullyQualifiedName~AuthSocialSignIn"` and `dotnet test tests/Balsm.API.Tests --filter "FullyQualifiedName~SocialSignInBootValidation"` — Expected: FAIL.
- [ ] **Step 3: Implement** gate (`if (!SocialSignInEnabled) return NotFound();` then blank-country 400) in both actions, `AuthorizationCode` on `OidcRequest`, `RequireSocialSignInAudiences` in DI, appsettings, insomnia.
- [ ] **Step 4: Run** the same tests — Expected: PASS. Then `dotnet build Balsm.API.slnx -c Release` — 0 warnings.
- [ ] **Step 5: Commit** (`dotnet format` first)

```bash
git add src/Modules/Auth/Balsm.Auth.Api src/Balsm.Infrastructure/DependencyInjection.cs src/Balsm.API/appsettings.Development.json src/Balsm.API/appsettings.Local.json docs/api/insomnia/auth.yaml tests
git commit -m "[Auth] Gate social sign-in behind SocialSignIn:Enabled and check audiences at boot"
```

### Task 2: API — key every identity on a stable sign-in id, never the email

Accounts link to the sign-in id: Google/Apple `sub` (already the unique key) and, for email identities, a stable opaque id instead of the address. The email becomes changeable data. Gmail addresses that differ only by case, dots or a `+tag` are one mailbox and must resolve to one identity (`hossamEldin.M.I@gmail.com` ≡ `hossameldinmi@gmail.com`). No account is ever merged or linked across providers by email.

**Files:**
- Create: `src/Modules/Auth/Balsm.Auth.Domain/ValueObjects/EmailCanonical.cs`
- Modify: `src/Modules/Auth/Balsm.Auth.Domain/Entities/UserIdentity.cs`
- Modify: `src/Modules/Auth/Balsm.Auth.Infrastructure/Configuration/UserIdentityConfiguration.cs` (column `email_canonical` text; partial unique index on `email_canonical` where `provider = 'email'`, replacing the old partial unique on `email_normalized`)
- Modify: every email lookup — `VerifyOtpHandler`, `VerifyLinkHandler`, `ResetPasswordHandler`, `RequestOtpHandler`, `PasswordSignInHandler`, `RecoveryClaimHandler` — to match on `EmailCanonical == EmailCanonical.From(input)`; `VerifyOtpHandler`/`VerifyLinkHandler` create email identities with `UserIdentity.CreateEmail(...)`
- Modify: `ExchangeGoogleTokenHandler` (email optional; refresh snapshot), `ExchangeAppleTokenHandler` (refresh snapshot only when the token carries an email; drop the synthetic `apple_{sub}@private.balsm.app` from the stored column — use it only for the JWT `email` claim if one is required)
- Create: migration `KeyEmailIdentitiesOnStableId` in both Auth migration projects. `Up()`: add `email_canonical`; backfill it from `email_normalized` with the same rules (SQL for Postgres; C# loop acceptable in the SQLite set); set `provider_subject = id::text` for `provider = 'email'`; swap the unique index. If two existing email rows collapse to the same canonical value, **abort the migration** with a message listing their `id`s (no auto-merge — ops resolve by hand). `Down()`: restore `provider_subject = email_normalized` and the old index, drop the column.
- Test: `tests/Modules/Balsm.Auth.Tests/EmailCanonicalTests.cs`, `tests/Modules/Balsm.Auth.Tests/StableIdentityKeyTests.cs`

**Interfaces:**
- Produces:
  ```csharp
  public static class EmailCanonical
  {
      /// Trim + lowercase. For gmail.com / googlemail.com: drop dots and any "+suffix"
      /// in the local part, domain → gmail.com. Other domains: lowercase only.
      public static string From(string email);
  }
  ```
- Produces (`UserIdentity`): `string? EmailCanonical { get; private set; }`; `static UserIdentity CreateEmail(Guid userId, string email)` (subject = the new row's `Id.ToString()`; sets `EmailNormalized` = trimmed lowercase as typed, `EmailCanonical`); `void ChangeEmail(string email)` (updates both, clears `EmailConfirmedAt` — the new address is unproven); `void RefreshProviderEmail(string? email)` (social only; no-op on null/blank; keeps `EmailConfirmedAt` handling to the caller).
- `Create(...)` for google/apple unchanged (subject = `sub`) but also fills `EmailCanonical` when an email is given.

Emails keep going to the address as typed (`EmailNormalized`), never to the canonical form.

- [ ] **Step 1: Write failing tests**
  - `From_GmailDotsAndCase_Collapse` (`"hossamEldin.M.I@gmail.com"` and `"hossameldinmi@gmail.com"` → both `"hossameldinmi@gmail.com"`)
  - `From_GmailPlusTag_Dropped` (`"a.b+balsm@googlemail.com"` → `"ab@gmail.com"`)
  - `From_OtherDomain_KeepsDots` (`"First.Last@Balsm.Health"` → `"first.last@balsm.health"`)
  - `PasswordSignIn_WithDottedGmailVariant_FindsSameIdentity`
  - `RequestOtp_SignUpWithDottedVariantOfExisting_ReportsExists` (no second account)
  - `ChangeEmail_KeepsProviderSubjectAndUserId_ClearsConfirmation`
  - `GoogleSignIn_EmailChangedAtGoogle_SameUserAndSnapshotUpdated` (same `sub`, new email → `IsNewUser == false`, `EmailNormalized` updated)
  - `GoogleSignIn_TokenWithoutEmail_Succeeds`
  - `AppleRepeatSignInWithoutEmail_KeepsStoredEmail`
  - `SocialSignIn_EmailMatchesExistingEmailAccount_CreatesSeparateAccount` (pins "no merge by email")
  - Migration test against SQLite: seed two email rows, run `Up()`, assert `provider_subject == id` and canonical filled; seed a colliding pair → `Up()` throws naming both ids.
- [ ] **Step 2: Run** `dotnet test tests/Modules/Balsm.Auth.Tests --filter "FullyQualifiedName~EmailCanonical|FullyQualifiedName~StableIdentityKey"` — Expected: FAIL.
- [ ] **Step 3: Implement** value object, entity members, handler lookups, social handlers, EF config, migrations.
- [ ] **Step 4: Run** the filter above, then `dotnet test tests/Modules/Balsm.Auth.Tests` and `dotnet test tests/Balsm.API.IntegrationTests` — Expected: PASS (existing auth flows unchanged for non-Gmail addresses).
- [ ] **Step 5: Commit**

```bash
git add src/Modules/Auth tests/Modules/Balsm.Auth.Tests
git commit -m "[Auth] Key identities on a stable sign-in id and treat Gmail variants as one address"
```

### Task 3: API — capture the Apple refresh token at sign-in

**Files:**
- Create: `src/Balsm.Infrastructure/Auth/AppleTokenClient.cs`
- Create: `src/Balsm.Infrastructure/Encryption/AppleRefreshTokenCipher.cs`
- Modify: `src/Balsm.Infrastructure/DependencyInjection.cs` (register both scoped; named HttpClient `"apple"` with 10 s timeout if not already registered)
- Modify: `src/Modules/Auth/Balsm.Auth.Domain/Entities/UserIdentity.cs`
- Modify: `src/Modules/Auth/Balsm.Auth.Application/Commands/ExchangeAppleTokenCommand.cs`
- Modify: `src/Modules/Auth/Balsm.Auth.Infrastructure/Handlers/ExchangeAppleTokenHandler.cs`
- Modify: `src/Modules/Auth/Balsm.Auth.Api/Controllers/AuthController.cs` (pass `req.AuthorizationCode`)
- Modify: Auth EF configuration for `UserIdentity` (column `apple_refresh_token_ciphertext`, nullable blob/bytea)
- Create: migration `AddAppleRefreshTokenToUserIdentity` in `Balsm.Auth.Infrastructure` (Npgsql) **and** `Balsm.Auth.Infrastructure.Migrations.Sqlite`
- Test: `tests/Modules/Balsm.Auth.Tests/ExchangeAppleTokenHandlerTests.cs`, `tests/Modules/Balsm.Auth.Tests/AppleRefreshTokenCipherTests.cs`

**Interfaces:**
- Produces (`Balsm.Infrastructure.Auth`):
  ```csharp
  public class AppleTokenClient   // methods virtual so tests can fake
  {
      public virtual bool IsConfigured { get; }                       // Apple:TeamId, ClientId, KeyId, PrivateKey all present
      public virtual Task<string?> ExchangeCodeAsync(string authorizationCode, CancellationToken ct); // refresh_token or null on any failure
      public virtual Task<AppleRevokeOutcome> RevokeAsync(string refreshToken, CancellationToken ct);
  }
  public enum AppleRevokeOutcome { Revoked, ConfigMissing, Failed }
  ```
  `ExchangeCodeAsync` → POST `https://appleid.apple.com/auth/token` form `client_id, client_secret, code, grant_type=authorization_code`. `RevokeAsync` → POST `https://appleid.apple.com/auth/revoke` form `client_id, client_secret, token, token_type_hint=refresh_token`. Move `BuildClientSecret` (ES256 JWT, `iss`=TeamId, `sub`/client_id=`Apple:ClientId`, `aud`=`https://appleid.apple.com`, 5-minute expiry, `kid`=KeyId) here from `AppleRevokeService`.
- Produces (`Balsm.Infrastructure.Encryption`): `public sealed class AppleRefreshTokenCipher { byte[] Encrypt(string token); string Decrypt(byte[] blob); }` — AES-256-GCM, layout `nonce(12)||tag(16)||ciphertext` like `DobEncryptionService`; key = `HKDF.DeriveKey(HashAlgorithmName.SHA256, dobKey, 32, info: "balsm/apple-refresh-token/v1")` from `DobEncryption:Key`.
- Produces (`UserIdentity`): `byte[]? AppleRefreshTokenCiphertext { get; private set; }`, `void SetAppleRefreshToken(byte[] ciphertext)`, `void ClearAppleRefreshToken()`.
- Produces: `ExchangeAppleTokenCommand(string IdToken, Guid DeviceId, string DeviceLabel, string CountryCode, string? AuthorizationCode)`.

Handler: after resolving/creating the identity, if `AuthorizationCode` is non-blank **and** `appleTokens.IsConfigured`, call `ExchangeCodeAsync`; on a non-null result `identity.SetAppleRefreshToken(cipher.Encrypt(token))` (replaces any older one). On null/exception: log a warning with `UserId` only and continue. Never let this path throw.

- [ ] **Step 1: Write failing tests**
  - `Cipher_RoundTrips` and `Cipher_KeyDiffersFromDobKey` (encrypting with the DOB service's raw key fails to decrypt — assert `CryptographicException`)
  - `Handle_NewUserWithCode_StoresEncryptedRefreshToken` (fake client returns `"r-1"`; stored bytes ≠ UTF-8 of `"r-1"`; `cipher.Decrypt(...) == "r-1"`)
  - `Handle_ExchangeReturnsNull_StillReturnsTokensAndStoresNothing`
  - `Handle_ClientNotConfigured_DoesNotCallExchange`
  - `Handle_RepeatSignInWithoutEmail_ResolvesExistingIdentityBySubject` (payload `Email=null`, existing identity with same `sub`; `IsNewUser == false`, same `UserId`)
- [ ] **Step 2: Run** `dotnet test tests/Modules/Balsm.Auth.Tests --filter "FullyQualifiedName~AppleRefreshTokenCipher|FullyQualifiedName~ExchangeAppleTokenHandler"` — Expected: FAIL.
- [ ] **Step 3: Implement** the client, cipher, entity members, command field, handler, controller pass-through, EF config.
- [ ] **Step 4: Add migrations** with the CLAUDE.md `dotnet ef migrations add` form for both projects (`--context AuthDbContext`); confirm each has `Up()` adding and `Down()` dropping the column.
- [ ] **Step 5: Run** the tests — Expected: PASS. `dotnet build Balsm.API.slnx -c Release` — 0 warnings.
- [ ] **Step 6: Commit**

```bash
git add src tests
git commit -m "[Auth] Store an encrypted Apple refresh token at Apple sign-in"
```

### Task 4: API — revoke the Apple grant when an account is purged

**Files:**
- Create: `src/Balsm.SharedKernel/Contracts/IAppleGrantRevoker.cs`
- Create: `src/Modules/Auth/Balsm.Auth.Infrastructure/Services/AppleGrantRevoker.cs`
- Modify: `src/Balsm.API/Program.cs` (register next to `IAccountFamilyLinkEraser`)
- Modify: `src/Modules/Deletion/Balsm.Deletion.Infrastructure/Jobs/DeletionPurgeJob.cs` (call per account, before `accountDb.UserAccounts.Remove(account)`)
- Delete: `src/Modules/Deletion/Balsm.Deletion.Infrastructure/Services/AppleRevokeService.cs` and its registration in `Balsm.Deletion.Infrastructure/DependencyInjection.cs`
- Test: `tests/Modules/Balsm.Auth.Tests/AppleGrantRevokerTests.cs`, `tests/Modules/Balsm.Deletion.Tests/AppleRevokePurgeTests.cs`

**Interfaces:**
- Consumes: `AppleTokenClient.RevokeAsync`, `AppleRefreshTokenCipher.Decrypt`, `UserIdentity.ClearAppleRefreshToken` (Task 3).
- Produces:
  ```csharp
  public interface IAppleGrantRevoker
  {
      /// Returns one of: "no_apple_identity", "no_refresh_token", "config_missing", "revoked", "failed".
      Task<string> RevokeForAccountAsync(Guid userId, CancellationToken ct = default);
  }
  ```
  Implementation clears the stored token after `Revoked` and saves. Never throws (catch, log `UserId` only, return `"failed"`).

Purge job: resolve `IAppleGrantRevoker` from the scope; for each expired account set the status on the matching `DeletionLog` (`UserIdHash` = existing SHA-256 hex of the user id bytes — move `ComputeHash` from the deleted service into the job) via `SetAppleRevokeStatus(status)`; save `deletionDb` with the existing save.

- [ ] **Step 1: Write failing tests**
  - Revoker: `RevokeForAccount_NoIdentity_ReturnsNoAppleIdentity`, `…_IdentityWithoutToken_ReturnsNoRefreshToken`, `…_ClientNotConfigured_ReturnsConfigMissing`, `…_Revoked_ClearsStoredToken`, `…_ClientThrows_ReturnsFailed`
  - Purge: `Purge_RecordsAppleRevokeStatusOnDeletionLog` and `Purge_RevokerFailsForOneAccount_StillPurgesTheRest` (two expired accounts, fake revoker returns `"failed"` for the first; both `UserAccounts` gone)
- [ ] **Step 2: Run** `dotnet test tests/Modules/Balsm.Auth.Tests --filter "FullyQualifiedName~AppleGrantRevoker"` and `dotnet test tests/Modules/Balsm.Deletion.Tests --filter "FullyQualifiedName~AppleRevokePurge"` — Expected: FAIL.
- [ ] **Step 3: Implement** contract, revoker, Program.cs wiring, purge call; delete the old service + registration.
- [ ] **Step 4: Run** those tests, then the whole suite `dotnet test Balsm.API.slnx` — Expected: PASS.
- [ ] **Step 5: Update** `../balsm_app/docs/social-sign-in-setup.md` later (Task 7) — nothing here. Commit:

```bash
git add src tests
git commit -m "[Deletion] Revoke the Apple grant with the stored refresh token on purge"
```

### Task 5: App — provider availability rule

**Files:**
- Create: `app/lib/balsm_app/screens/social_providers.dart`
- Test: `app/test/social_providers_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum SocialProvider { apple, google }
  /// Ordered as drawn: Apple first, then Google.
  List<SocialProvider> availableSocialProviders({
    required FlavorConfig config,
    required TargetPlatform platform,
    required bool isWeb,
  });
  ```
  Rules: empty when `isWeb` or `!config.socialSignInEnabled`. Apple: `platform == iOS`. Google: `config.googleServerClientId` non-empty **and** (`android` or `macOS`, or `iOS` with `config.googleIosClientId` non-empty).

- [ ] **Step 1: Write failing tests** — `ios_withAllIds_returnsAppleThenGoogle`, `ios_withoutIosClientId_returnsAppleOnly`, `android_returnsGoogleOnly`, `macos_returnsGoogleOnly`, `web_returnsEmpty`, `flagOff_returnsEmpty`, `android_withoutServerClientId_returnsEmpty`, `windows_returnsEmpty`.
- [ ] **Step 2: Run** `cd app && fvm flutter test test/social_providers_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** `git add app/lib/balsm_app/screens/social_providers.dart app/test/social_providers_test.dart && git commit -m "Decide which social sign-in providers each platform offers"`

### Task 6: App — `SocialSignInBlock` on Welcome and email screens

**Files:**
- Create: `app/lib/balsm_app/screens/social_sign_in_block.dart` (move `_SocialButton`, `_GoogleMark`, `_kGoogleGSvg` here from `auth_flow.dart` as private members; add `_AppleMark` using the design's Apple path, `currentColor` → white)
- Modify: `app/lib/balsm_app/screens/auth_flow.dart`
  - `_WelcomeScreenState`: delete `_busyGoogle`, `_googleAvailable`, `_signInGoogle` and the Google block under the CTAs; insert `SocialSignInBlock(compact: false)` directly under the sub-title (after the 30 px gap), before "Create an account". Keep `_error` only if still used by other code; otherwise remove.
  - `_PhoneScreen` build: insert `SocialSignInBlock(compact: true)` between the help text and the email field, only for `AuthIntent.signUp` / `AuthIntent.signIn`, followed by 18 px.
  - Remove `_OrDivider` from this file if no longer used here (the block owns its divider).
- Modify: `app/lib/balsm_app/i18n/strings.i69n.jsonc`, `strings_ar.i69n.jsonc` (`onboarding.w_apple`, `onboarding.w_or_email`, update ar `w_google`; delete `w_or` if unused) → `cd app && fvm dart run build_runner build --delete-conflicting-outputs`
- Modify: `app/test/social_sign_in_test.dart` (rewrite header doc + cases for the new rules)

**Interfaces:**
- Consumes: `availableSocialProviders` (Task 5); `googleCredentialsPortProvider`, `appleCredentialsPortProvider`, `signInUseCaseProvider` (`signInWithGoogle({idToken, email, countryCode})`, `signInWithApple({idToken, authCode, email, countryCode})`), `enterAfterSignIn(context, ref, s)`, `s.setSocialName(...)`, `s.strings.auth.social_failed / social_unavailable / auth_locked_retry`.
- Produces: `class SocialSignInBlock extends ConsumerStatefulWidget { const SocialSignInBlock({super.key, required this.compact}); }` — renders nothing (`SizedBox.shrink`) when no provider is available; otherwise buttons (gap 10) → 14 px → divider labelled `w_or_email` → error line (live region, `AppColors.danger`) when set. Holds `SocialProvider? _busy`; while non-null both buttons get `onTap: null` and the busy one shows the spinner. Outcome handling is exactly today's `_signInGoogle` logic generalised per provider (cancel → silent; failure → `social_unavailable` if `missingToken` else `social_failed`; success → `setSocialName` when `isNewUser`, then `enterAfterSignIn`; lockout → `auth_locked_retry`). Apple passes `credentials.authorizationCode` as `authCode`.

- [ ] **Step 1: Write failing widget tests** in `app/test/social_sign_in_test.dart` (use `debugDefaultTargetPlatformOverride`, existing `_StubCredentials`/mocks):
  - `welcome_onIos_showsAppleAboveGoogleAboveCreateAccount` (compare `tester.getTopLeft` dy of the three labels)
  - `welcome_onIosWithoutIosClientId_showsAppleOnly`
  - `welcome_onAndroid_showsGoogleOnly`
  - `emailScreen_signIn_showsSocialBlock` / `emailScreen_deviceOnly_hidesSocialBlock`
  - `apple_success_newUser_sendsAuthCodeAndPrefillsName` (verify `signInWithApple(authCode: 'apple-code', …)`; `state` holds the given/family name)
  - `apple_cancelled_showsNoError`
  - `google_missingToken_showsUnavailable`
  - `whileAppleRuns_googleTapDoesNothing` (stub Apple with a `Completer`; tap Google; Google stub `calls == 0`)
- [ ] **Step 2: Run** `cd app && fvm flutter test test/social_sign_in_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement** the block, the screen edits, the strings + codegen.
- [ ] **Step 4: Run** `fvm flutter test test/social_sign_in_test.dart test/social_providers_test.dart` and `fvm flutter analyze` in `app/` and `modules/auth/` — Expected: PASS, 0 issues. Run root `test/` suites that reference the welcome screen (`grep -rl "WelcomeScreen\|w_google\|w_or" test app/test`) — PASS.
- [ ] **Step 5: Commit**

```bash
git add app/lib/balsm_app/screens app/lib/balsm_app/i18n app/test
git commit -m "Lay out Apple and Google sign-in per the Auth Flow design"
```

### Task 7: Turn it on — iOS capability, env, docs, changelog

**Files:**
- Modify: `app/ios/Runner/Runner.entitlements` — replace the "DISABLED" comment with `<key>com.apple.developer.applesignin</key><array><string>Default</string></array>`. Leave `Runner-Personal.entitlements` untouched.
- Modify: `app/ios/Runner/Info.plist` — keep the comment, reworded: the Google URL type is added with the real `REVERSED_CLIENT_ID` when `GOOGLE_IOS_CLIENT_ID` is filled in; until then the iOS Google button stays hidden (Task 5 rule). Do not add a placeholder scheme.
- Modify: `app/env/shared.json` and `app/env/shared.example.json` — `"SOCIAL_SIGN_IN_ENABLED": true`, both Google ids `""` (example keeps a comment-free `""` too).
- Modify: `app/lib/balsm_app/screens/auth_flow.dart` / `modules/auth/.../apple_credentials_adapter.dart` doc comments that still say the provider is off pending team ownership.
- Modify: `docs/social-sign-in-setup.md` — status **ENABLED**; re-enable section becomes "switching off" (`SOCIAL_SIGN_IN_ENABLED`, `SocialSignIn__Enabled=false`); add the Apple revocation keys (`Apple__TeamId`, `Apple__KeyId`, `Apple__PrivateKey` as Railway secrets) and that the refresh token is encrypted with a key derived from `DobEncryption:Key`; placeholders table: Google ids are `""`, not `REPLACE_ME`; fix the stale `social_sign_in_screen.dart` reference → `social_sign_in_block.dart`.
- Create: `changelog.d/<PR#>.added.md`: `Sign in with Apple on iPhone, and Sign in with Google on iPhone, Android and Mac, from the welcome and email screens ([#<PR#>](https://github.com/balsm-health/balsm_app/pull/<PR#>))` — use the PR number once the PR exists; if no PR yet, create the file at PR time.
- Modify: `../Balsm-Core/agents/rules/AGENTS.md` only if wording about social sign-in being off exists (grep `social`); otherwise none.

- [ ] **Step 1: Make the edits.**
- [ ] **Step 2: Verify** `plutil -lint app/ios/Runner/Runner.entitlements app/ios/Runner/Info.plist` → both `OK`; `grep -rn REPLACE_ME app/env app/ios/Runner` → no Google hits.
- [ ] **Step 3: Run** `cd app && fvm flutter analyze && fvm flutter test` — PASS.
- [ ] **Step 4: Commit**

```bash
git add app/ios/Runner/Runner.entitlements app/ios/Runner/Info.plist app/env/shared.example.json app/lib modules/auth/lib docs/social-sign-in-setup.md changelog.d
git commit -m "Turn on Sign in with Apple and Google"
```

(`app/env/shared.json` — check `git check-ignore app/env/shared.json`; stage it only if tracked.)

## After the plan (user, not the implementer)

- Apple Developer: enable Sign in with Apple on App ID `app.balsm.health`; create a Sign in with Apple key → Railway secrets `Apple__TeamId`, `Apple__KeyId`, `Apple__PrivateKey`.
- Google Cloud: Web, iOS, Android OAuth clients per `docs/social-sign-in-setup.md`; send the Web + iOS ids; add the iOS reversed id URL type.
- Railway: `SocialSignIn__Enabled=true`, `Google__ClientId=<web id>`.
