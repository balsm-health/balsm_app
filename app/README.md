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

## Care-team contact import

`CareImportSheet` is the review step after the OS contact picker (design:
`care-import.jsx`, its `initial` branch). The picker is the selection surface,
so the sheet confirms rather than browses: it lists what was picked, proposes a
type per contact that one tap corrects, and marks anyone already on the team.

Entry is a button in the screen body, **not** the FAB. The FAB is the primary
add, and routing it through the OS picker would make typing a provider in by
hand the slower path — two existing tests assert that, correctly.

The sheet's copy says care-team records sync to the Balsm account. The old
"stays on your device" line in `care_add_note` was corrected at the same time:
it stopped being true when care team gained a cloud mirror, and the deletion
pre-confirm screen already says so in both columns.

`BalsmButton` does not ellipsize its label, so a long Arabic label plus an icon
overflows the row at narrow widths. The import button carries no icon and its
label is short for that reason.

