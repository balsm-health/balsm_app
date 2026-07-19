# CI/CD Pipeline — Design

**Date:** 2026-07-03
**Status:** Implemented (2026-07-03)
**Scope:** `balsm_app_flutter` (GitHub Actions)

## Goal

Lint + test + coverage gate on every PR/push, and tag-triggered channel
releases (alpha/beta/production) that distribute the Balsm patient app to
Firebase App Distribution (Android + iOS) and attach desktop/web/Android
artifacts to a GitHub Release.

## Two workflows

- **`ci.yml`** (extended) — PR + push to `main`: analyze (lint, error-gated),
  tests, and coverage → Codecov. Smoke builds (web/android/ios) stay.
- **`release.yml`** (new) — triggered on `v*` tags: derive channel, build the
  requested platforms, sign (if secrets present), distribute.

## Channel model — git tags

| Tag pattern | Channel | Env flavor file | Firebase group | GitHub Release |
|---|---|---|---|---|
| `v*-alpha` | alpha | `env/balsm/staging.json` | `alpha-testers` | prerelease |
| `v*-beta` | beta | `env/balsm/staging.json` | `beta-testers` | prerelease |
| `v*` (no suffix) | production | `env/balsm/prod.json` | `production` | full release |

- App: **balsm** patient flavor, entry `lib/brands/balsm/main_balsm.dart`. `balsm_pro` is
  out of scope.
- `build-name` = tag minus leading `v` and any `-alpha`/`-beta` suffix.
- `build-number` = `github.run_number` (monotonic; required by Firebase/stores).
- alpha + beta point at the **staging** backend (dev env targets a dev server
  external testers can't reach). Production points at prod.

## Build + distribution matrix

| Platform | Runner | Firebase | GitHub Release |
|---|---|---|---|
| Android APK | ubuntu | ✅ all channels | ✅ |
| iOS IPA | macos | ✅ | — |
| macOS (.zip) | macos | — | ✅ |
| Windows (.zip) | windows | — | ✅ |
| Linux (.tar.gz) | ubuntu | — | ✅ |
| Web (.zip) | ubuntu | — | ✅ |

Android is dual-distributed (Firebase + Release); iOS Firebase-only;
desktop/web Release-only.

**Desktop platforms are not scaffolded in the repo** (only `android/`, `ios/`,
`web/` exist). Each desktop job runs `flutter create --platforms=<os> .` on the
runner to generate a vanilla native shell before building — nothing half-baked
is committed. If custom desktop runners (icons, entitlements, MSIX/dmg
packaging) are later needed, `flutter create` them locally and commit.

## Signing + Firebase — scaffolded, guarded

Every signing/Firebase step runs **only if its secret is present**
(`if: ${{ secrets.X != '' }}` via a job-level `env` boolean). Missing secret →
step skips and an **unsigned** artifact is still built and uploaded, so the
pipeline is green and useful before credentials are wired.

Secrets (documented in `docs/ci-secrets.md`):

- **Android signing:** `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`,
  `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`. CI decodes the keystore and
  writes `app/android/key.properties`; gradle uses it when present, else the
  debug key.
- **iOS signing:** `APPLE_CERT_P12`, `APPLE_CERT_PASSWORD`,
  `APPLE_PROVISIONING_PROFILE`, `APPLE_TEAM_ID`, `IOS_EXPORT_METHOD`
  (default `ad-hoc`). Imported via `apple-actions/import-codesign-certs`.
- **Firebase:** `FIREBASE_SERVICE_ACCOUNT` (JSON), `FIREBASE_APP_ID_ANDROID`,
  `FIREBASE_APP_ID_IOS`.

## Android signing config change

`app/android/app/build.gradle.kts` reads `android/key.properties` if it exists
and uses that `signingConfig` for `release`; otherwise falls back to the debug
key (unchanged local/dev behavior). No secret in the repo.

## Coverage → Codecov

`ci.yml` gains a `coverage` job: pub get + drift codegen, then for each package
that has a `test/` dir run `flutter test --coverage` (and `dart test` +
`coverage:format_coverage` for the pure-Dart `balsm_api`). Rewrite each
`lcov.info` `SF:` path to be repo-root-relative, concatenate, upload once with
`codecov/codecov-action@v4` (`CODECOV_TOKEN`). `codecov.yml` sets project target
`auto` and patch target **informational** (non-blocking) to start — ratchet up
later. Codecov receives line-hit data (paths + counts), not source.

## Also fixed

- `ci.yml` `PKGS` gains `packages/balsm_api`; its 48 tests were absent from CI.
- The `test` job's coverage now exercises package tests, not just PHI-fuzz +
  i18n.

## Out of scope

`balsm_pro` app; Play/App Store store publishing (Firebase only for now);
on-device/e2e tests; changelog/release-notes automation.
