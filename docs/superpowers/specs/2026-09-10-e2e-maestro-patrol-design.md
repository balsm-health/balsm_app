# E2E tests with Maestro and Patrol — design

**Date:** 2026-09-10
**Status:** Approved, not yet implemented
**Scope:** `balsm_app` only

## Goal

On-device end-to-end coverage of the patient app's full first-run path —
walkthrough → welcome → sign-in → disclosure gate → home shell — driven by two
tools with a clear division of labour and no backend dependency.

## Decisions

| Decision | Choice |
|---|---|
| Coverage depth | Full path to the home shell |
| Backend | Stubbed at the `Provider<XxxApi>` seam; no live API |
| CI | Local only for now; no workflow changes |
| Tool split | One stubbed build, two drivers (see below) |
| Platform staging | Maestro on iOS + Android now; Patrol on Android now, iOS deferred |

### Why Patrol's iOS setup is deferred

Patrol on iOS requires a `RunnerUITests` target inside `Runner.xcodeproj`.
Adding one is a GUI operation in Xcode; doing it by hand means editing
`project.pbxproj`, which fails in subtle ways. Android's side is ordinary Gradle
and carries no such risk. Maestro needs no native changes on either platform, so
iOS still has coverage from day one — just black-box rather than Dart-level.

### Why not one tool

Patrol alone loses cheap YAML screenshot flows and black-box verification of a
real installed build. Maestro alone cannot reach inside the app to force a
lockout, a 500, or assert on widget state — and the full path needs the stubbed
build regardless, so it would be most of the work for less of the result.

## Architecture

Three pieces, each independently useful.

### 1. `bootstrap()` — extracted from `main_balsm.dart`

`main_balsm.dart:main()` is 171 lines and already constructs a
`ProviderContainer(overrides: [...])` (line 61). That container is the seam.

Extract the body into:

```dart
Future<void> bootstrap({List<Override> extraOverrides = const []}) async { ... }
```

`extraOverrides` is appended **after** the existing overrides, so an e2e
override wins over the production binding for the same provider. `main_balsm.dart`
becomes `Future<void> main() => bootstrap();` — behaviourally identical, and the
only production-code change in this work.

### 2. Fake API layer — `packages/core/lib/src/test_kit/`

The repo already has this convention: `packages/core/lib/src/test_kit/fakes.dart`
holds `FakeEventBus`, `FakeSecureStorage`, `FakeBalsmApiController` and four
others, exported from `core.dart` under a dev-only comment, and the
`no_test_kit_in_release` custom-lint rule blocks any `test_kit` import when
`FLAVOR != dev`. New fakes follow that convention exactly — no new mechanism.

Add `packages/core/lib/src/test_kit/fake_apis.dart` covering the eight
interfaces registered in `network/api_providers.dart`:

| Interface | Methods |
|---|---|
| `AuthApi` | 11 |
| `AccountApi` | 6 |
| `SessionsApi` | 3 |
| `EmergencyQrApi` | 3 |
| `DeletionApi` | 2 |
| `DisclosureApi` | 1 |
| `GeofenceApi` | 1 |
| `CareDirectoryApi` | 1 |

28 methods total, most returning a small DTO. Each fake exposes knobs for the
states the tests need to force — `AccountLocked`, a network failure, an unknown
email — so a Patrol test can drive an error path without a server.

Seed data is a single synthetic account, fixed so tests are deterministic:
user id `00000000-0000-0000-0000-000000000001`, email `e2e@balsm.test`, country
`EG`, display name `E2E Tester`. Per `AGENTS.md` the fixture carries no health
data at all — the flows under test stop at the home shell, so none is needed,
and inventing plausible-looking PHI is exactly what the rule forbids.

Alongside it, `e2eOverrides` — the canonical list binding every
`Provider<XxxApi>` to its fake, so the entrypoint and the Patrol tests cannot
drift apart.

**Not stubbed:** the on-device drift/SQLCipher database and secure storage. Both
work on a real device or simulator, and the disclosure gate reading real
acceptance rows (`disclosureDaoProvider`) is exactly the behaviour under test.

### 3. `main_e2e.dart` — the build Maestro drives

```dart
Future<void> main() => bootstrap(extraOverrides: e2eOverrides);
```

Maestro is black-box and cannot inject anything, so it needs a binary that is
already stubbed. Patrol does not need this entrypoint — its tests call
`bootstrap(extraOverrides: [...e2eOverrides, ...perTestTweaks])` directly, which
is what lets a single test force one specific failure.

## Division of labour

**Patrol owns behaviour.** Branches and edge cases, native dialogs, anything
needing an assertion on state or a forced failure:

- new account → profile setup (the fail-closed DOB/age gate must not be skipped)
- returning account → disclosure gate → home shell
- account lockout surfaces the countdown and does not navigate
- a failed sign-in surfaces the error and stays put
- disclosure gate refused → no access to `app`
- native permission dialogs via `$.native`

**Maestro owns the happy path and the pixels.** Fast, readable, no code
coupling:

- walkthrough slides (already exists as `wt_flow.yaml`)
- welcome → sign-in → home, with screenshots at each step
- Arabic/RTL pass of the same flow

Rule of thumb for future tests: if it needs to reach inside the app, it is
Patrol. If it is "does the happy path still render", it is Maestro.

## Test inventory — first cut

| # | Tool | Flow |
|---|---|---|
| 1 | Maestro | walkthrough slides + screenshots (existing `wt_flow.yaml`, promoted) |
| 2 | Maestro | welcome → sign-in → disclosure → home, screenshots |
| 3 | Maestro | same flow in Arabic, RTL screenshots |
| 4 | Patrol | new account routes to profile setup and the age gate runs |
| 5 | Patrol | returning account reaches home through the disclosure gate |
| 6 | Patrol | lockout shows the countdown, no navigation |
| 7 | Patrol | sign-in failure shows the error, no navigation |
| 8 | Patrol | declining the disclosure never reaches `app` |

## Native and tooling setup

**Android (now).** `patrol` and `patrol_cli` dev dependencies; `PatrolJUnitRunner`
as `testInstrumentationRunner` in `app/android/app/build.gradle.kts`; the
generated test runner file. Android has **no product flavors** (single Balsm
build), so `patrol test` runs without `--flavor`.

**Patrol config** goes under a `patrol:` key in `app/pubspec.yaml` — app name,
Android package `app.balsm.health`, iOS bundle `app.balsm.health`.

**iOS (deferred).** Written up as explicit steps: add a `RunnerUITests` target
in Xcode, set its bundle id, add the Patrol test file. Ten minutes of GUI work,
after which the same Patrol tests run on iOS unchanged.

**Version:** `patrol` 4.9.0 is current (published August 2026).

## Commands

Existing `melos e2e` runs `flutter test integration_test`, which would pick up
Patrol test files and fail — Patrol has its own runner. So:

| Script | Runs |
|---|---|
| `melos e2e` | `flutter test integration_test/auth_ui_test.dart` — narrowed to the existing widget-level test |
| `melos e2e:patrol` | `patrol test` |
| `melos e2e:maestro` | `maestro test .maestro/` against an installed e2e build |

Patrol tests live in `app/integration_test/patrol/`, keeping them out of the
plain runner's path. `app/integration_test/auth_ui_test.dart` is untouched — it
passes, it is cheap, and it covers rendering that neither new suite duplicates.

## Constraints and non-goals

- **No CI wiring.** Chosen deliberately; the risk is a suite that rots unrun,
  and the mitigation is that adding an Android emulator job later is a
  self-contained follow-up.
- **No real backend coverage.** These tests prove the app's own behaviour, not
  the API contract. Contract coverage stays with `packages/balsm_api`'s tests
  and the .NET integration tests.
- **Patrol on iOS is not delivered here**, only documented.
- **No production behaviour changes** beyond the `bootstrap()` extraction.

## Risks

| Risk | Mitigation |
|---|---|
| The `bootstrap()` extraction changes real boot behaviour | It is a pure move; `main_balsm.dart` calls it with no overrides. The app's existing tests plus a manual launch confirm it. |
| Fakes drift from the real API contract | The fakes implement the same interfaces, so a signature change breaks the build rather than passing silently. |
| Full path proves brittle to drive | The path crosses profile setup's `showBalsmDatePicker`. If driving it fights the test more than it earns, the DOB step gets a seam rather than the suite being weakened. |
| Two suites duplicating coverage | The Patrol/Maestro rule above is the guard; new tests state which side they fall on. |

## Housekeeping

`app/.maestro/wt_flow.yaml` is currently untracked and gets committed as part of
this work.
