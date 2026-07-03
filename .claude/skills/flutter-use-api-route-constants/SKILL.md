---
name: flutter-use-api-route-constants
description: Route every backend API path through the `ApiRoutes` constants class in packages/balsm_api (lib/src/api_routes.dart) instead of hardcoding '/…' string literals. Use when adding, changing, or calling any endpoint — or when you see or are about to write a `'/account/…'`, `'/auth/…'`, `_net.get('/…')`, `dio.post('/…')`, or any literal HTTP path.
metadata:
  type: convention
---

# Use API Route Constants

Every backend path in `balsm_api` is referenced through **one source of
truth** — the `ApiRoutes` class in
`packages/balsm_api/lib/src/api_routes.dart`. Do **not** hardcode `'/…'`
route string literals in `dio_<area>_api.dart` (or anywhere else).

## Why

- One place to rename/re-version a path — call sites don't break.
- Typos become compile errors, not silent 404s at runtime.
- One auditable list to **diff against the .NET controllers** — the whole
  wire contract in a single file.

## When you add or change an endpoint

1. **Add the route** to `ApiRoutes`, in the matching backend-module group:
   - Fixed path → `static const` in **lowerCamelCase**, built from the
     group's base const (`static const accountSelf = '$_account/self';`).
   - Path with a path parameter → `static String` **builder**
     (`static String session(String id) => '$_sessions/$id';`).
2. **Reference it** at the call site — never a literal:
   ```dart
   await _net.post(ApiRoutes.accountHandleClaim, data: req.toJson());
   await _net.get(ApiRoutes.emergencyQrResolve(tokenId));
   await _net.delete(ApiRoutes.session(sessionId));
   ```
3. `ApiRoutes` is exported from `package:balsm_api/balsm_api.dart`.

## The `ApiRoutes` class shape

```dart
class ApiRoutes {
  ApiRoutes._();

  // ── Account ──
  static const _account = '/account';
  static const accountSelf = '$_account/self';
  static const accountHandleClaim = '$_account/handle/claim';

  // ── Sessions ──
  static const _sessions = '/sessions';
  static const sessions = _sessions;
  static String session(String sessionId) => '$_sessions/$sessionId';
}
```

- Route consts are **lowerCamelCase** (idiomatic Dart — no
  `constant_identifier_names` ignore needed).
- Group per backend module; each group builds leaves from one base const
  (`static const _account = '/account'`) so the prefix lives in one spot.
- Name by meaning (`accountHandleClaim`), grouped by area.
- Dynamic segments → `static String` builder, so it stays a method.

## Tests keep the literals

Area tests assert `expect(adapter.requests.single.path, '/account/self')`
with the **literal** on purpose — the test is the oracle that the constant
resolves to the right wire path. Do not replace the expected literal in a
test with `ApiRoutes.accountSelf` (that would test nothing).

## Do / Don't

| Do | Don't |
|----|-------|
| `_net.post(ApiRoutes.accountHandleClaim, …)` | `_net.post('/account/handle/claim', …)` |
| `ApiRoutes.session(id)` builder for path params | `'/sessions/$id'` at the call site |
| Add the const + use it in the same change | Leave a literal "to clean up later" |
| Keep the expected literal in the test | Assert against `ApiRoutes.*` in the test |

## Checklist

- [ ] Route added to `ApiRoutes` (const for fixed, `static String` for params).
- [ ] lowerCamelCase name, grouped under the right backend module.
- [ ] Every call site uses `ApiRoutes.*` — no `'/…'` literal in `lib/src/*/dio_*.dart`.
- [ ] Test still asserts the literal wire path (oracle).
- [ ] `(cd packages/balsm_api && dart test)` green.
