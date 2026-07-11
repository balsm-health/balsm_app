---
context: shared-kernel
plane: cross-plane
features:
  - "P001: domain primitives (UuidV7, CountryCode, Bcp47Tag, Money)"
  - "P001: SQLCipher drift setup + key derivation (on-device PHI store)"
  - "P001: event bus, i18n, HTTP infrastructure"
  - "P001: notification permission state + scheduler (offline-capable local notifications)"
  - "P002: BackupAdapter ports (iCloudBackupAdapter, DriveBackupAdapter) — ACL to platform clouds"
---

# core

Shared kernel for the Flutter monorepo — not a bounded context. Value objects, event bus, SQLCipher/drift setup, backup adapter ports, notification plumbing. Governed strictly: anything domain-flavored gets evicted to its owning module (constitution Principle IV; convention in `Balsm-Core/architecture/bounded-contexts/README.md`).

Boundary rules (enforced by `balsm_boundary_lint`): core never depends on modules; domain never imports Flutter.
