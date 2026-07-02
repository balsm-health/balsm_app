# `balsm_api` Package — API Layer Extraction Design

**Date:** 2026-07-02
**Status:** Approved (design review with Hossam)
**Scope:** Flutter monorepo (`balsm_app_flutter`)

## Problem

The API layer is scattered and untyped:

- Transport (`BalsmApiClient`, `PhiLeakInterceptor`, `dioClientProvider`) lives in `core/src/network/`.
- auth / account / geofence_block wrap endpoints in per-module `infrastructure/api/` adapters using inline `Map` requests and record responses — no DTO classes.
- emergency_card / sessions / deletion call raw `Dio` **inside application-layer use cases**, leaking HTTP concerns across the layer boundary.
- The wire contract with the .NET backend (`Balsm-API-DotNet`, 7 modules) has no single Flutter-side surface, making cross-repo contract drift hard to audit.

## Motivations (in priority order)

1. **Typed contract in one place** — mirror the .NET API shape; formalize DTOs; make drift diffable.
2. **Stop dio leaking into modules** — use cases depend on typed clients, never `Dio`.
3. **Reuse in future apps** — clinician app / other clients consume the same API package without dragging `core` (drift, sqlcipher, notifications, go_router).

OpenAPI codegen is **not** a current goal, but the layout must not preclude it.

## Decision

Create a new **pure-Dart** package `packages/balsm_api` holding transport + all endpoint clients + hand-written DTOs. Each area exposes an **abstract client interface** (`AuthApi`) with its dio implementation (`DioAuthApi`) in the same package; modules and DI bind to the abstraction only. Anti-corruption mapping to domain types stays inside each module.

Interfaces (rather than bare concrete classes) buy: swappable transport later (three-tier architecture — a local-server tier could ship a second implementation), trivial fakes in module tests, and a contract file per area that is pure signatures — the cleanest thing to diff against the .NET controllers.

### Alternatives rejected

- **Transport-only package, DTOs stay per-module** — fails motivations 1 and 2 (contract stays scattered; modules keep `dio` for their adapters).
- **Formalize inside `core/src/api/`** — fails motivation 3 (reuse drags all of core's Flutter-heavy deps).
- **Domain ports in modules + implementations in api package** — dependency cycle (api → module ports → api). Interfaces avoid this by living in `balsm_api` itself, beside their implementations.
- **Concrete classes only (no interfaces)** — cheaper ceremony, but loses transport swap and forces module tests to mock concrete classes.

## Package layout

```
packages/balsm_api/
  pubspec.yaml            # pure Dart: dio only (no codegen)
  lib/
    balsm_api.dart        # single public export file
    src/
      transport/
        balsm_api_client.dart      # moved from core (decoupled, see Transport)
        phi_leak_interceptor.dart  # moved from core verbatim (pure dio)
        api_exception.dart         # shared error envelope
      shared/              # cross-area DTOs (paging, timestamps)
      auth/
        auth_api.dart      # abstract interface — pure endpoint signatures
        dio_auth_api.dart  # DioAuthApi implements AuthApi
        requests.dart      # request DTOs (manual fromJson/toJson)
        responses.dart     # response DTOs (manual fromJson/toJson)
      account/   ...same shape...
      emergency_qr/
      sessions/
      deletion/
      disclosure/
      geofence/
```

Areas (7, from call-site audit): auth, account, emergency_qr, sessions, deletion, disclosure, geofence. **medications/home/profile have zero HTTP calls** (pure on-device Drift) — no area created until an endpoint exists.

- Folder-per-backend-module mirrors the .NET layout (`Auth`, `Account`, `EmergencyQr`, `Deletion`, `Sessions`, `Disclosure`, shared) so contract diffing stays 1:1.
- `environment:` is SDK-only — **no `flutter:` dependency**. CI-enforceable via `dart pub deps` check later if desired.
- Dev deps: `test`, `mocktail` only (client tests stub `HttpClientAdapter`). No codegen dev deps — DTOs are hand-written.

## DTO conventions

- **Plain immutable Dart classes with hand-written `fromJson`/`toJson`** — *amended from freezed*: the repo has zero freezed/json_serializable codegen today (records + manual parsing everywhere), a repo skill (`flutter-implement-json-serialization`) codifies manual mapping, and AGENTS.md forbids unjustified new dependencies. The package stays codegen-free (no build_runner at all).
- Wire names written literally in `fromJson`/`toJson` (snake_case for most areas: `country_code`, `device_id`, …). **Exception discovered in audit:** the account area uses camelCase wire keys (`preferredLanguage`, `countryCode`, `displayName`) — DTOs must match exactly.
- **Envelope nuance discovered in audit:** most areas wrap responses in `{data, error}`; **auth returns flat bodies** (token fields at top level). Shared `unwrapEnvelope`/`unwrapEnvelopeList` helpers serve enveloped areas; auth impls parse flat.
- Requests and responses only — **no domain types in this package**. Modules keep DTO→domain mapping in their use cases/adapters (anti-corruption stays in the bounded context). Auth keeps its `BalsmAuthAdapter` as that mapping layer — its public surface (method signatures, `AuthTokens`/`RefreshedTokens` records, `AuthException`) is preserved so auth use cases don't change.
- One `requests.dart` / `responses.dart` pair per area; area export file re-exports API class + DTOs.

## Transport

`BalsmApiClient` moves to `balsm_api` with Flutter coupling removed:

- `init()` / `reconfigure()` take a **`baseUrl` string** instead of `ServerPreset`/`ActiveServerStore`.
- Stays in `core`: `ActiveServerStore` (flutter_secure_storage), `ServerPreset`, `FlavorConfig`, `ServerReconfigured` event + `EventBus` publication, and all riverpod providers. Core wraps/configures the client and republishes reconfiguration events.
- `PhiLeakInterceptor` moves verbatim (already pure dio). Its telemetry-scrub contract (`extra['phi_safe_body']`, never mutate outbound body) is unchanged.
- Timeouts/headers defaults move with the client factory.

## DI wiring (stays in core)

- `balsmApiClientProvider` remains in core (still overridden in `ProviderScope`).
- Core adds one provider per area: `authApiProvider`, `accountApiProvider`, `emergencyQrApiProvider`, `sessionsApiProvider`, `deletionApiProvider`, `disclosureApiProvider`, `geofenceApiProvider` — each typed as the **abstract interface** (`Provider<AuthApi>`) and constructing the dio implementation from the shared dio instance.
- `dioClientProvider` is **deleted at the end of migration** — after that, `Dio` is not visible outside `balsm_api` (core wiring excepted).

## Error model

- `ApiException` hierarchy in `balsm_api/src/transport/api_exception.dart`: HTTP status, machine-readable `code`, optional `retryAfter` (parsed from `Retry-After` header), safe message.
- Auth's 423 account-lockout special case becomes a typed field on the exception; the auth module maps `ApiException` → its domain `AuthException` (mapping stays in auth).
- Implementations throw `ApiException` — never raw `DioException` — so modules drop their `on DioException` handling. The throwing contract is documented on the interface methods.

## Migration order

One module per commit; `melos gen` + `analyze` + `test` green at every step:

1. **emergency_card** — worst offender (raw dio in use cases)
2. **sessions**
3. **deletion**
4. **account** — port adapter to typed client
5. **auth** — biggest adapter, done once the pattern is proven
6. **disclosure / geofence_block** — remainder sweep (medications/home/profile have no HTTP)
7. **Cleanup** — delete `core/src/network/` transport pieces, delete `dioClientProvider`, drop `dio` from every module pubspec (`app` keeps only what its own code needs)

## Boundary rule updates

- Rule becomes: **modules depend only on `core` and `balsm_api`**.
- Update `Balsm-Core/agents/rules/AGENTS.md` P001 architecture note (line ~22) accordingly.
- `balsm_boundary_lint` inspection: **no code change required** — `no_module_to_module_imports` checks against a `_modules` list that `balsm_api` is not in, so module→`balsm_api` imports pass; `core_must_not_depend_on_module` likewise unaffected by core→`balsm_api`.
- Modules must import only their own area's exports; cross-module DTO imports are a review flag (folder-per-area makes this greppable; lint enforcement can come later).

## AI guidance (new repo skill)

New skill at `.claude/skills/flutter-add-api-endpoint/SKILL.md` (same format as `flutter-use-asset-constants`), `metadata.type: convention`. Content requirements:

- **Trigger description:** adding/modifying any backend API call, endpoint, request/response model, DTO, or dio usage; or on sight of `Dio` imports in module packages.
- **Rules the skill encodes:**
  1. All endpoint methods + DTOs live in `packages/balsm_api` under the matching backend-module folder — never inline `Map` payloads or raw `Dio` in feature modules. Every area is an abstract interface (`AuthApi`) plus a dio implementation (`DioAuthApi`); new endpoints touch both.
  2. Hand-written DTO conventions (immutable class + manual `fromJson`/`toJson`, exact wire key casing per area, requests/responses files, export wiring).
  3. Implementations throw `ApiException`; modules map to domain errors in their own layer.
  4. New area ⇒ new `Provider<AbstractApi>` in core DI; module consumes the provider, never constructs implementations.
  5. PHI constraints: never log email/userId/tokens; don't touch `PhiLeakInterceptor` allowlist without adding the new safe fields deliberately.
  6. Cross-repo duty (from AGENTS.md): when an endpoint is added/changed, update the API client collection in `Balsm-Core` `/docs/api/`.
  7. Checklist: DTOs + client method + provider + module mapping + `melos gen` + `analyze` + tests green + no `dio` import outside `balsm_api`/core.

## Testing

- `balsm_api` gets its own test suite: DTO round-trip tests + client tests against a mocked dio adapter (status codes, error envelope, `Retry-After` parsing, PHI scrub behavior).
- Module tests switch from mocking `Dio` to faking/mocking the abstract interfaces (plain `implements AuthApi` fakes or mocktail).
- Existing adapter tests migrate with their endpoints.
- Repo-root suites (`golden`, `phi_leak_fuzz`) — `phi_leak_fuzz` retargets the interceptor at its new import path.

## Out of scope

- OpenAPI/swagger codegen (layout is compatible; revisit later).
- Retry/backoff policy changes, websockets, offline queueing.
- Enabling `balsm_boundary_lint` (blocked on analyzer bump — separate task).
