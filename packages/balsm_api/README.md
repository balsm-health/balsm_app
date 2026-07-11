---
context: infrastructure
plane: cross-plane
features:
  - "P001: BalsmApiClient (dio wrapper) + auth interceptor — extracted API layer"
---

# balsm_api

HTTP client layer for the Balsm backend APIs — infrastructure, not a bounded context. Wraps dio with auth interception; modules consume it through `core`'s abstractions. Convention: `Balsm-Core/architecture/bounded-contexts/README.md`.
