---
context: app-shell
plane: consumer
features:
  - "P001: patient app composition root - bootstrap, DI overrides, router, flavors, shell UI"
---

# app

Composition root. Binds core ports to module implementations at bootstrap, mounts module routes, owns flavors/env and the shell (tabs, home).
