---
context: app-shell
plane: consumer
features:
  - "P001: patient app composition root - bootstrap, DI overrides, router, flavors, shell UI"
  - "P001: vault attachment preview - decrypt-in-memory image + PDF viewer (records, prescriptions); bytes never touch disk"
---

# app

Composition root. Binds core ports to module implementations at bootstrap, mounts module routes, owns flavors/env and the shell (tabs, home).
