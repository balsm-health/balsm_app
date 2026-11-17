# Balsm Product Report — 10–16 Nov 2026

**Product:** Balsm patient app (PostHog project "Balsm App", id 286220, EU cloud)
**Window:** 10–16 Nov 2026 (7 full days, Africa/Cairo) vs 3–9 Nov 2026. 30-day trend used for context.
**Internal-user filter:** applied to every query (cohort 254064 "Internal / Test users"), **but it matches 0 people**, so internal and test traffic is still in every number below. See Critical #3.
**Sample size:** every group in this report is under 100 users. **No comparison is statistically testable.** All deltas are "too little data". Read them as directional.

---

## 1. Executive summary

- **State:** very early product with a tiny audience. 80 people did something past app open this week (52 last week). Only **6 people** did a core health action (check-in, quick log, dose, medication, profile, emergency QR), up from 3.
- **Biggest problem:** the shipped build (0.8.0 build 29) **still sends medication names to PostHog** on `medication.added`, even though `main` documents that leak as fixed. This is a live PHI leak (Critical #1).
- **Second biggest problem:** analytics identity is broken. **None of the 45 people who installed in the last 14 days can be followed past install.** Every later event goes to a different person, so no install → sign-up → activation funnel can be measured.
- **Biggest win:** app errors fell **199 → 48 events (−75.9%)**, and the whole active base is now on 0.8.0 (0.1.0 was last seen on 9 Nov). Error volume comes from 1–3 devices either way.
- **Top recommendation:** this week, hotfix the PostHog path so only allowlisted props go out (drop `name`, `userId`, `user_id`, `jti`), and delete the leaked property history in PostHog. Then fix identity stitching before trusting any funnel.

## 2. Critical

1. **PHI leak: `medication.added` → property `name` holds the medication name.**
   - Facts: 9 of 9 events in the last 30 days have it filled in (8 people). It came from builds 0.1.0 b7 and **0.8.0 b29 (the current build)**, Android and iOS, last seen 12 Nov. Values were not read or reproduced. ([query](https://eu.posthog.com/project/286220/sql?open_query=SELECT%20toDate%28timestamp%29%20AS%20day%2C%20toString%28properties.%24app_version%29%20AS%20ver%2C%20toString%28properties.%24app_build%29%20AS%20build%2C%20toString%28properties.%24os%29%20AS%20os%2C%20length%28coalesce%28toString%28properties.name%29%2C%27%27%29%29%20%3E%200%20AS%20has_name%20FROM%20events%20WHERE%20timestamp%20%3E%3D%20now%28%29%20-%20INTERVAL%2030%20DAY%20AND%20event%20%3D%20%27medication.added%27%20ORDER%20BY%20day))
   - Interpretation: `packages/balsm_api/.../non_phi_allowlist.dart` on `main` says `name` was removed from the allowlist for exactly this reason. Other keys that are *not* on the allowlist also reach PostHog: `userId`, `user_id`, `medicationId`, `checkInId`, `jti`, `occurredAt`. That suggests the PostHog sink in build 29 does not apply the allowlist at all, or build 29 was cut before the fix. `EventBusAnalyticsForwarder` forwards `event.toJson()` verbatim.
   - Related: `medication.added.userId` and `health_profile_updated.user_id` attach account IDs to health events. `emergency_qr_token_minted.jti` sends the emergency-QR token ID, which is security-sensitive.
2. **Tracking broken: install events are orphaned.** All 45 installers (24 this week, 21 last week) have only `Application Installed`, plus `Application Opened` on Android, under their person ID, and nothing else. All 28 people who accepted the disclosure have zero install events. Activation, time-to-convert and acquisition attribution can't be computed. ([query](https://eu.posthog.com/project/286220/sql?open_query=SELECT%20person_id%2C%20countIf%28event%3D%27Application%20Installed%27%29%20AS%20inst%2C%20countIf%28event%3D%27disclosure_accepted%27%29%20AS%20disc%2C%20countIf%28event%3D%27user_signed_in%27%29%20AS%20signin%2C%20count%28%29%20AS%20total%20FROM%20events%20WHERE%20timestamp%20%3E%3D%20toDateTime%28%272026-11-02%2022%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-16%2022%3A00%3A00%27%29%20AND%20person_id%20IN%20%28SELECT%20person_id%20FROM%20events%20WHERE%20event%20IN%20%28%27Application%20Installed%27%2C%27disclosure_accepted%27%29%20AND%20timestamp%20%3E%3D%20toDateTime%28%272026-11-02%2022%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-16%2022%3A00%3A00%27%29%29%20GROUP%20BY%20person_id%20ORDER%20BY%20inst%20DESC))
3. **The internal-user filter is a no-op.** The cohort is defined on `$internal_or_test_user = true`. That property doesn't exist in the project, and the cohort count is 0. ([query](https://eu.posthog.com/project/286220/sql?open_query=SELECT%20count%28%29%20FROM%20persons%20WHERE%20properties.%24internal_or_test_user%20%3D%20true)) No email or `is_internal` person property exists either, so team and store-review traffic can't be excluded. With this few users, a handful of team devices can dominate. For example, one Android device produced 40 of this week's 48 errors.

## 3. KPI scorecard

Targets were not set in the routine config, so target status is "n/a". Rows are unique people unless stated.

| Metric | 10–16 Nov | 3–9 Nov | Δ abs | Δ % | Significance | Target | Note |
|---|---|---|---|---|---|---|---|
| Core-active users (north-star proxy) | 6 | 3 | +3 | +100% | too little data | n/a | provisional definition, see appendix |
| Engaged users (any event beyond app lifecycle) | 80 | 52 | +28 | +53.8% | too little data | n/a | inflated by orphaned identities |
| Persons with any event | 109 | 75 | +34 | +45.3% | too little data | n/a | includes 24 install-only orphans |
| Installs (`Application Installed`) | 24 | 21 | +3 | +14.3% | too little data | n/a | store installs not visible |
| Signed in | 17 | 12 | +5 | +41.7% | too little data | n/a | |
| Disclosure accepted | 14 | 11 | +3 | +27.3% | too little data | n/a | |
| Week-over-week return (signed in 3–9 Nov → any activity 10–16 Nov) | 4 / 12 = 33% | — | — | — | too little data | n/a | |
| Check-in completion (completed ÷ started, 14d) | 6 / 10 = 60% | — | — | — | too little data | n/a | 5 abandoned at step 0 |
| Quick-log save rate (saved ÷ opened, 14d) | 3 / 11 = 27% | — | — | — | too little data | n/a | biggest feature drop-off |
| `app_error` events | 48 | 199 | −151 | −75.9% | too little data | n/a | 4 vs 3 affected users |
| Users with a fatal error | 0 | 1 | −1 | — | too little data | n/a | crash-free not measurable (no `$exception`) |
| Users with rage clicks | 10 | 10 | 0 | 0% | too little data | n/a | iOS only |
| `session_expired` users | 13 | 8 | +5 | +62.5% | too little data | n/a | exactly 1 per person, see Findings |

([KPI query](https://eu.posthog.com/project/286220/sql?open_query=SELECT%20if%28timestamp%20%3E%3D%20toDateTime%28%272026-11-09%2022%3A00%3A00%27%29%2C%20%27cur%27%2C%20%27prev%27%29%20AS%20period%2C%20uniq%28person_id%29%20AS%20any_event_users%2C%20uniqIf%28person_id%2C%20event%20NOT%20IN%20%28%27Application%20Installed%27%2C%27Application%20Opened%27%2C%27Application%20Backgrounded%27%2C%27Application%20Updated%27%29%29%20AS%20engaged%2C%20uniqIf%28person_id%2C%20event%20IN%20%28%27checkIn.saved%27%2C%27check_in_completed%27%2C%27quick_log_saved%27%2C%27dose.taken%27%2C%27dose.skipped%27%2C%27medication.added%27%2C%27health_profile_updated%27%2C%27emergency_qr_token_minted%27%29%29%20AS%20core_active%2C%20uniqIf%28person_id%2C%20event%3D%27Application%20Installed%27%29%20AS%20installs%2C%20uniqIf%28person_id%2C%20event%3D%27user_signed_in%27%29%20AS%20signin%2C%20countIf%28event%3D%27app_error%27%29%20AS%20errors%2C%20uniqIf%28person_id%2C%20event%3D%27app_error%27%29%20AS%20error_users%20FROM%20events%20WHERE%20timestamp%20%3E%3D%20toDateTime%28%272026-11-02%2022%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-16%2022%3A00%3A00%27%29%20GROUP%20BY%20period))

## 4. Version comparison

Release timeline (from first and last event seen): 0.1.0 b7 (3 Oct → last seen 9 Nov), then dev and test builds 0.1.2–0.5.0 (23–30 Oct, mostly Android, 1–18 users each), then **0.8.0 b29 (first seen 30 Oct)**. This week 0.8.0 holds **100%** of active users (iOS 59, Android 50).

| Metric | 0.1.0 | 0.8.0 | Δ | Significance |
|---|---|---|---|---|
| Share of active persons, 10–16 Nov | 0% | 100% | — | — |
| `app_error` events, 3–9 Nov | 10 (1 user, iOS) | 189 (5 users) | — | too little data |
| `app_error` events, 10–16 Nov | — | 48 (4 users) | — | too little data |
| Fatal errors, 3–9 Nov | 0 | 1 (iOS) | — | too little data |

You can't compare funnels or retention by *first* version, because identity is broken (Critical #2). Two or three versions of history don't exist in usable volume.

**Verdict: SHIP (keep 0.8.0)**, with a hotfix build for the PHI leak. There's no evidence of a regression, and errors fell. 0.8.0 is also the build that leaks, so a new build is needed, not a rollback: 0.1.0 leaks too. No outdated version holds more than 10% of users, so no update prompt is needed.

## 5. Platform comparison (10–16 Nov)

| Metric | iOS | Android | Web | Desktop | Best→worst gap | Significance |
|---|---|---|---|---|---|---|
| Persons with any event | 59 | 50 | 0 | 0 | — | too little data |
| Installs | 15 | 9 | — | — | — | too little data |
| Core-active users | 2 | 4 | — | — | — | too little data |
| Signed in | 9 | 8 | — | — | — | too little data |
| Users with errors / error events | 1 / 1 | 3 / 47 | — | — | — | too little data |
| Rage-click users | 10 | 0 | — | — | — | too little data |

([platform query](https://eu.posthog.com/project/286220/sql?open_query=SELECT%20if%28timestamp%20%3E%3D%20toDateTime%28%272026-11-09%2022%3A00%3A00%27%29%2C%20%27cur%27%2C%20%27prev%27%29%20AS%20period%2C%20toString%28properties.%24os%29%20AS%20os%2C%20uniq%28person_id%29%20AS%20users%2C%20uniqIf%28person_id%2C%20event%20IN%20%28%27checkIn.saved%27%2C%27check_in_completed%27%2C%27quick_log_saved%27%2C%27dose.taken%27%2C%27dose.skipped%27%2C%27medication.added%27%2C%27health_profile_updated%27%2C%27emergency_qr_token_minted%27%29%29%20AS%20core_users%2C%20uniqIf%28person_id%2C%20event%3D%27Application%20Installed%27%29%20AS%20installs%2C%20uniqIf%28person_id%2C%20event%3D%27app_error%27%29%20AS%20err_users%2C%20countIf%28event%3D%27app_error%27%29%20AS%20errs%2C%20uniqIf%28person_id%2C%20event%3D%27%24rageclick%27%29%20AS%20rage%20FROM%20events%20WHERE%20timestamp%20%3E%3D%20toDateTime%28%272026-11-02%2022%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-16%2022%3A00%3A00%27%29%20GROUP%20BY%20period%2C%20os))

- **Web and desktop send nothing.** There are zero posthog-js events in 30 days, and only one macOS user (3–9 Nov). Either web and desktop analytics aren't wired, or nobody uses them.
- **iOS:** 18 users raised 33 rage clicks over 14 days, all with `$screen_name = "Flutter"`, so the screen can't be located. iOS installs also log no `Application Opened` under the install person. That's the orphan pattern again.
- **Android:** 40 of 47 errors came from one device (minified type `_fbb`). Stack traces are obfuscated, so upload symbols.
- **Cross-platform journeys** can't be measured: identity is split even within a single device.
- **Where to focus:** iOS rage clicks, once screen names exist.

## 6. Growth & engagement

- **Top of funnel:** not measurable, because install events can't be joined to later steps. Only 1 person in the project carries UTM properties.
- **Markets (persons, this week):** Egypt 51 (5 core-active), Saudi Arabia 38 (1 core-active, but the most installs: 12), Germany 10, other 10. Saudi Arabia drives installs while Egypt drives usage. Interpret with care: GeoIP, and internal traffic isn't excluded.
- **Language:** `preferred_language` comes back redacted from PostHog, so there's no ar/en split.
- **Search, notifications, consent opt-out:** not instrumented (see §12).
- **Churn risk:** the defined churn window needs 30 days of stable identity. Not computable.

## 7. Findings

1. **Quick log is opened far more than it's completed.** 11 people opened it and 3 saved (27%) over 14 days. Check-in completes at 60% (6 of 10), and 5 of the 6 abandonments happen at step 0. *Likely reason:* the first step asks too much before any value appears, but that's unverified. *Confidence: low* (n ≤ 11). ([query](https://eu.posthog.com/project/286220/sql?open_query=SELECT%20event%2C%20toString%28properties.step%29%20AS%20step%2C%20count%28%29%20AS%20n%2C%20uniq%28person_id%29%20AS%20users%20FROM%20events%20WHERE%20timestamp%20%3E%3D%20toDateTime%28%272026-11-02%2022%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-16%2022%3A00%3A00%27%29%20AND%20event%20IN%20%28%27check_in_started%27%2C%27check_in_step_viewed%27%2C%27check_in_abandoned%27%2C%27check_in_completed%27%2C%27quick_log_opened%27%2C%27quick_log_saved%27%2C%27session_expired%27%29%20GROUP%20BY%20event%2C%20step%20ORDER%20BY%20event%2C%20step))
2. **`session_expired` fires exactly once per person** (21 events, 21 people, 14d). Each expiry seems to land on a fresh person ID, which points to the same identity reset problem. *Confidence: medium.*
3. **`screen_view` is useless for paths.** 100% of events have `route = "/"` with action push or pop. No path, drop-off-screen or feature-adoption-by-screen analysis is possible. *Confidence: high.*
4. **Offline batching is real.** Median ingestion lag is about 10–20 s, but p95 reached 22 h on 14 Nov and 15 h on 6 Nov. The last 2 days of the window (15–16 Nov) are preliminary.

## 8. UX friction from session replays

102 recordings exist for the window (71 distinct IDs), but every one reports 0 clicks and 0 active seconds. Mobile replay is masked and limited to the sign-in screens (per #137), so they show no friction signal. **No recordings were watched this run.** No friction claims are made from replay.

## 9. Experiments & flags

- No experiments, surveys or annotations exist.
- Flags: `sync` is at 100% (a cleanup candidate: remove the flag from code). `sync_care` and `beta_banner` are at 0% (decide whether to kill them). No `$feature_flag_called` events arrive, so flag exposure can't be checked. Recommendation only; nothing was changed.

## 10. Recommendations (impact × confidence ÷ effort)

1. **Hotfix the telemetry PHI leak (S).** Make the PostHog sink pass props through `kTelemetryAllowlist`, and add a test that `MedicationAdded` produces no `name` or `userId` on the PostHog path. Ship as 0.8.1. Then, as PostHog owner, delete the `medication.added` events and their `name` property history. *Validate:* zero events with `properties.name` on `medication.added` from the new build within 7 days.
2. **Fix identity stitching (M).** Don't `reset()` or regenerate the anonymous ID before `identify`. Make sure install and lifecycle events and the first screens share the distinct_id that later calls `identify`. *Validate:* at least 80% of new installers have a later `screen_view` on the same person_id, measured over a 14-day cohort.
3. **Make the internal filter real (S).** Set `$internal_or_test_user: true` as a person property for team and review accounts (by account ID on sign-in, no email needed). *Validate:* the cohort count is above 0, and this report shows it.
4. **Send real route names in `screen_view` and `$screen_name` (S).** Use go_router's location template (no IDs). That unlocks paths, rage-click location and feature adoption.
5. **Quick-log step 0 study (M, after #2–4).** Hypothesis: pre-filling the category raises the save rate from about 27% to at least 45%. It needs about 100 openers per arm, which takes months at today's volume, so use qualitative interviews first.

## 11. Follow-up on last report

No previous report was found. The routine's "previous report" location isn't configured, and this container is ephemeral. This is the baseline.

## 12. Instrumentation gaps (no PHI)

- `signup_started` / `signup_completed` {method, platform}, `onboarding_step_viewed` {step}, `onboarding_completed` {duration_ms}
- `push_permission_result` {granted: bool, platform}, `notification_opened` {type}
- `search_performed` {surface, result_count bucket}. Never send the query text unless it's a vetted non-PHI facility term.
- `analytics_consent_changed` {enabled}, needed to measure opt-out share
- Crash capture: `$exception` via the SDK, plus Dart symbol upload (`_fbb`, `_ZZa` and others are minified)
- Web: posthog-js init, with `release` and `platform` super properties
- Super properties on every event: `platform`, `market` (EG/GCC from account jurisdiction), `locale` bucket ar/en (unredacted, non-PHI)

## 13. Questions for the team

- Which devices and accounts belong to the team or store reviewers? They're probably a large share of today's 80 people.
- Was build 29 cut before the allowlist fix (#103/#135), or does the PostHog sink skip the allowlist?
- Is web or desktop live for patients? If so, why is there no posthog-js traffic?
- What are the official targets, north-star definition and key journeys? The routine template was left blank.

---

## Appendix

**Metric definitions** (the routine left these blank, so these are provisional; confirm them and they'll stay fixed):
- *Active (core) user:* did ≥1 of `checkIn.saved`, `check_in_completed`, `quick_log_saved`, `dose.taken`, `dose.skipped`, `medication.added`, `health_profile_updated`, `emergency_qr_token_minted` in the window.
- *Engaged user:* any event other than `Application Installed/Opened/Backgrounded/Updated`.
- *Activated user:* first core action within 7 days of sign-up. **Not computable** (identity split).
- *Churned user:* active in the previous 30 days, inactive for the last 14. **Not computable reliably** (identity split, under 30 days of stable data).

**Filters:** timezone Africa/Cairo (the project is set to UTC; windows were converted: 2026-11-09 22:00Z to 2026-11-16 22:00Z vs the 7 days before). Internal cohort 254064 applied, matching 0 people. No store-review exclusion was possible. The window is rolling 7 days, not Sat→Fri, as the routine asked for "last 7 days".

**Data quality:** `$app_version` is present on 100% of events in the window. `$os` and `$lib` are present (posthog-flutter only). Person properties include GeoIP city, postal code and lat/long even though `anonymize_ips` is on (not PHI, but precise location for a health app: consider turning off GeoIP enrichment). `preferred_language` and `country_code` on `disclosure_accepted` come back redacted. Ingestion lag p95 ranged up to 22 h.

**Calendar:** 10–16 Nov 2026 doesn't overlap Ramadan, Eid, or an Egyptian or Saudi national holiday. No campaigns were listed in the config, and no annotations exist in PostHog.

**Not instrumented / empty:** search, push notifications, surveys/NPS, experiments, `$exception`, web analytics and web vitals, heatmaps, consent events, acquisition source (UTM on 1 person).

**Key queries:** linked inline above (PostHog SQL editor, EU cloud, project 286220).
