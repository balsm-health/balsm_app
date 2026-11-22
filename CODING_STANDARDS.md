# balsm_app — Coding Standards

> Extends the shared standards in
> [Balsm-Core/agents/rules/CODING_STANDARDS.md](../Balsm-Core/agents/rules/CODING_STANDARDS.md).
> Shared principles (error handling, SOLID, logging, validation, DTOs,
> idempotency, caching) apply as written there; this file adds the
> Dart/Flutter specifics. PHI invariants live in [CLAUDE.md](./CLAUDE.md).

---

## 1. Naming Conventions

- widgets: `{Feature}{Purpose}Widget` (e.g., `PatientProfileCard`)
- screens/pages: `{Feature}Screen` (e.g., `AppointmentDetailScreen`)
- models: `{Entity}Model`; services: `{Feature}Service`
- file names: `snake_case.dart` always
- **Names say what a thing is, to someone who has not read the file.**
  - No cryptic abbreviations or initials for a public class (`FS`, `PCard`, `Bp`, `LIcon`): `FontSizes`, `AppCard`,
    `Breakpoints`. A short local variable inside one method is fine; a public name is read everywhere.
  - **Scales are ordered and read in one direction.** Never put the multiplier after the size (`xs2` is smaller than `xs`
    but `xl2` is larger than `xl`). Use `xxs, xs, sm, md, lg, xl, xxl`, or name each step for its role (`FontSizes.body`).
  - A class is named for its single responsibility; a name like `Tokens`, `Utils`, `Helpers`, `Common` or `Kit` means it
    holds unrelated things — split it.
  - **A file is named after the main thing it declares** (`patient_app_state.dart` for `PatientAppState`). Never a generic
    name (`kit.dart`, `shell.dart`, `utils.dart`, `helpers.dart`, `common.dart`) and never a catch-all suffix
    (`*_kit.dart`, `*_shared.dart`, `*_widgets.dart`). One public widget per file; a small family of tightly coupled
    widgets takes the name of its main member.
  - No design-iteration words in names (`v2`, `new`, `old`, `legacy`).
- **static const identifiers: `snake_case`** — named const instances, const collections, and static const config values use `snake_case` (e.g. `CountryCode.saudi_arabia`, `Assets.brand_icon`, `ApiRoutes.account_self`), NOT `lowerCamelCase`. Add `// ignore_for_file: constant_identifier_names` at the top of the file. Enum *values* stay `lowerCamelCase` (Dart requires it).

## 2. Dart Style

- **list building: `.map()` over collection-`for`** — transforms into list elements use `.map(...)` (spread `...xs.map(...)`, or `.map(...).toList()`), `.where(...).map(...)` for filtered transforms, `.indexed.map((e) => ...)` when the index is needed (`e.$1` index, `e.$2` item). Collection-`for` stays ONLY where `.map` cannot express the loop without changing semantics or readability: sequential `await` bodies, `sync*`/`async*` generators, numeric ranges with no backing list, early `break`/`continue`/`return`, multi-collection accumulation, buffer mutation, map/set literals (`{for (...) k: v}`), and record-pattern destructuring that named bindings make clearer. (2026-07-24 directive; repo-wide sweep applied.)
- **domain state holds value objects, not raw strings** — state fields use the typed value object (`LanguageCode lang`, `CountryCode country`), derive booleans from it (`lang.isRtl`, `country == kHomeCountry`), and parse untrusted/stored input at the boundary via named factories: `fromCode` (throws on malformed) / `tryFromCode` or `tryParseUi` (null → caller falls back to a domain constant). Unnamed value-object factories are not used.
- never `async void`; event handlers are the only exception
- immutable DTOs/aggregates — `freezed` or hand-written `const` classes with `props`

## 3. Project Structure (melos monorepo)

- `packages/core/` — shared kernel: value objects, data-source contracts, auth context, db (drift `AppDatabase`), localization, kit, telemetry, backup
- `modules/{context}/` — one Dart package per bounded context, named after the context (NO `feature_` prefix; DDD per 2026-06-15 directives), layered:
  - `lib/src/domain/` — aggregates, entities, value objects, events
  - `lib/src/application/` — use cases + `ports/` (abstract persistence/service contracts; no storage tech in name or imports)
  - `lib/src/infrastructure/` — drift/API implementations (`Drift{X}DataSource` etc.), bound to ports via riverpod providers
  - `lib/src/presentation/` — screens, widgets, providers
- `app/` — the runnable shell (brands, balsm_app prototype port)
- modules never import other modules — cross-module reads go through core contracts/ports
- PHI persistence implements core's scoped data-source contracts (`ProfileDataSource` partitioned by `health_profile_id`, `UserDataSource` by account); domain/application layers depend on the module port, never on `Drift*` concretes

## 4. Localization

- all user-visible strings live in i69n bundles — `.i69n.jsonc` (JSON **with comments**: annotate keys, gender rules, RTL notes inline) in `app/lib/balsm_app/i18n/`, `packages/core/lib/src/localization/i18n/`, and `modules/*/lib/src/i18n/`; regenerate with `dart run tool/build.dart gen` after editing
- no inline bilingual ternaries (`ar ? '…' : '…'`)
- **gendered Arabic**: Arabic addresses women and men with different forms (اختر / اختاري, متعب / متعبة, تشعر / تشعرين). Any message that speaks to, or describes, the signed-in patient takes `Gender gender` (from `core`) and is called with `s.gender`; the English key declares the same parameter and ignores it. Select **only the part that changes**, never the whole sentence:
  - a feminine suffix: `"حاول${_select(gender, female: 'ي', other: '')} مرة أخرى"`, `"متعب${_select(gender, female: 'ة', other: '')}"`
  - a word that changes shape: `"${_select(gender, female: 'أضيفي', other: 'أضف')} دواءً"`
  - always write both `female:` and `other:`; `male` and unknown fall to `other`, which is the masculine
  - leave fixed: copy shown before sign-in (the gender is not known yet), copy addressed to someone else (a pharmacist, a responder), and words spelt the same in both forms without vowel marks (بياناتك، يمكنك)
  - never hard-code one gender in a message that addresses the patient — the check-in copy once read feminine to every man
- **Arabic counts use `_plural`**: Arabic has distinct forms for one, two, 3–10 and 11+ (سجل واحد / سجلين / 3 سجلات / 11 سجلًا). Any message that shows a count declares `int n` and selects with `${_plural(n, one:…, two:…, few:…, many:…, other:…)}` — see `rec_count`, `med_count`. Never build `'$n ' + noun`. For plain informational displays, the invariant label-and-number pattern (`عدد السجلات: 12`) is fine
- reference data (countries, languages) comes from core value objects + `CountryRegistry` — no private lists in screens
- **where a string goes**: copy owned by one module goes in that module's bundle and is read in presentation with
  `ref.watch(<module>StringsProvider)` (`ref.read` inside callbacks); a widget that needs it becomes a `ConsumerWidget`.
  Infrastructure and domain read `<module>Strings.current`. The shared words (Cancel, Retry, Done, Close, Save, …) live
  once in core's `common.*` and are read with `coreMessagesOf(context).common`; do not redeclare them in a module.
  Month and weekday names come from a bundle (`settings.cal_months*`, core `calendar_*`), never a list in code
- **one message per sentence**: a sentence with a value in it is one parameterized key (`revokeBody(String device)`),
  never pieces joined in code, because Arabic word order and plural forms differ from English
- **not translated**: brand and vendor names (Balsm, LinkedIn), file-type badges (PDF), version labels, `@handles`,
  format placeholders (`XXXXX-XXXXX-…`), developer-only panels, and literals that match stored historical data
- **digits typed on an Arabic or Persian keyboard** are folded with core's `toWesternDigits`; do not write another converter
- prefer typed `s.strings.key` over stringly `s.t('key')`; `t()` only for keys computed at runtime

## 5. Tooling

- Flutter runs via **fvm**: `fvm flutter …`, `fvm dart …` (version pinned in `.fvmrc`)
- tests per package (`fvm flutter test` in `packages/core` etc.); analyze before committing
- **code generation**: `dart run tool/build.dart gen` (also `melos run gen`, or the "Flutter: code generation" VS Code task) — runs `build_runner` across every package that depends on it (i69n bundles, drift, json/freezed) and skips the rest; add `--watch` for continuous rebuilds. Regenerate after editing any `*.i69n.json`, drift table, or annotated model.

### No machine-specific paths

Nothing committed may contain an absolute path into somebody's checkout — one
that starts at a mount point, a user home (`$HOME`, or the Windows equivalent),
or a hard-coded workspace root. A checkout location is one developer's
accident, not a fact about the repo: the path is wrong in every other clone and
on CI, and it publishes the author's directory layout. This applies to docs and
plans as much as to code and scripts — a runbook nobody else can paste is not a
runbook.

Write instead:

| Instead of | Use |
|---|---|
| `cd <abs-path-to-this-repo>` | `cd "$(git rev-parse --show-toplevel)"`, or document commands as run from the repo root |
| `<abs-path-to-this-repo>/app/lib/...` | `app/lib/...` (repo-relative) |
| `<abs-path-to-workspace>/Balsm-Core` | `../Balsm-Core` (sibling repo in the workspace) |
| `<abs-path-to-workspace>` | "the workspace root", the parent of this repo |

Sometimes an absolute path **is** the subject: a test asserting that a path is
redacted, a mounted installer volume after `hdiutil attach`, an illustrative
CLI transcript. Put `machine-path-ok` on that line and both checks skip it. Use
it for those cases only — not to land a real checkout path.

Enforced twice: `.githooks/pre-commit` scans added lines and blocks the commit
(enable once per clone with `git config core.hooksPath .githooks`), and the
`hygiene` CI job greps the whole tracked tree, which is what catches a
`--no-verify` or a clone that never enabled the hook. Both write their patterns
with character classes so neither file matches itself — otherwise they would
need exemptions, and exemptions are what let 146 bad paths hide in
`.claude/agents/**` on the first pass. The only exclusions left are the
vendored `*/skills/**` trees, which are installed third-party content.

### What CI rebuilds on a pull request

Analyze, tests, coverage and the web, Android and iOS builds run only when a
push changes something they depend on since the last green CI run on the pull
request. The **Build needed?** job decides (`.github/scripts/ci-needs-build.sh`).
A push of docs, `*.md`, editor or agent config, another workflow file, or only a
pubspec `version:` line skips them, and the pull request keeps its last green status.

## 6. Flutter Performance

- `const` constructors wherever possible
- `ListView.builder` for long lists — never materialize all children
- `RepaintBoundary` around frequently repainting widgets
- cache network images with explicit policies
- minimize widget tree depth
- `compute()`/isolates for CPU-intensive work — never block the UI thread
- profile with DevTools before/after; measure frame render times
- lazy-load screens and heavy widgets

## 7. State Management (Riverpod)

- **Riverpod is the only state-management system.** Every piece of shared or
  data-bearing state lives behind a provider: `Provider` for services,
  `FutureProvider`/`StreamProvider` for reads, `Notifier`/`AsyncNotifier` for
  mutable state. No new `InheritedWidget`s, no new `ChangeNotifier`
  singletons, no other packages.
- **`ChangeNotifierProvider` is a migration bridge only** — sanctioned for
  `patientAppStateProvider` (the app shell) and the dev `logBufferProvider`
  while they migrate to immutable `Notifier` state. Do not add new
  ChangeNotifiers behind it.
- `AppScope.of(context)` is the context-based view binding onto the
  Riverpod-owned `PatientAppState` — it subscribes exactly like
  `ref.watch(patientAppStateProvider)`. New code that already has a `ref`
  uses the provider directly.
- **`setState` is for ephemeral view-local state only**: text-field/focus
  state, open/closed toggles, in-flight flags for a button the same build
  displays, animation plumbing. The moment state is read by another widget,
  survives the route, or mirrors data — it belongs in a provider.
  - **Anything an `await` delivers is not view-local.** A picker result, an API
    response, a database read or a stream event goes into a provider
    (`Notifier`/`AsyncNotifier`) and the widget watches it; never `setState`
    from the continuation. If a `setState` does follow an `await` (a button's
    in-flight flag), guard it with `if (!mounted) return;` first — the widget may
    be gone (sheet dismissed, route popped). The monkey e2e (scenario 7 in
    `design_port_e2e_test.dart`) reports `setState() called after dispose()`.
  - **Form drafts that feed a save** (vitals pad digits, record fields) live in
    one `Notifier` per form, not in ten `setState` fields, so the save, the
    validity check and the tests read the same state.
  - **New code does not add `setState` outside those cases.** The existing
    backlog (about 500 calls) is migrated feature by feature, not in one sweep.
- Providers holding decrypted PHI are `autoDispose` so plaintext leaves
  memory with the last listener (see `vaultBlobProvider`).
- **Riverpod 3** (`flutter_riverpod ^3.4`):
  - `StateProvider`, `StateNotifierProvider` and `ChangeNotifierProvider` are legacy and need
    `import 'package:flutter_riverpod/legacy.dart';`. Do not add new ones; write a `Notifier` instead. The ones
    left (`patientAppStateProvider`, `logBufferProvider`, the consent notifiers, `SyncStatusNotifier`, the
    map-pack download controller, three small `StateProvider`s) are migration debt.
  - Every `ProviderScope` / `ProviderContainer`, tests included, passes `retry: noProviderRetry` (core): a failed
    provider shows its error at once instead of Riverpod 3's automatic ten retries. A provider that should retry
    passes its own `retry:`.
  - After every `await` in a `Notifier`/`AsyncNotifier` method, check `if (!ref.mounted) return …;` before touching
    `state` or `ref`: Riverpod 3 throws when a disposed notifier is used, which an auto-dispose screen leaving
    mid-request does.
  - Read `AsyncValue.value` (nullable on loading and error); `valueOrNull` is gone. A failed provider read
    through `.future` or `requireValue` throws `ProviderException`; inspect `e.exception`.
  - Widgets off screen (`TickerMode` disabled, e.g. a hidden tab) pause their providers. A listener that must keep
    running while hidden belongs in a provider, not in a widget's `ref.listen`.

## 8. Feature Flags

- **A feature that may need turning off without a release goes behind a
  flag**: anything that sends patient data off the device, anything rolled out
  gradually, anything marked beta. See `docs/feature-flags.md`.
- **Declare it once** as a `const FeatureFlag` in
  `app/lib/balsm_app/flags.dart`, add it to `AppFlags.all`, and read it with
  `flags.isOn(AppFlags.yours)`. Never test a flag by its string key.
- **Keys** are lowercase letters, digits and underscores (`sync_care`), the
  set every flag tool accepts.
- **The fallback is the safe value** for a device that has never been online
  and for a patient who opted out of analytics. Anything that moves data off
  the device falls back to off.
- **No vendor SDK outside its adapter.** A flag tool is a
  `FeatureFlagSource` in `packages/core/lib/src/flags/`, registered in the
  bootstrap; `app/test/architecture_test.dart` enforces it.
- **A flag does not replace the patient's own setting.** Where both exist
  (care-team sync), the feature runs only with the flag on and the patient's
  switch on.

## 9. Versioning and the Changelog

These apply to every change, whoever or whatever writes it. An AI agent
writes the changelog note itself, in the same change, without being asked,
and never raises the version.

### The version

`version:` in `app/pubspec.yaml` is `MAJOR.MINOR.PATCH+BUILD`, and it is the
only version in the repo: the packages under `packages/` and `modules/` ship
inside the app, never on their own, so they carry none.

**Pull requests never change it.** It rises when the team sends a build to
testers: the Promote workflow (alpha) collects the changelog notes, raises the
version by the largest change among them, and commits both to the branch
before tagging. One release takes one raise, however many pull requests it
holds.

| The change | Its note | Raise | Example |
|---|---|---|---|
| Bug fix, hotfix, security fix, copy or visual correction, refactor a patient notices, dependency bump | `fixed`, `changed`, `security`, `removed` | PATCH | `0.1.0` → `0.1.1` |
| New feature, or new behaviour a patient can notice | `added`, or `.minor` on another group | MINOR, PATCH back to 0 | `0.1.1` → `0.2.0` |
| Breaking: data that cannot be read by the previous version, a removed feature, a raised minimum OS | `.major` on its group | MAJOR, the rest back to 0 | `0.2.0` → `1.0.0` |
| Only docs, tests, CI or tooling, or a pure refactor | none (`skip-changelog` label for a refactor) | nothing | |

- The raise is counted from the **last production release** in the branch's
  history (its `vX.Y.Z` tag). A version already sent to testers but not yet
  released takes later notes without rising again, unless they need a bigger
  raise: fixes during QA stay on `0.2.0`; a breaking note makes it `1.0.0`.
  Before the first production release, the version being built takes every
  note.
- `+BUILD` goes up by one with every collect. Store builds take their build
  number from the release workflow's run number, which only rises.
- A hotfix is a pull request with a note into a `release/**` branch cut from
  the released tag; Promote it and it becomes a PATCH on that line.
- The **Changelog note** check (`.github/workflows/changelog-note.yml`) fails a
  pull request, or a merge-queue entry, that changes what ships without a
  note, has a malformed note, or changes the version. What ships is
  everything under `app/`, `packages/` and `modules/` except tests and docs.
- You rarely write the note by hand: on every push to a pull request,
  `.github/workflows/claude-changelog-note.yml` runs the same check and, when
  it fails, has Claude write the note and commit it (signed) to the branch.
  Pull from the branch before your next push. Pull requests from forks are
  skipped and write it by hand.

- **Releases are tags, not branches.** QA tests a `v0.2.0-alpha.N` tag and
  production is the same commit tagged `v0.2.0`, both made by the Promote
  workflow; see `docs/releasing.md`.

### The changelog

- **A pull request writes a note, not `CHANGELOG.md`.** One file in
  `changelog.d/`, named `<pr or issue>.<group>[.major|.minor].md`, whose text
  is the line; `changelog.d/README.md` has the details. Promote moves it into
  `CHANGELOG.md` at release, under the version it raised to.
- **Every version has its own section**, newest first, with its lines grouped
  as **Added**, **Changed**, **Fixed**, **Removed** or **Security** (only the
  groups a section uses). The sections below the top are never renamed or
  merged, so the changelog lists every version that was ever built.
- A note is needed for every change a patient could notice, and for changes
  to how the app is built, released or secured when they touch shipped code.
- Not recorded: a pure refactor, a test-only or comment-only change, a typo.
- **The top section's heading is the pubspec version.**
- Write for someone who was not there: what changed and why it matters, not
  how. No "fixed bug", no ticket number on its own, no file list.
- **Every line ends with its ticket, as a link**:
  `([#99](https://github.com/balsm-health/balsm_app/issues/99))` for the
  issue it fixes or delivers, or the pull request when there is no issue,
  `([#113](https://github.com/balsm-health/balsm_app/pull/113))`. Several
  tickets share one pair of brackets, separated by commas. The link is
  written out because the changelog is also read outside GitHub, where a
  bare `#99` links nowhere. The sentence comes first; the reference never
  stands in for it.
- **Never add a version to `app/web/version/<brand>.json` in a code change.**
  That file is live and lists released versions only; an entry there is
  offered to every installed app at once. It is edited at release time
  (`docs/app-update.md`, "Releasing"). That is also when the released
  version's section, and every `Unreleased` section below it, gets the
  release date: they all ship in that build.

`app/test/changelog_test.dart` fails when the top section is not for the
version being built, a version is listed twice or out of order, a section is
empty, or an `Unreleased` section sits below a released one.

## 10. Static Analysis (very_good_analysis)

- **One lint config for the whole repo**: `packages/balsm_lints/lib/analysis_options.yaml` includes
  [`very_good_analysis`](https://pub.dev/packages/very_good_analysis) plus Balsm's overrides. Every package's
  `analysis_options.yaml` starts with `include: package:balsm_lints/analysis_options.yaml` and adds only its own
  `exclude:` entries. Never add `flutter_lints`, a second rule set, or per-package rule changes — change the shared
  file and say why in a comment next to the rule.
- **Overrides that follow these standards** (do not "fix" them back): `constant_identifier_names` off (§1 uses
  `snake_case` consts), `lines_longer_than_80_chars` off (format width is 120), `public_member_api_docs` off (app
  packages, not published libraries). Generated code (`*.g.dart`, `*.i69n.dart`, `*.freezed.dart`) is excluded.
- **New and touched code is lint-clean.** CI fails only on errors today while the backlog is cleared package by
  package (`dart fix --apply`, then by hand). A package that reaches zero issues moves to `--fatal-infos` in CI and
  must stay there.
- **Measure the backlog** with `scripts/lint_report.sh` (writes `build/lint-report/summary.txt`: totals, per
  package, every error, counts per rule).
- **Every `// ignore:` has its reason in the comment directly above it** (why the rule does not apply here, not what
  the rule is). Text after the rule name on the ignore line itself is not safe — the analyzer reads it as part of the
  rule name and the ignore stops working. Do not add `ignore_for_file: constant_identifier_names`; the rule is off.

## 11. Widgets & Components

- **No helper methods or functions that return widgets** (`Widget _buildHeader()`). They rebuild with the parent,
  cannot be `const`, reuse the parent's `BuildContext`, and hide in DevTools. Extract a `StatelessWidget` /
  `ConsumerWidget` with a `const` constructor instead — in its own file when it is reused or non-trivial.
- **Split large builds**: a `build()` past ~60 lines gets its sections extracted into widgets.
- **Reuse the kit, never rebuild it**: sheets, pills, date pickers, buttons, status screens come from
  `packages/core/lib/src/kit/` and `app/lib/balsm_app/kit.dart`. Do not hand-roll a drag handle, a circular
  `InkWell` + `Container(shape: BoxShape.circle)` button, or a one-off dialog when a kit component exists; add a
  variant to the kit component instead.
- **Pass the state object, not its pieces**: a widget that reads 4+ fields of one state takes that typed state
  (`required DoseDayState day`) instead of 4+ primitive parameters.
- **Semantic callbacks**: a component with several actions names them by intent (`onRetake`, `onShare`,
  `onBackToProfile`), not by position (`onPrimary`, `onSecondary`). The component maps its state to the right
  callback so parents do not repeat the branching.
- No redundant default arguments (`avoid_redundant_argument_values`) — rely on the constructor's default.
- Screen content never hardcodes domain data (medication names, sample doses); it comes from entities. See
  CLAUDE.md on never fabricating PHI.

## 12. RTL / Bidirectional Layout

Arabic is a first-class language: layouts are written direction-neutral, never mirrored by hand.

- **Insets**: `EdgeInsetsDirectional.fromSTEB(start, top, end, bottom)` / `EdgeInsetsDirectional.only(start:, end:)`.
  Never `EdgeInsets.only(left:/right:)` or `EdgeInsets.fromLTRB`. `EdgeInsets.all` / `.symmetric` are fine.
- **Alignment**: `AlignmentDirectional.centerStart`, `.topEnd`, … Never `Alignment.centerLeft/Right`,
  `topLeft`, etc. (`center`, `topCenter`, `bottomCenter` are fine).
- **Stacks**: `PositionedDirectional(start:, end:)`, never `Positioned(left:, right:)`.
- **Corners & borders**: `BorderRadiusDirectional.only(topStart:, …)`, `BorderDirectional(start:, end:)`.
- **Text**: `TextAlign.start` / `.end`. `left`/`right` only inside an explicit `TextDirection.ltr` run (phone
  numbers, codes, IDs, emails).
- **Directional icons** (back, forward chevrons, "next" arrows): Material's directional `Icons.*` already mirror
  in RTL; for Lucide use `backChevron` / `forwardChevron` / `backArrow` / `forwardArrow(context)`. `Icon` has
  no `matchTextDirection` parameter (only `Image` does). No inline `isRtl ? Icons.a : Icons.b` ternaries.
- Progress fills start → end. LTR-only data (phone numbers, OTP codes, emails, dosage codes) sits in a
  `Directionality(textDirection: TextDirection.ltr)` run inside the RTL layout.
- **Exception — forced-LTR runs**: a `Text` with `textDirection: TextDirection.ltr` (versions, dates, numbers) is aligned
  by the *layout's* direction, which `TextAlign.start` cannot express once the run is forced LTR. Write
  `textAlign: rtl ? TextAlign.right : TextAlign.left` there, next to the `textDirection:` line. Nowhere else.
- **Directional `IconData` passed into a component** (a parameter, not an `Icon(...)` you build) uses `backArrow(context)`
  / `forwardArrow(context)` (or `backChevron` / `forwardChevron`) from `app/lib/balsm_app/kit.dart`, which read the ambient direction. Never an
  `s.rtl ? … : …` ternary and never a hand-rolled `Transform.flip` / `Transform.scale(scaleX: -1)` around an icon.

## 13. Colors, Assets & Theming

- **One home per token type, in core**: every design token lives in `packages/core/lib/src/kit/`, one file per
  concern, re-exported by `kit/tokens.dart` (and so by `package:core/core.dart`), so the app and every module read
  the same values. The app's `app/lib/balsm_app/tokens.dart` only re-exports them.

  | Type | Class | File |
  |---|---|---|
  | Colour | `AppColors` | `app_colors.dart` |
  | Corner radius | `AppRadii` | `app_radii.dart` |
  | Elevation | `AppShadows` | `app_shadows.dart` |
  | Font size | `FontSizes` | `font_sizes.dart` |
  | Text style | `Typo` | `typo.dart` |
  | Duration and curve | `Motion` | `motion.dart` |
  | Accent hue | `Accent` | `accent.dart` |
  | Contrast helper | `ColorContrast` | `color_contrast.dart` |
  | Window classes, layout measures, touch target | `BalsmWindow`, `BalsmWindowClass`, `BalsmDensity` | `balsm_window.dart` |

  Never declare a second class for a type that has a home, and never write the value at the call site.
- **No hardcoded colors in screens or widgets**: no `Color(0x…)` or `Colors.*` outside `AppColors`. Need a new color?
  Add a semantic token (`warningBackground`, `scrim`), not a hex value at the call site. Translucent variants of white
  and cream are named by opacity (`white70`, `creamVeil`) so they stay `const`. `Colors.transparent` is allowed.
  `scripts/check_tokens.sh` enforces this and the rule below.
- **No bare radii, font sizes or animation durations**: `BorderRadius.circular(AppRadii.lg)`, `fontSize: FontSizes.meta`,
  `duration: Motion.base`. A value that is not on the scale is a design question: raise it, then add a named token.
- **Feature-only values**: a palette used by one feature lives next to that feature
  (`maintenance/maintenance_tokens.dart`), and a value used by one screen is a private top-level `const` at the top of
  that screen's file, with a comment saying why it is not shared. Do not name a token file or class after a design
  iteration (`v2`); do not add a catch-all class. A new shared concern gets a new file in core's `kit/` and an `export`
  line in `kit/tokens.dart`. Members drop the class name (`AppRadii.xl`, not `AppRadii.rXl`).
- **No raw `'assets/…'` strings** outside `app/lib/balsm_app/assets.dart`: every image, icon and font path is a
  typed constant in `Assets` and referenced through it.
- Never convey state by color alone (see §15).

## 14. Type Safety, Null Safety & Logging

- **No `dynamic`** (and no `Object?` used as "anything") without a comment saying why — typically a JSON or
  platform-channel boundary, parsed into a typed model immediately.
- **No `!`** without a one-line justification. Prefer pattern matching (`if (x case final v?)`), `?.`, `??`,
  early returns, and sealed hierarchies with exhaustive `switch`.
- No unsafe `as` casts on untrusted data; parse at the boundary (§2 value-object factories).
- **No `print` / `debugPrint`.** Use `dart:developer` `log()` or the dev log buffer (`logBufferProvider`). Never log
  PHI, tokens, OTPs, emails or other PII (CLAUDE.md). Verbose network logging is debug-only.
- After an `await` in a widget, check `context.mounted` before touching `context`; in a notifier, do not act on a
  disposed provider.

## 15. Accessibility & Adaptive Layout

- **Touch targets ≥ 48×48 dp.** `app/test/accessibility_guidelines_test.dart` enforces the floor on real screens.
- Custom interactive widgets are wrapped in `Semantics` with a label (and hint/role where useful); decorative
  illustrations, background shapes and icons next to a text label are wrapped in `ExcludeSemantics`.
- **Never color alone** for selected / error / success / severity: pair it with an icon, text or border change.
- Support system text scaling without truncation or `RenderFlex` overflow; test large text on changed screens.
- Tablets and wide windows: forms, readers and dialogs are constrained to a readable max width (~600–720 dp) and
  centered, not stretched edge to edge; grids add columns as width grows.

## 16. Persistence & Testing

- **Schema changes are migrations**: every `schemaVersion` bump (drift `AppDatabase`, `ModulePreferences`) adds
  the matching step to the migration and a line to the schema-history comment, and has a test that upgrades from
  the previous version. On-device PHI has no server copy — a broken migration is lost patient data.
- Screens and widgets never touch `SharedPreferences`, `FlutterSecureStorage` or drift directly; they go through a
  provider backed by the module's port (§3, §7).
- Tests mirror `lib/`. Prefer real fakes and in-memory implementations over mocks; use `mocktail` when a mock is
  unavoidable.
- Widget tests with spinners or repeating animations use `tester.pump(duration)`, never `pumpAndSettle()` (it
  never settles).
- Architecture rules that a machine can check live in `app/test/architecture_test.dart`; when you add a rule here
  that can be grepped, add the check there too.
