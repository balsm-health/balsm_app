---
context: shared-kernel
plane: consumer
features:
  - "P001: shared kernel - domain VOs (UniqueId/UserId/EntityId), event bus, AppDatabase (SQLCipher), data-source ports, localization (i69n), design kit, telemetry, notifications, backup"
---

# core

Patient-app shared kernel. Cross-context ports (currentUserIdProvider, currentEntityIdProvider, readAccountRepositoryProvider), cross-context events (CountryChanged, LanguageChanged), typed identity VOs, storage interface layer, UI kit. Must never depend on a module.
