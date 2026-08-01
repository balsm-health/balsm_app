# Shared Balsm date picker

- **Date:** 2026-08-02
- **Repo:** `balsm_app`

## Why

Date selection was inconsistent: a branded bottom-sheet calendar
(`_DobCalendarSheet`) was trapped private in `auth_flow.dart`, while two other
screens used off-brand Material `showDatePicker`. Standing rule: always use the
shared Balsm date picker.

## What

- New shared widget `packages/core/lib/src/kit/widgets/balsm_date_picker.dart`
  exposing `showBalsmDatePicker(context, {firstDate, lastDate, title,
  confirmLabel, initial, accent, months, weekdays, rtl})` → `Future<DateTime?>`.
  Bottom-sheet calendar with month/year nav + year grid; days outside
  `[firstDate, lastDate]` are disabled. Exported via the core kit barrel.
- **Boundary-clean:** lives in `core` (so `modules/*` can use it) and depends
  only on core tokens + `BalsmRoundButton` + Material icons — never on the app
  shell. Localized `months`/`weekdays`, `rtl`, and `accent` are parameters with
  sensible defaults (English / ambient Directionality / app accent).

## Migrations (all 3 date-pick sites)

- `app/lib/patient_app/screens/auth_flow.dart` — DOB; deletes the private
  `_DobCalendarSheet`, passes localized strings + accent.
- `app/lib/patient_app/screens/personal_details.dart` — DOB; replaces raw
  `showDatePicker`.
- `modules/medications/.../add_medication_screen.dart` — start/end dates;
  replaces raw `showDatePicker`.

## Tests

`packages/core/test/kit/balsm_date_picker_test.dart` — selecting a day and
confirming returns it; a day outside `[firstDate, lastDate]` is not selectable.
