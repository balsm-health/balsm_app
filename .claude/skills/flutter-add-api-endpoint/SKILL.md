---
name: flutter-add-api-endpoint
description: Route every backend HTTP call through packages/balsm_api — abstract per-area interfaces (AuthApi, SessionsApi, …), dio implementations, and hand-written DTOs. Use when adding, changing, or consuming any API endpoint, request/response model, or DTO — or on sight of `import 'package:dio/dio.dart'`, an inline `Map` payload, or a hardcoded '/path' HTTP call inside a feature module.
metadata:
  type: convention
---

# Add or Change a Balsm API Endpoint

All backend HTTP lives in **`packages/balsm_api`**. Feature modules never
import `dio`, never build inline `Map` payloads, and never parse raw JSON
envelopes. Modules bind to **abstract interfaces** via core DI providers.

## Package anatomy

```
packages/balsm_api/lib/src/
  transport/   BalsmApiClient (owns the Dio), NetworkManager (HTTP verbs +
               DioException→ApiException mapping), ApiException, envelope.dart
  <area>/      <area>_api.dart        ← abstract interface (pure signatures)
               dio_<area>_api.dart    ← DioXxxApi implements XxxApi, calls NetworkManager
               requests.dart          ← request DTOs (toJson)
               responses.dart         ← response DTOs (fromJson)
```

`DioXxxApi` never touches `Dio` directly — it calls the injected
`NetworkManager` (`_net.get/post/put/delete`), which owns transport + error
mapping. The impl only does DTO `toJson`/`fromJson` and envelope handling.

Areas mirror the .NET backend modules: auth, account, emergency_qr,
sessions, deletion, disclosure, geofence. New backend module ⇒ new area
folder, same four-file shape.

## Wire-format rules (violating these breaks the backend contract)

- **Casing is per-area:** account = camelCase (`preferredLanguage`);
  everything else = snake_case (`device_id`). Match the .NET controller.
- **Envelope is per-area:** auth returns FLAT bodies; all other areas wrap
  in `{data, error}` — use `unwrapEnvelope` / `unwrapEnvelopeList` from
  `transport/envelope.dart`. Never hand-parse `body['data']`.
- DTOs are plain immutable classes with hand-written `fromJson`/`toJson`.
  **No freezed / json_serializable / build_runner** in this package.

## When you add or change an endpoint

1. **DTOs** in the area's `requests.dart` / `responses.dart`.
2. **Signature** on the abstract interface (`<area>_api.dart`) with a doc
   comment naming the route (`/// POST /sessions/revoke-all`).
3. **Implementation** in `dio_<area>_api.dart`: call the injected
   `NetworkManager` (`await _net.post(path, data: …, cancelToken: …)`), then
   `unwrapEnvelope`/parse. NetworkManager already maps `DioException →
   ApiException`, so impls carry NO `try/on DioException` (except special cases
   like account `getSelf` catching `ApiException` for a 404→null). Never call
   `Dio` directly; never construct `NetworkManager` in a module.
   - **Cancellation:** every method takes an optional `{CancelToken? cancelToken}`
     (last param) forwarded to NetworkManager. `CancelToken` is re-exported
     from `balsm_api`, so callers never import dio. A cancelled request throws
     `ApiException` with `isCancelled == true` (mapped from
     `DioExceptionType.cancel`); callers should ignore it, not show a failure.
4. **Export** all new files from `lib/balsm_api.dart`.
5. **Test** in `packages/balsm_api/test/<area>/` using
   `test/helpers/fake_http_adapter.dart` — assert path, method, exact wire
   keys, and response parsing. Run `(cd packages/balsm_api && dart test)`.
6. **Provider**: new area ⇒ add `Provider<XxxApi>` in
   `packages/core/lib/src/network/api_providers.dart`
   (`DioXxxApi(dio: ref.watch(balsmApiClientProvider).dio)`).
7. **Module**: consume the interface via the provider; map DTO → domain
   type and `ApiException` → the module's `Failure`/exception in the
   module's own layer. Never construct `DioXxxApi` in a module.
8. **Cross-repo duty** (AGENTS.md): update the API client collection in
   `Balsm-Core` `/docs/api/` for any added/changed endpoint.

## PHI constraints

- Never log or `toString()` emails, user ids, tokens, or payload bodies.
- `ApiException.toString()` excludes `serverMessage` — keep it that way.
- Don't grow `PhiLeakInterceptor.allowedFields` casually: new telemetry
  fields must be deliberately non-PHI (see `test/phi_leak_fuzz_test/`).

## Do / Don't

| Do | Don't |
|----|-------|
| `ref.watch(sessionsApiProvider)` in a module | `ref.watch(...)` a Dio or build one |
| `on ApiException catch (e)` + map to module Failure | `on DioException` in a module |
| `e.fromEnvelope ? ValidationFailure(e.serverMessage ?? …)` | show `serverMessage` in logs |
| Add DTO + interface + impl + test + provider together | leave an inline `Map` payload "for now" |

## Checklist

- [ ] DTOs with exact wire keys (casing per area).
- [ ] Interface method with route doc comment + optional `{CancelToken? cancelToken}`.
- [ ] Dio impl throws only `ApiException` and forwards `cancelToken`.
- [ ] Exports from `balsm_api.dart`.
- [ ] Area test green: `(cd packages/balsm_api && dart test)`.
- [ ] Core provider exists; module uses the abstraction.
- [ ] No `package:dio` import outside `balsm_api`/`core`.
- [ ] `Balsm-Core /docs/api/` collection updated.
