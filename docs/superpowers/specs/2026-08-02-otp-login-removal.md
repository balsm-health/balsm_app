# Client: OTP email for registration + reset only (drop email-OTP login)

- **Date:** 2026-08-02
- **Repo:** `balsm_app` (mirrors the Balsm-API-DotNet Auth change)
- **API source of truth:** `Balsm-API-DotNet/docs/superpowers/specs/2026-08-02-otp-registration-only-design.md`

## Why

Email-OTP was the passwordless login path, so every login spent a Resend email.
With a limited email quota, OTP emails are now sent only for **registration** and
**password reset**. Returning users sign in with a password or Google/Apple.

## Client changes

- **`packages/balsm_api`** — `RequestOtpRequest` carries a required
  `OtpPurpose { register, reset }`; `toJson` emits `"purpose"`. The wire value is
  the enum `.name` (`register` / `reset`), which the API parses case-insensitively.
- **`modules/auth`** — `BalsmAuthAdapter.requestOtp` takes the purpose.
  `SignUpUseCase.requestEmailOtp` sends `register`; `SignInUseCase.requestEmailOtp`
  (forgot-password) sends `reset`. Use-case public signatures are unchanged, so the
  unwired legacy presentation screens still compile.
- **`app` (`auth_flow.dart`)** — the sign-in email screen drops the "use code"
  sub-mode (email sign-in is password-only). The "forgot password" link stays and
  is the recovery path for passwordless users: reset emails a code → they set a
  password → sign in with it. Sign-up keeps the code-vs-also-set-a-password choice.

## Behavioural contract (from the API)

- `POST /auth/otp/request` requires `purpose`. `register` on a known email →
  `409 EmailAlreadyRegistered`; `reset` on an unknown email → `200` with no email.
- `POST /auth/otp/verify` / `verify-link` complete registration only; an existing
  identity → `409 AccountAlreadyExists`.

## Tests

`dio_auth_api_test` asserts the request body carries `purpose`; the `sign_up` /
`sign_in` use-case tests assert the correct purpose is forwarded.
