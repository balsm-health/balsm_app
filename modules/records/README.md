---
context: Personal Health
plane: consumer
features:
  - "P001: health-records vault - self-uploaded labs/scans/reports metadata, on-device (SQLCipher)"
---

# records

Health-records vault: metadata index for the user's lab results, scans, and
reports (PHI, on-device only). Document bytes live in the app documents dir;
this module owns the searchable `health_record` index and exposes it as the
first concrete `UserDataSource` implementation (user-partitioned, fail-loud).
