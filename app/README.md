---
context: app-shell
plane: consumer
features:
  - "P001: patient app composition root - bootstrap, DI overrides, router, flavors, shell UI"
  - "P001: vault attachment preview - decrypt-in-memory image + PDF viewer (records, prescriptions); bytes never touch disk"
---

# app

Composition root. Binds core ports to module implementations at bootstrap, mounts module routes, owns flavors/env and the shell (tabs, home).

## Care-team cloud sync triggers

`careTeamSyncServiceProvider` is overridden in `brands/balsm/main_balsm.dart`,
beside the Drive blob backup and running alongside it — not replacing it. The
blob needs a Google session, so email-OTP and Apple patients get no backup at
all; this mirror is what gives them a roster that survives device loss.

Three triggers, per FR-509:

| Trigger | Where |
|---|---|
| Sign-in / dependant-profile switch | `shell.dart` — `ref.listen(currentProfileIdProvider)`, fires on the null → non-null edge so a signed-out app never calls the API |
| App foreground | `shell.dart` — `didChangeAppLifecycleState(resumed)` |
| Explicit user refresh | `care_team_screen.dart` — `SubScreen(onRefresh:)` |

All three are fire-and-forget. The screen reads from drift, so a failed sync
costs the patient nothing visible; the service records it on the sync-status
provider and the next trigger retries.

`SubScreen` gained an optional `onRefresh`. Null (the default) means no
indicator, so every other sub-screen is untouched. Note the indicator is
**material_ui's** `RefreshIndicator`, not Flutter's — widget tests for a
refreshable sub-screen need material_ui's `MaterialApp`, as `care_team_test.dart`
already uses.

