# Self-report / check-in + body map + care directory — Design

**Date:** 2026-07-24 · **Status:** approved, Spec A in implementation

Restores three patient-app features descoped in commit `9eee1fe` (P001 MVP
gating), which had conflated *symptom self-logging* (a journal) with the
spec's *symptom checker* non-goal (a CDS/advice tool). Self-logging, a body
map, and provider discovery are not clinical-decision-support and are restored
here with real backends.

Two independent specs. **Spec A ships first** (pure Flutter + on-device, no
backend blocker). Spec B follows.

---

## Spec A — Self-report / check-in + body map (PHI, on-device)

New Flutter module **`modules/self_report/`** (new bounded context).
Profile-scoped from day one via core's `ProfileDataSource` contract →
dependants-ready for free.

### Domain
- Aggregate **`CheckIn`** — `id, healthProfileId, recordedAt, mood, painLevel,
  painRegions: Set<BodyRegion>, symptoms: Set<SymptomId>, vitals: Vitals,
  note, photoRecordId?`.
- Value objects: `CheckInId`, `Mood` (1–5), `PainLevel` (0–10),
  `SymptomId` (curated, i69n label), `BodyRegion` (hotspot catalog: id +
  i69n label + cx/cy for rendering, front/back), `Vitals` (all nullable: BP
  sys/dia, heart rate, temperature, weight, SpO₂, glucose fasting/meal/random).
- Event `CheckInSaved`.

### Persistence — SQLCipher, on-device only, NO server endpoint
- Tables: `check_in` (+ `health_profile_id`, vitals as columns, `photo_record_id`),
  child `check_in_symptom`, `check_in_pain_region`.
- Port `CheckInsDataSource extends ProfileDataSource<CheckInId, CheckIn>`;
  impl `DriftCheckInsDataSource`.
- Added to the encrypted backup snapshot (`snapshot_service` `_tables`, FK
  order) → cross-device via backup blob only.

### Reuse (no duplication)
- Check-in's meds-taken/skipped step → real `recordDoseOutcomeUseCase`
  (writes actual `dose_events`), NOT a copy.
- Photo → records vault (`RecordDocument`, type `checkin_photo`); check-in
  stores only the `RecordDocumentId`.
- `self_report` owns only mood/pain/symptoms/vitals/note.

### Application
- `SaveCheckInUseCase`, `ListCheckInsUseCase`, riverpod providers
  (`checkInsDataSourceProvider`, `saveCheckInUseCaseProvider`,
  `checkInHistoryProvider`).

### Presentation
- Restore `report_flow.dart` (multi-step: mood → vitals → meds → pain+body
  map → symptoms → note → summary) + `body_map.dart`, rewired: mock
  `kMeds`/`kVitals` → real medications provider + typed `Vitals`; body map
  feeds `painRegions`; save via `SaveCheckInUseCase`.
- Entry point: restore the **`(+)` quicklog FAB** in the shell tab bar.
- Minimal check-in **history** read; full trends charts (`trends_screen.dart`)
  = stretch / follow-up.

### Security / governance
PHI → on-device only, never logged, backup-blob only. Nothing here is AI, but
the AI-governance PHI invariants are honored regardless.

---

## Spec B — Care directory (non-PHI, real backend) — detailed after A

### .NET `Balsm.CareDirectory` bounded context
- `CareProvider` (name, type clinic/pharmacy/hospital/lab, lat/lng, address,
  phone, hours, country) — non-PHI.
- EF table `care_provider`; **`GET /care/providers?north&south&east&west&type&q`**
  — bounding-box query (client sends the map **viewport**, never the user's
  exact coordinates).
- GCC seed migration (EG/SA/AE).

### Flutter `modules/care_directory/`
- Port `CareProvidersApi` + dio impl → `/care/providers`.
- Restore `map_screen.dart` (flutter_map/OSM tiles + Geolocator for centering
  only), markers from the real API, list view.
- Restore the **`map` tab**.

### Net UI effect (after both)
Tab bar returns to the design's full `home · map · (+) · meds · profile`.

---

## Testing
- self_report: value-object tests + drift round-trip + backup round-trip
  (mirrors meds/profile suites).
- care directory: API handler + bbox query test + seed verification.

## Out of scope (still)
No symptom *checker* / CDS / advice, no drug-interaction, no AI. Self-report is
a journal; care directory is discovery only.
