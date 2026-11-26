---
context: Personal Health
plane: consumer
features:
  - "P002: vaccination log (manual) — doses copied from the paper vaccination card, per person"
  - "P003b: each family member's vaccinations, with the next dose due and the doses past due"
---

# vaccinations

The vaccination log of one person — the account holder or a family member
they manage on this phone. Each dose is entered by hand from the paper
vaccination card: the vaccine's name as written there, the dose number, the
day it was given, where (optional) and, when the card or the doctor gives
one, the day the next dose is due. The app suggests and schedules nothing.

Records are partitioned by the person they are about (`health_profile_id`),
like the record vault: with no scope a read or write follows core's active
profile. Everything stays on the device; deletes are soft.

## Layers

- `domain/` — `VaccinationRecord` (its rules reported all at once as
  `VaccinationViolation`s) and `VaccinationStatus` (the latest dose of each
  vaccine → next doses still upcoming vs. past due, against a day the caller
  passes in, never the wall clock).
- `application/` — `VaccinationsDataSource` (the port) and
  `RecordVaccinationUseCase`.
- `infrastructure/drift/` — `DriftVaccinationsDataSource` over
  `vaccination_record` in core's encrypted database.
- `presentation/` — Riverpod providers the app shell's screens watch.

The screens are ported in the app shell
(`app/lib/balsm_app/screens/family/vaccinations_screen.dart`), behind the
`mother_child` flag.
