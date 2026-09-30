# Medications: the daily to-take list

The Meds tab lists every dose due today, grouped Morning (before 12:00) and
Evening. There are no notifications yet: a dose exists only because the
schedule says so, and the patient marks it Taken, Skipped or Snoozed from the
list. The last 7 days of those outcomes drive the adherence ring.

All of it is on-device PHI (SQLCipher). Nothing here reaches the cloud.

## Where it comes from

Two forms feed the list, and they share one med form
(`app/lib/balsm_app/widgets/med_plan_form.dart`):

- **Add medication** (Meds tab **+**): a med with no prescription.
- **Add prescription**: every med typed into the prescription is also added
  to the list. Editing or deleting the prescription later doesn't touch
  those meds.

## Schedule rules

`dosesOn` in `modules/medications/lib/src/domain/services/dose_schedule.dart`
is the only place these are computed. Tests:
`modules/medications/test/dose_schedule_test.dart`.

| Frequency on the form | Stored as | Doses |
|---|---|---|
| One time | `once` | once, on the day it was added |
| Times per day = 1 | `daily` | once a day, Morning (08:00) or Evening (20:00) |
| Times per day ≥ 2 | `daily` | at each time. Times are suggested (2 → 08:00, 20:00; 3 → 08:00, 14:00, 20:00) and editable |
| Every X hours | `everyHours` | from the first dose, e.g. 8h from 08:00 → 08:00, 16:00, 00:00 |
| Every X days | `everyDays` | the day it was added, then every Xth day |
| Other (free text) | `daily` | once a day; the text is kept as `frequencyNote` |

| Duration | Effect |
|---|---|
| For a set period (N days / weeks / months) | ends at midnight after the last day (`endDate`) |
| Until package finishes, Ongoing, Other | never ends on its own; kept for display |

- **New meds start at midnight today.** A med added at 16:00 with an 08:00
  dose shows that dose as Due, rather than skipping it.
- **Rows written before these rules** started at the moment they were added.
  Their earlier slots that day stay hidden, as they always were.
- Frequency, interval and duration live in the `schedule_config` JSON column,
  so they needed no migration. `notes` is an additive column.

## Testing

```bash
fvm flutter test modules/medications/test
fvm flutter test app/test/med_plan_draft_test.dart
maestro test app/.maestro/add_medication.yaml   # e2e build, iOS simulator
```

On iOS, Maestro's `hideKeyboard` doesn't close Flutter's keyboard, and the
keyboard covers the frequency and timing controls. The flow presses Enter on
the single-line dose field instead.
