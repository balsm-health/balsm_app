# Enable Sign in with Apple + Google — design

Status: approved 2026-11-28
Repos: `balsm_app`, `../Balsm-API-DotNet`

## Intent

App ownership (Apple developer team) is settled, so the reason social sign-in
was held back is gone. Turn on Sign in with Apple and Google, laid out as the
Claude Design "Auth Flow" page (`auth.jsx` → `WelcomeScreen`, `PhoneScreen`,
`SocialButtons`, `OrDivider`).

## Goals

- iOS: Apple + Google. Android: Google. macOS: Google (unchanged).
- Welcome screen order per design: Apple (black) → Google (white, ink-200
  border) → "or with email" divider → Create account → Sign in → device-only.
- Email screen (sign-up + sign-in intents): same two buttons, compact (48px),
  then the "or with email" divider, above the email field. Hidden for the
  device-only intent.
- A new or known social account enters the app after the disclosure gate
  (`enterAfterSignIn`), name prefilled from the provider for a new account —
  unchanged from today. Correction 2026-11-28: the design's prose comment says
  "new account goes on to profile setup", but its code (`auth.jsx:91`) and the
  email sign-up path both go straight to `app`; profile setup left the
  registration flow in the 2026-09 design.
- API: `SocialSignIn:Enabled` gate (404 while off) and boot-time validation of
  `Google:ClientId` / `Apple:ClientId` when on — ported by hand from
  `feature/social-sign-in` (`8cb9743`), not merged (that branch is on old
  history).
- Apple token revocation on account deletion actually works: at Apple sign-in
  the API exchanges the authorization code for an Apple refresh token, stores
  it encrypted (same AES-256-GCM pattern as DOB), and `AppleRevokeService`
  revokes with it (`token_type_hint=refresh_token`).

- Accounts are linked to the sign-in id, never the email (added 2026-11-28
  at the user's request): Google/Apple by `sub`; email identities get a stable
  opaque subject so the address can change later. Gmail variants differing
  only by case, dots or `+tag` are one address
  (`hossamEldin.M.I@gmail.com` ≡ `hossameldinmi@gmail.com`). The stored
  provider email is a refreshable snapshot. No cross-provider merge by email.

- Hardening (added 2026-11-28): Apple sign-in carries a per-attempt nonce
  (app sends SHA-256 to Apple, raw value to the API, API compares);
  `/auth/google` + `/auth/apple` are rate limited per IP (20 / 10 min);
  `POST /auth/apple/notifications` handles Apple's server-to-server events —
  consent-revoked / account-delete sign the user out everywhere and drop the
  stored Apple token (the Balsm account itself is never auto-deleted);
  email-disabled / email-enabled refresh the email snapshot.

## Non-goals

- An email-change screen/endpoint (this work only makes it possible).
- Linking a Google/Apple sign-in to an existing email account.

- Apple on Android/web (needs a Service ID audience + server support).
- Google/Apple console setup — the user does it; ids stay `REPLACE_ME` until
  supplied. Placeholders must never ship in an iOS URL scheme (ASC error 90158).

## Anti-goals

- No PHI or provider tokens in logs/telemetry.
- Cancelling the provider sheet stays silent.

## Approaches considered

- **A (chosen):** enable both + real Apple refresh-token revocation. Meets App
  Store 5.1.1(v) account-deletion revocation requirement.
- **B:** enable now, revocation later. Faster, ships a known compliance gap.

## Decided

- Copy for buttons/divider comes from the design (en + ar).
- `com.apple.developer.applesignin` restored in `Runner.entitlements` only
  (never `Runner-Personal.entitlements`).

- Encrypted Apple refresh token lives on the Auth module's `UserIdentity`
  row; Deletion's purge revokes through a SharedKernel contract implemented by
  Auth and wired in `Program.cs` (same pattern as `IAccountFamilyLinkEraser`).
- Encryption key: derived from `DobEncryption:Key` via HKDF (info
  `balsm/apple-refresh-token/v1`) — no new secret, separate key per purpose.
- A failed code exchange never fails sign-in; revocation later records
  `no_refresh_token`. Missing Apple key config (TeamId/KeyId/PrivateKey) skips
  capture with a warning; it does not block boot.
- Client: Google on iOS only shows when `GOOGLE_IOS_CLIENT_ID` is non-empty
  (placeholders in `shared.json` become `""`), because its reversed id must be
  a real URL scheme in `Info.plist`.
