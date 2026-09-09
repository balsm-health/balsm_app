# Sign in with Google / Apple — console setup

> **Status: DISABLED.** Both buttons are hidden and both API endpoints return
> 404. An Apple account identifier is scoped to the developer team that owns the
> app, so transferring the app to another team changes it and every Apple user
> needs a migration through Apple to keep their account. Until app ownership is
> settled, not accruing those users is cheaper than migrating them.
>
> **To re-enable**, all three:
> 1. `SOCIAL_SIGN_IN_ENABLED: true` in `app/env/shared.json`
> 2. `SocialSignIn:Enabled = true` in the API config (or `SocialSignIn__Enabled=true`)
> 3. Restore `com.apple.developer.applesignin` in `app/ios/Runner/Runner.entitlements`
>    — the snippet is in a comment there. Only after enabling the capability on
>    the App ID, or the build fails to sign.
>
> Then fill in the credentials below. The API refuses to boot with the flag on
> and the client ids missing.

The code is complete on both sides: `modules/auth` obtains the provider token
natively and posts it to `POST /auth/google` / `POST /auth/apple`, which
validates it (`GoogleOidcValidator` / `AppleOidcValidator` in
`Balsm-API-DotNet`) and mints a Balsm session. What is left is the one-time
console configuration that produces the identifiers both sides validate against.

Every value below is a **public** OAuth identifier, not a secret — client ids
are designed to be shipped inside apps. Nothing here belongs in a secret store.

**Scope:** Google on iOS + Android; Apple on iOS only. The Apple button is
hidden off iOS (`social_sign_in_screen.dart`) because the Android web flow needs
a Service ID whose token audience differs from the bundle id the API validates.

## Placeholders to replace

| Placeholder | Lives in | Becomes |
|---|---|---|
| `GOOGLE_SERVER_CLIENT_ID` | `app/env/shared.json` | Google **Web** client id |
| `GOOGLE_IOS_CLIENT_ID` | `app/env/shared.json` | Google **iOS** client id |
| `com.googleusercontent.apps.REPLACE_ME` | `app/ios/Runner/Info.plist` | iOS **reversed** client id |
| `Google:ClientId` | API `appsettings.Development.json` / `.Local.json` | Google **Web** client id |
| `Apple:ClientId` | API `appsettings.Development.json` / `.Local.json` | `app.balsm.health` (already correct) |

Search for `REPLACE_ME` to find them all.

## 1. Google Cloud console

<https://console.cloud.google.com> → create or select the Balsm project.

1. **APIs & Services → OAuth consent screen**
   - User type **External**, publish when ready.
   - Scopes: `openid`, `email`, `profile` — nothing else. (Drive backup adds
     `drive.appdata` separately; see *Interaction with Drive backup* below.)
   - While the app is unverified, add every tester under **Test users** or their
     sign-in fails with `access_denied`.

2. **Credentials → Create credentials → OAuth client ID**, three times:

   | Type | Input | Where the output goes |
   |---|---|---|
   | **Web application** | no redirect URIs needed | `GOOGLE_SERVER_CLIENT_ID` **and** the API's `Google:ClientId` |
   | **iOS** | bundle id `app.balsm.health` | `GOOGLE_IOS_CLIENT_ID`, and its *reversed* form into `Info.plist` |
   | **Android** | package name `app.balsm.health` + SHA-1 (below) | nothing to paste — Google matches it by signature at runtime |

   The Web client is the one that matters most: the app passes it to the Google
   SDK as `serverClientId`, so **every** platform mints an ID token whose `aud`
   is the web client id. That is why the API validates a single audience, and
   why Android returns a null `idToken` when it is missing.

3. **Android SHA-1 fingerprints.** Get them with:

   ```bash
   cd app/android && ./gradlew signingReport
   ```

   Register **each** of these on the Android OAuth client:
   - the **debug** keystore SHA-1 (local development builds),
   - the **upload** key SHA-1 (Play internal testing),
   - the **Google Play app signing** SHA-1, from Play Console → *Release →
     Setup → App signing*. This one is easy to miss: when Play re-signs your
     build, the installed app carries Play's signature, not your upload key's,
     and sign-in fails in production while working in internal testing.

4. **iOS reversed client id.** The iOS client id `123-abc.apps.googleusercontent.com`
   reverses to `com.googleusercontent.apps.123-abc`. Put that in the second
   `CFBundleURLTypes` entry in `app/ios/Runner/Info.plist`. Google's console
   shows it directly; a downloaded `GoogleService-Info.plist` has it as
   `REVERSED_CLIENT_ID`. The app does not need that plist file — the client ids
   come from `shared.json`.

## 2. Apple Developer portal

<https://developer.apple.com/account> → **Certificates, Identifiers & Profiles**.

1. **Identifiers** → App ID `app.balsm.health` → tick **Sign in with Apple** →
   *Save*. Leave it as a primary App ID (no grouping needed).
2. Restore the entitlement in `app/ios/Runner/Runner.entitlements` — it was
   removed while the feature is disabled, and the exact snippet is in a comment
   in that file. Do this only *after* step 1: a build carrying the entitlement
   without the capability on the App ID fails provisioning. With automatic
   signing, Xcode regenerates the profile on the next build.
3. The API's `Apple:ClientId` is the **bundle id** `app.balsm.health`: for the
   native iOS flow, that is the `aud` claim Apple puts in the ID token.

**Personal-team signing.** `Runner-Personal.entitlements` deliberately omits the
capability, because free personal-team signing rejects it. Apple sign-in does
not work in personal-team builds (`scripts/ios_personal_signing.sh on`) — use a
paid-team build to test it.

No Service ID, key, or client secret is required: the native flow validates the
ID token against Apple's public JWKS, which the API already fetches and caches.

## 3. API configuration

Local and Development read the two ids from `appsettings`. Staging and
Production supply them as environment variables:

```
Google__ClientId=<web client id>.apps.googleusercontent.com
Apple__ClientId=app.balsm.health
```

With `SocialSignIn:Enabled=true`, `AddSharedInfrastructure` throws at startup
when either is missing, so a misconfigured deployment fails to boot instead of
500-ing on the first user's sign-in tap. While the flag is off the audiences are
not required and the endpoints 404.

## 4. Verify

1. `Google:ClientId` on the API and `GOOGLE_SERVER_CLIENT_ID` in the app are the
   **same** string. A mismatch surfaces as `Google ID token validation failed`
   in the API log and a generic failure in the app.
2. Android: tap Continue with Google. Reaching the account chooser but landing
   on "Could not get a Google sign-in token" means `serverClientId` is unset or
   the SHA-1 is not registered.
3. iOS: the Google flow opens `SFSafariViewController` and returns via the
   reversed-client-id URL scheme. A "safari cannot open the page" style failure
   means the `Info.plist` scheme does not match the iOS client id.
4. First-ever sign-in returns `is_new_user: true` and creates the account under
   the country the app sent — check `user_accounts.country_code` matches the
   country chosen in onboarding.

## Interaction with Drive backup

`packages/core/lib/src/backup/drive_backup_adapter.dart` builds its own
`GoogleSignIn` (for the `drive.appdata` scope) with no client ids, and
`docs/google-drive-backup-setup.md` still names an older bundle id
(`health.balsm.app`; the app is `app.balsm.health`). Both are pre-existing and
untouched here, but the two call sites share one native Google session — when
Drive backup is picked up, they should be configured from the same
`FlavorConfig` values rather than separately.
