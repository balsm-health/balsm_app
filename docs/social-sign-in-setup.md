# Sign in with Google / Apple — console setup

> **Status: ENABLED.** `SOCIAL_SIGN_IN_ENABLED` is `true` in the app env and
> the Apple entitlement is in `Runner.entitlements`. The API gate is
> `SocialSignIn:Enabled`. With it on, the API refuses to boot if
> `Google:ClientId` or `Apple:ClientId` is missing.
>
> **Switching off** (e.g. to stop accruing users):
> 1. `SOCIAL_SIGN_IN_ENABLED: false` in `app/env/shared.json`; the buttons hide
>    in builds made after the change.
> 2. `SocialSignIn__Enabled=false` on the API (Railway). This stops **new**
>    accounts only: a `/auth/google` or `/auth/apple` sign-in from a subject
>    that has no Balsm account yet returns 404 (the app says sign-in is
>    unavailable and points to email). Users who already signed in with Apple
>    or Google keep signing in — for many it is their only way in, and builds
>    already installed still show the buttons. `/auth/apple/notifications`
>    keeps working, so an Apple user who withdraws consent is still signed
>    out. Leave `Google:ClientId` and `Apple:ClientId` set: without them the
>    existing users are refused too (404) and Apple notifications return 404.
>
> Leave the Apple entitlement in place: removing it only matters if the
> capability is removed from the App ID. An Apple account identifier is scoped
> to the developer team that owns the app, so transferring the app to another
> team changes it and every Apple user needs a migration through Apple.

The code is complete on both sides: `modules/auth` obtains the provider token
natively and posts it to `POST /auth/google` / `POST /auth/apple`, which
validates it (`GoogleOidcValidator` / `AppleOidcValidator` in
`Balsm-API-DotNet`) and mints a Balsm session. What is left is the one-time
console configuration that produces the identifiers both sides validate against.

Every value below is a **public** OAuth identifier, not a secret — client ids
are designed to be shipped inside apps. Nothing here belongs in a secret store.

**Scope:** Google on iOS, Android and macOS; Apple on iOS only. Provider
availability lives in `social_providers.dart`, and the buttons are
`social_sign_in_block.dart` (Welcome and email screens). The Apple button is
hidden off iOS because the Android web flow needs
a Service ID whose token audience differs from the bundle id the API validates.

## Values to fill in

| Setting | Lives in | Becomes |
|---|---|---|
| `GOOGLE_SERVER_CLIENT_ID` | `app/env/shared.json` | Google **Web** client id (`""` until set; Android and macOS hide Google while empty) |
| `GOOGLE_IOS_CLIENT_ID` | `app/env/shared.json` | Google **iOS** client id (`""` until set; the iOS Google button stays hidden while empty) |
| *(no entry today)* | `app/ios/Runner/Info.plist` | iOS **reversed** client id, added as a new URL type — see step 4 |
| `Google:ClientId` | API `appsettings.Development.json` / `.Local.json`, Railway `Google__ClientId` | Google **Web** client id |
| `Apple:ClientId` | API config | `app.balsm.health` (already correct) |

The placeholders are empty strings, not `REPLACE_ME`: a placeholder in a URL
scheme is rejected by App Store Connect (error 90158).

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
   reverses to `com.googleusercontent.apps.123-abc`. Add it as a second
   `CFBundleURLTypes` entry in `app/ios/Runner/Info.plist`:

   ```xml
   <dict>
     <key>CFBundleTypeRole</key><string>Editor</string>
     <key>CFBundleURLName</key><string>health.balsm.auth.google</string>
     <key>CFBundleURLSchemes</key>
     <array><string>com.googleusercontent.apps.123-abc</string></array>
   </dict>
   ```

   Add the iOS client's `REVERSED_CLIENT_ID` as a URL type only once the real id
   exists; a placeholder must never be committed (App Store Connect error 90158:
   `_` is not allowed in a URL scheme). Google's console
   shows it directly; a downloaded `GoogleService-Info.plist` has it as
   `REVERSED_CLIENT_ID`. The app does not need that plist file — the client ids
   come from `shared.json`.

## 2. Apple Developer portal

<https://developer.apple.com/account> → **Certificates, Identifiers & Profiles**.

1. **Identifiers** → App ID `app.balsm.health` → tick **Sign in with Apple** →
   *Save*. Leave it as a primary App ID (no grouping needed).
2. The entitlement `com.apple.developer.applesignin` is already in
   `app/ios/Runner/Runner.entitlements`. It signs only once step 1 is done: a
   build carrying it without the capability on the App ID fails provisioning.
   With automatic signing, Xcode regenerates the profile on the next build.
3. The API's `Apple:ClientId` is the **bundle id** `app.balsm.health`: for the
   native iOS flow, that is the `aud` claim Apple puts in the ID token.

**Personal-team signing.** `Runner-Personal.entitlements` deliberately omits the
capability, because free personal-team signing rejects it. Apple sign-in does
not work in personal-team builds (`scripts/ios_personal_signing.sh on`) — use a
paid-team build to test it.

Sign-in itself needs no Service ID, key, or client secret: the native flow
validates the ID token against Apple's public JWKS, which the API fetches and
caches. Account deletion does need a key, to revoke the user's Apple token (see
*Apple token revocation* in section 3).

**Server-to-server notifications.** In the portal, set the notification endpoint
for the App ID to `https://api.balsm.health/auth/apple/notifications`. Consent
revoked and account deleted sign the user out everywhere (unless the event is
older than the user's latest Apple sign-in); email disabled/enabled refresh the
stored email snapshot.

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
not required, existing Apple/Google identities still sign in, and a sign-in that
would create an account returns 404; a provider whose client id is missing also
returns 404, for everyone. The three endpoints share a rate limit per client IP
of 20 requests per 10 minutes, counted whatever the flag says.

Apple sign-in sends a per-attempt nonce: its SHA-256 goes to Apple and the raw
value to the API, which compares them. `/auth/apple` returns 401 without it.

### Before deploying and enabling

1. **Email collision check (before the deploy).** The migration
   `KeyEmailIdentitiesOnStableId` keys email identities on a canonical address
   (lowercase; Gmail dots and `+tag` dropped, `googlemail.com` folded into
   `gmail.com`) and **aborts the deploy** if two email identities share one.
   Run this read-only query against production first; it must return no rows:

   ```sql
   SELECT canonical, string_agg(id::text, ', ' ORDER BY id) AS identity_ids
   FROM (
       SELECT id, CASE
           WHEN position('@' IN lower(btrim(email_normalized))) = 0
               THEN lower(btrim(email_normalized))
           WHEN substr(lower(btrim(email_normalized)), position('@' IN lower(btrim(email_normalized))) + 1)
                IN ('gmail.com', 'googlemail.com')
               THEN replace(split_part(split_part(lower(btrim(email_normalized)), '@', 1), '+', 1), '.', '')
                    || '@gmail.com'
           ELSE lower(btrim(email_normalized))
       END AS canonical
       FROM public.user_identities
       WHERE provider = 'email' AND email_normalized IS NOT NULL
   ) c
   GROUP BY canonical
   HAVING count(*) > 1;
   ```

   Any row is two accounts on one mailbox: resolve them by hand (support
   decides which account keeps the address) before deploying.

2. **Proxy hop count (before enabling).** The social endpoints rate-limit per
   client IP (20 requests per 10 minutes), read from `X-Forwarded-For` by
   `UseForwardedHeaders` in `Program.cs`, which trusts one hop (the default
   `ForwardLimit = 1`). Confirm how many proxies append to `X-Forwarded-For`
   in production. Railway's edge alone is one hop, which is correct. Behind a
   CDN in front of Railway (Cloudflare, for example) there are two: set
   `ForwardLimit = 2`, or key the limit on `CF-Connecting-IP`; otherwise every
   user behind one CDN edge shares that edge's IP and its 20-request budget.

### Apple token revocation

At sign-in the API exchanges the Apple authorization code for a refresh token
and stores it encrypted (AES-256-GCM, with a key HKDF-SHA256-derived
from `DobEncryption:Key`, info `balsm/apple-refresh-token/v1`, so that key must be set and must not be rotated casually).
When an account is purged the token is revoked with Apple, which needs a Sign in
with Apple key from the portal (Keys → Sign in with Apple). Set these as Railway
**secrets**:

```
Apple__TeamId=<10-character team id>
Apple__KeyId=<key id>
Apple__PrivateKey=<contents of the .p8, PKCS8 PEM>
```

A revocation that fails (Apple unreachable, or these secrets missing:
`config_missing`) is recorded as `failed_retrying` on the deletion log, and the
account is kept, auth identities and stored token included, for the next nightly
purge. Five days past the deletion grace period the purge gives up: it records
`failed_final` and erases the account's auth identities, refresh tokens and
account anyway. So set these secrets before the first Apple user can reach the
end of a deletion grace period.

### Account linking

Email identities are keyed on a stable id, and Gmail dot and `+tag` variants are
treated as one address.

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
