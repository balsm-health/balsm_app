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
