# balsm CLI

`bin/balsm` (macOS/Linux) and `bin\balsm.cmd` (Windows) are the committed
entry points for `tool/build.dart` — the single source of truth for every
build/run/test command across brands, environments, and platforms. Melos
scripts, VS Code tasks, CI workflows, and your shell all invoke the same
typed, validated wiring; flavor names, entrypoints and `--dart-define` files
can never drift between them.

The wrapper uses **fvm** when the machine has it (honours `.fvmrc`) and falls
back to plain `dart` (CI runners get their SDK from `subosito/flutter-action`).

## Setup

Works from the repo with no setup: `./bin/balsm -h`. For any-cwd use, alias it:

```sh
alias balsm=/path/to/balsm_app/bin/balsm     # ~/.zshrc
```

## Synopsis

```
balsm <action> [brand] [env] [options] [-- extra flutter args]
```

| Part | Values | Default |
|---|---|---|
| `action` | `run` · `test` · `integration` · `gen` · `install` · `build` · or an artifact key directly | — |
| `brand` | `balsm` (see `tool/build_config.dart`) | `balsm` |
| `env` | `dev` · `staging` · `prod` | `dev` |

### Artifacts

`apk` · `aab` · `ipa` (ad-hoc) · `ipa-appstore` · `ipa-archive` · `web` ·
`macos` · `windows` · `linux`

`balsm apk balsm prod` and `balsm build balsm prod --artifact=apk` are the
same command; the second form exists so one VS Code task can drive everything
from a picker.

### Options

| Option | Meaning |
|---|---|
| `--artifact=<key>` | what `build` / `install` operates on |
| `--export=adhoc\|appstore\|none` | iOS signing profile (overrides the artifact's default) |
| `--servers=shared\|shared.tunnel` | which server list (`app/env/<name>.json`) gets compiled in; `shared.tunnel` adds devtunnel/LAN presets |
| `--device=<id>` | skip the device picker |
| `--obfuscate=on\|off` | hide Dart names in the binary; on by default for `staging` and `prod`, off for `dev`, never for web |
| `--allow-insecure` | build `prod` even though a release check failed (see below) |
| `--no-apk` | with `aab … prod`, skip the APK that is built alongside (see below) |

Anything after `--` passes through to `flutter` untouched.

## What each action does

- **`run`** — `flutter run` with the brand's flavor, entrypoint and env files
  wired in. `balsm run balsm dev --device=<id>`.
- **`test`** — test suites across the workspace.
- **`integration`** — integration/Patrol suites.
- **`gen`** — `build_runner` in every package that depends on it, skipping the
  rest (i69n bundles, drift, json). Same thing `melos run gen` calls.
- **`<artifact>` / `build`** — builds, then **collects** the artifact to
  `output/<brand>/<platform>/<brand>-<version>-<env>.<ext>` so the thing you
  just built is findable without digging through `build/`.
- **`install`** — pushes a previously collected artifact to a device:
  `balsm install balsm dev --artifact=ipa` (installable: `apk`, `ipa`).

## A production bundle comes with an APK

`balsm aab balsm prod` produces two files:

```
output/<brand>/android/<brand>-<version>-prod.aab   upload to Play
output/<brand>/android/<brand>-<version>-prod.apk   install on a phone
```

An app bundle cannot be installed; it is what Play takes. The APK is the same
build — same code, same flags, same signing key — for handing to a phone
directly. `--no-apk` skips it.

The APK is signed with the **upload** key. Play re-signs what it distributes
with its own app-signing key, so a phone that installed the APK cannot later
update to the Play version: Android refuses the mismatched signature, and the
app has to be uninstalled first. Uninstalling deletes the health data, which
lives only on the device and is not backed up. Use the APK for testers and
demos, not for patients who will move to the store version.

## Obfuscated builds and their symbols

Staging and prod builds of the phone and desktop apps are obfuscated: class,
method and field names in the compiled Dart are replaced with meaningless
ones, so the binary gives away far less about how the app works. Android
release builds also have their Java/Kotlin side renamed and shrunk by R8,
which Flutter does by default.

Obfuscation hides names. It does not encrypt the app, and it does not protect
anything stored in it: no secret belongs in a build, obfuscated or not.

An obfuscated build also writes the files that undo it:

```
output/<brand>/symbols/<brand>-<version>-<env>-<platform>/
  dart/                  split debug info, one file per CPU architecture
  android-mapping.txt    R8's map (Android only)
```

- **Keep them, per build.** A crash from an obfuscated build is unreadable
  without the set that was written by that exact build. Store each release's
  folder somewhere durable; `output/` is git-ignored and local.
- **Never ship or commit them.** They turn the obfuscation back into names.
- **Reading a stack trace:**
  `flutter symbolize -i <stack.txt> -d output/…/dart/app.android-arm64.symbols`
- **Sentry** shows obfuscated Dart frames until these files are uploaded to it
  (`sentry-cli debug-files upload`). That upload is not wired yet, and CI
  builds do not keep their symbols, so a build made in CI has no way to have
  its crashes read. Build releases locally, or wire the upload first.
- Error *types* sent to product analytics (`error.runtimeType`) are obfuscated
  names in these builds.

`--obfuscate=off` builds a staging or prod artifact without it, for chasing a
crash that only happens in release.

## Release checks on production builds

A `prod` build is checked before it starts. Something certainly wrong for a
store release stops the build; `--allow-insecure` builds anyway and says what
it ignored.

| Check | Result |
|---|---|
| `aab` with no `app/android/key.properties` (would be signed with the debug key) | stops |
| No server named `Production` in `ENVS`, or it is not `https://` | stops |
| A define still set to a `REPLACE_ME` placeholder (sign-in ids only count when `SOCIAL_SIGN_IN_ENABLED` is true) | stops |
| The server-list file is not valid JSON | stops |
| `apk` with no `key.properties` | warning |
| `--obfuscate=off` | warning |
| No `SENTRY_DSN` | warning |

Also built into every Android build, in the manifest rather than the tool:
no plain HTTP, only Android's own certificate authorities trusted
(`res/xml/network_security_config.xml`), and no backup or device-to-device
transfer of app data (`res/xml/data_extraction_rules.xml`).

## Requirements

`app/env/shared.json` must exist (git-ignored, per-developer):

```sh
cp app/env/shared.example.json app/env/shared.json
```

The CLI refuses to build without it. CI provisions it from the template in
each workflow (see `docs/ci-secrets.md` for the release-build variant).

## Examples

```sh
balsm run balsm dev                       # run on default device, dev servers
balsm apk balsm prod                      # release APK → output/balsm/android/
balsm ipa balsm dev                       # ad-hoc IPA → output/balsm/ios/
balsm ipa balsm dev --servers=shared.tunnel   # against a machine on the desk
balsm build balsm dev --artifact=macos
balsm install balsm dev --artifact=ipa    # push the collected IPA to a device
balsm gen                                 # codegen everywhere
```
