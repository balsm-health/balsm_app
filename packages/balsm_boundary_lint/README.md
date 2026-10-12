---
context: tooling
plane: cross-plane
features:
  - "P001: custom_lint rules enforcing DDD module boundaries"
---

# balsm_boundary_lint

custom_lint plugin: no module-to-module imports, core must not depend on modules, barrel whitelist, no aggregate leak into presentation, domain stays Flutter-free, no test-kit in release.
