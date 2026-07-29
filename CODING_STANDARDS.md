# balsm_app_flutter — Coding Standards

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
- `app/` — the runnable shell (brands, patient_app prototype port)
- modules never import other modules — cross-module reads go through core contracts/ports
- PHI persistence implements core's scoped data-source contracts (`ProfileDataSource` partitioned by `health_profile_id`, `UserDataSource` by account); domain/application layers depend on the module port, never on `Drift*` concretes

## 4. Localization

- all user-visible strings live in i69n bundles (app: `app/lib/patient_app/i18n/`, core: `src/localization/i18n/`); regenerate with `dart run build_runner build` after editing JSON
- no inline bilingual ternaries (`ar ? '…' : '…'`)
- reference data (countries, languages) comes from core value objects + `CountryRegistry` — no private lists in screens
- prefer typed `s.strings.key` over stringly `s.t('key')`; `t()` only for keys computed at runtime

## 5. Tooling

- Flutter runs via **puro**: `puro flutter …`, `puro dart …`
- tests per package (`puro flutter test` in `packages/core` etc.); analyze before committing
- **code generation**: `dart run tool/build.dart gen` (also `melos run gen`, or the "Flutter: code generation" VS Code task) — runs `build_runner` across every package that depends on it (i69n bundles, drift, json/freezed) and skips the rest; add `--watch` for continuous rebuilds. Regenerate after editing any `*.i69n.json`, drift table, or annotated model.

## 6. Flutter Performance

- `const` constructors wherever possible
- `ListView.builder` for long lists — never materialize all children
- `RepaintBoundary` around frequently repainting widgets
- cache network images with explicit policies
- minimize widget tree depth
- `compute()`/isolates for CPU-intensive work — never block the UI thread
- profile with DevTools before/after; measure frame render times
- lazy-load screens and heavy widgets
