---
context: Personal Health
plane: consumer
features:
  - "P003b: pregnancy tracking on the account holder's own profile (due date or last period, obstetrician, next visit, week and trimester)"
  - "P003b: one prenatal profile per baby (Baby A/B…, optional name, no sex before birth), add a baby, stop following one"
  - "P003b: pregnancy records about me or one or more babies (scan, measurements, document)"
  - "P003b: birth turns the baby's prenatal profile into the child's profile, keeping its id and chosen records; ending a pregnancy keeps every record"
---

# pregnancy

A pregnancy the account holder tracks on their own (self) profile, the
babies it carries, and what is recorded along the way. Each baby is its own
Personal Health partition from the start: a **prenatal** `health_profile`
pointing back to the pregnancy (`pregnancy_id`, `sequence`). Birth keeps that
profile's id and turns it into a dependent, so the prenatal records become the
child's earliest history. Everything stays on the device.

## Rules

- The pregnancy closes itself once no baby is still followed: outcome
  `birth` if any baby was born, otherwise `ended` (design `mcSettle`).
- Ending the pregnancy (loss) closes it and every baby still followed; every
  record is kept.
- Stopping following one baby closes that baby's profile only.
- No fetal sex is recorded before birth.
- At birth, records about that baby that are not ticked to move are detached
  from the child (the link is soft-deleted); the record stays on the pregnancy.
- Items are soft-deleted only.

## Layers

- `domain/` — `Pregnancy` (start, next visit, end, settle), `PregnancyInfo`
  (week, day, trimester, days left — injected clock), `PregnancyItem`,
  `PregnancyBaby` (read model of a prenatal profile) and `BabyLabel`,
  `BirthDetails`.
- `application/` — `PregnancyBabiesPort` (the babies' profiles; the profile
  module owns them, so the app shell binds this port — this module never
  imports profile or family) and `PregnanciesDataSource`; use cases to start,
  add a baby, stop following one, end, record a birth, attach an item and set
  the next visit.
- `infrastructure/drift/` — `DriftPregnanciesDataSource` over `pregnancy`,
  `pregnancy_item` and `pregnancy_item_baby`, partitioned by the mother's
  `health_profile_id`.
- `presentation/` — Riverpod providers the app shell's screens watch.

The screens are ported in the app shell (`app/lib/balsm_app/screens/pregnancy/`),
behind the `mother_child` flag. Weekly guidance is not ported (placeholder
partner content), nor are visit reminders (no reminder scheduler yet).
