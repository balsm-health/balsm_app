---
context: infrastructure
plane: consumer
features:
  - "P001: typed HTTP clients for the Balsm .NET API (auth, account, sessions, deletion, disclosure, emergency QR)"
---

# balsm_api

Transport layer: Dio-based BalsmApiClient, typed per-context clients, DTOs, ApiException, PhiLeakInterceptor. DTOs are Strings/primitives by design - domain modules wrap them into typed VOs (anti-corruption).
