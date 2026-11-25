# Balsm Product Report — 18–24 Nov 2026 (vs 11–17 Nov)

PostHog project **Balsm App (286220)** · Africa/Cairo days · generated 25 Nov 2026 by the scheduled product-analyst routine.
**Filters on every query:** internal/test cohort 254064 excluded **and** simulator/emulator traffic (`$is_emulator = true`) excluded. See Critical #1 for why the second filter was needed. All counts are PostHog "persons" unless stated.

> **Read this first:** the real (non-simulator) audience is small: **54 weekly users and 4 users doing a health action this week**. Almost no comparison here clears the ~100-users-per-group bar, so most results are marked *too little data*. Nov 23–24 are preliminary (offline batching).

## 1. Executive summary

- **State:** real weekly users **halved, 111 → 54 (−51%)**. Users doing a core health action fell **7 → 4**, and installs fell **26 → 10**. The headline dashboards show the opposite (≈330 users this week) because ~280 of them are **iOS-simulator test runs**.
- **Biggest win:** none we can stand behind. New-user 7-day activation went 3.0% → 7.8%, but that is 3 → 4 people (p = 0.18).
- **Biggest problem:** **analytics can't be trusted yet.** Simulator traffic isn't filtered (the internal cohort has 0 members), screen names are all `/`, error types are obfuscated, and one install turns into several "persons". Product decisions made off the current dashboards would be wrong.
- **Latest version (0.8.0):** **ship / keep.** There is no significant regression against 0.1.0 on sign-in, activation, D1/D7 or errors (every p > 0.2). It runs on 100% of real active users.
- **Top recommendation:** exclude simulators and debug builds from PostHog **at the source**, and backfill the test cohort. That fixes every number in the next report.

## 2. Critical

1. **Tracking contaminated by simulator/test traffic: 278 of 313 iOS "users" this week are simulators.** iOS simulator events (`$device_model = arm64`, iOS 26.5, `$is_emulator = true`, Cairo IP) ran in bursts on Nov 19 (73 users), Nov 20 (169) and Nov 22 (39). In those bursts they produced 49 installs, 29 `medication.added` and dozens of sign-ins. The internal cohort *Internal / Test users* (254064) matches **0 persons**, so the default "filter test accounts" toggle removes nothing. The bursts look like the screenshot automation in `docs/screenshots.md` (`tool/docshots.dart`, booted simulator, fresh install each run). That is *suspected*, not verified. ([query][q-emu])
2. **PHI audit: no leak found.** `medication.added.name` reaches PostHog, but all 45 values since 30 Sep are the redaction placeholder, so the scrub works. `app_error.log_message` has 7 distinct short code-like strings, with no digits ≥ 8, no `@` and no Arabic text. Provider, country, language and disclosure fields arrive as `[redacted]`. Two keys are worth removing at the source rather than relying on redaction: `medication.added.name` and `health_profile_updated.user_id`.
3. **No crash cluster.** 2 real users hit `app_error` this week (21 events). Android shows a higher error-user rate (below), but 1–2 devices drive it.

## 3. KPI scorecard (real users only)

The prompt's target placeholders were never filled in, so **target status = n/a**. Definitions are in the appendix.

| Metric | Prev (11–17 Nov) | Current (18–24 Nov) | Δ | Sig. | Note |
|---|---|---|---|---|---|
| Weekly users (any event) | 111 | 54 | −57 (−51%) | too little data | iOS 59→35, Android 52→19 |
| **North star: weekly core-action users** | 7 | 4 | −3 (−43%) | too little data | check-in / quick-log / meds / dose / profile |
| Installs (`Application Installed`) | 26 | 10 | −16 (−62%) | too little data | ≥ 20% move, no annotation or campaign found |
| Sign-ins (users) | 16 | 9 | −7 (−44%) | too little data | |
| New users → signed in | 12.0% (12/100) | 13.7% (7/51) | +1.7 pp (+14%) | not sig. (p = 0.76) | |
| New users → activated ≤ 7 d | 3.0% (3/100) | 7.8% (4/51) | +4.8 pp (+161%) | not sig. (p = 0.18) | current is preliminary |
| Check-in start → completed | 75% (6/8) | 29% (2/7) | −46 pp (−62%) | too little data (p = 0.07) | |
| Users with `app_error` | 4 | 2 | −2 | too little data | |
| Rage-click users | 13 | 6 | −7 | too little data | |
| 30-day weekly trend (users) | 202 → 75 → 111 → **54** | | | | decline since launch week (28 Oct) |

## 4. Version comparison (by first version used, all-time cohorts since 25 Sep)

0.8.0 (first seen 30 Oct Android / 31 Oct iOS) has fully replaced 0.1.0 (last seen 9 Nov). The 0.1.2–0.5.0 builds were Android-only, live for 1–2 days each (24–30 Oct), and are excluded. N-2 = n/a.

| Metric | 0.1.0 (n = 555) | 0.8.0 (n = 262) | Δ pp | Δ % | Sig. |
|---|---|---|---|---|---|
| Disclosure accepted | 9.7% | 12.6% | +2.9 | +29% | not sig. (p = 0.22) |
| Signed in | 12.4% | 13.0% | +0.5 | +4% | not sig. (p = 0.83) |
| Activated ≤ 7 d | 3.2% | 4.2% | +1.0 | +29% | not sig. (p = 0.49) |
| Seen again after D1 | 5.6% | 3.8% | −1.8 | −32% | not sig. (p = 0.28) |
| Seen again after D7 | 3.1% | 1.4% (n = 211) | −1.6 | −54% | not sig. (p = 0.20) |
| Users with an error | 1.4% | 1.1% | −0.3 | −21% | not sig. (p = 0.73) |

The D1/D7 dip is directional only. 0.8.0 cohorts have had less time to return, and identity fragmentation hits both versions. **Verdict: ship / keep 0.8.0.** No outdated version holds ≥ 10% of active users, so no update prompt is needed.

## 5. Platform comparison (new users first seen in the last 30 days)

| Metric | iOS (n = 234) | Android (n = 202) | Web | Desktop | Gap (pp) | Sig. |
|---|---|---|---|---|---|---|
| Share of weekly users (current) | 35 | 19 | 0 | 0 | — | — |
| Disclosure accepted | 15.8% | 7.4% | — | — | 8.4 | **significant (p = 0.007)** |
| Signed in | 15.8% | 9.9% | — | — | 5.9 | not sig. (p = 0.07) |
| Activated ≤ 7 d | 2.6% | 5.4% | — | — | 2.9 | not sig. (p = 0.12) |
| Active on 2+ days | 3.8% | 6.9% | — | — | 3.1 | not sig. (p = 0.15) |
| Users with error (all-time cohorts) | 0.7% (3/412) | 3.3% (15/458) | — | — | 2.5 | significant (p = 0.008), but driven by 1–2 devices |

- **Android** loses more people before the disclosure screen: 7.4% vs 15.8% accept it. Android "persons" also average fewer events (4.5 vs 12.8 on 0.1.0), which fits more fragmented or abandoned anonymous IDs. Market and language can't be split because `country_code` and `preferred_language` are redacted, so an audience difference can't be ruled out.
- **Android errors:** one device sent 40 `_fbb` errors on 14 Nov, and one sent 20 `_ClientSocketException` this week (offline/network). The type names are obfuscated, so they can't be traced to code. ([query][q-err])
- **Web/desktop:** no web traffic (`posthog-js` absent). Desktop is one macOS user in 30 days. Not instrumented or not used.
- **Cross-platform users:** can't be measured. Only 48 persons were ever identified, so most users never link across devices.
- **Where to focus:** Android's install → disclosure step.

## 6. Growth & engagement

- **Top of funnel (real users, current week):** 10 installs → 7 disclosures → 9 sign-ins. Store impressions and installs aren't visible in PostHog, and no UTM/acquisition data was captured.
- **Search / zero-result terms:** not instrumented (no search event).
- **Notifications:** not instrumented (no permission or push-open events).
- **Churn risk:** **20 of 22** users who did a core action between 11 Oct and 10 Nov have been silent 14+ days (Android 12/14, iOS 8/8). Their last events were passive (`Application Opened` / `Backgrounded` / `screen_view`, plus one `$rageclick`). Fragmentation may inflate this count, since a returning user can show up as a new person.
- **Consent opt-out share:** can't be measured. With `optOut` on, the SDK sends nothing, and no consent-change event exists.
- **Features (30 days, real users):** quick-log opened 20 users, check-in started 19, nearby-locate 5 (all `found`), dose logged 4, emergency QR 4 or fewer, medication added ~5 real users. Every core feature is used by fewer than 20 people.

## 7. Findings

1. **Check-in is the weakest step.** Over 30 days, 19 users started a check-in and 12 abandoned at **step 0**. Only 12 viewed step 1, and 9 completed. Likely cause: step 0 asks too much, or users only wanted a quick look. *Confidence: medium.* ([query][q-ci])
2. **The audience is shrinking after the launch spike.** Weekly users went 202 (week of 28 Oct, the 0.8.0 rollout) → 75 → 111 → 54, and the 7-day new-user cohorts sign in at only ~13%. *Confidence: medium.* Fragmentation inflates the denominators but not the trend.
3. **Most "users" never get past the welcome flow.** Over all cohorts, ≈ 85% of persons never accept the disclosure. Part of this is real drop-off and part is anonymous-ID churn. *Confidence: low* until identity is fixed.

## 8. UX friction from session replays

Replays are gated and fully masked in code (`maskAllTexts / Images / CustomPaint`), so friction is visible but content is not. These recordings are queued for manual review: real-device sessions that ended in `check_in_abandoned` on 0.8.0:
[iOS 22 Nov](https://eu.posthog.com/project/286220/replay/01a204bf-ad4e-78f1-aecf-16af63ffdb76) · [iOS 22 Nov](https://eu.posthog.com/project/286220/replay/01a20126-526a-7eb2-acf3-8979086c1c2c) · [iOS 19 Nov](https://eu.posthog.com/project/286220/replay/01a1f4a3-c6f7-7601-98e9-9156bb26df1b) · [Android 18 Nov](https://eu.posthog.com/project/286220/replay/01a1ed7b-8a16-751d-8742-7574a866916c) · [Android 17 Nov](https://eu.posthog.com/project/286220/replay/01a1eb72-356a-76d5-9e5d-77db96277c19).
**I did not watch them.** Replay Vision writes data and spends credits, which this read-only routine doesn't allow. Rage-clicks: 6 users this week, 13 last week. No element context exists on Flutter, so they can't be located.

## 9. Experiments & flags

- Experiments: **none**. Surveys: **none**. Annotations: **none**.
- `sync` is at **100%**. Remove the flag once it's stable. `beta_banner` and `sync_care` are at **0%**: decide whether to delete them or launch them. *Recommendation only, no change made.*

## 10. Recommendations (impact × confidence ÷ effort)

1. **Stop test traffic at the source (S).** Disable PostHog when running on a simulator/emulator or in a debug/profile build, or when `docshots` runs (or send `$internal_or_test_user = true`). Also make cohort 254064 match `$is_emulator = true`. *Fixes:* every metric. *Validate:* next week simulator users = 0 and the cohort count > 0.
2. **Fix screen tracking (S).** `screen_view.route` is always `/`, so paths, drop-off screens and feature adoption can't be measured. Send the route *template* (for example `/check-in/:step`), not `/`. *Validate:* ≥ 10 distinct routes next week.
3. **Upload Dart symbol maps for obfuscated builds (S).** Error types like `_gbb` and `_fbb` can't be acted on. *Validate:* top errors show real class names.
4. **Simplify check-in step 0 (M).** For example, prefill it or let the user skip to a one-tap mood. *Expected:* start→complete rises from ~47% (30 days) toward 70%. *Validate:* A/B behind a flag, metric = start→completed, ~100 starters per arm. At current volume that takes about 8–10 weeks, so ship and monitor unless traffic grows.
5. **Fix identity fragmentation (M).** Make sure the anonymous ID persists across launches and that `identify` runs on every sign-in, using an opaque account ID. *Validate:* persons per install falls from ~4.5 toward ~1.

## 11. Follow-up on the last report

There's no previous report. This is the first run. The report is saved to `docs/product-reports/` in balsm_app (branch `claude/dreamy-noether-eqrecc`) for next week's follow-up.

## 12. Instrumentation gaps (no PHI in any property)

- `screen_view` → real `route` template, plus `previous_route`
- `onboarding_step_viewed` / `onboarding_completed` {`step`, `step_index`, `duration_ms`}
- `push_permission_result` {`granted`: bool, `platform`}; `notification_opened` {`notification_type`}
- `analytics_consent_changed` {`enabled`: bool}. Send it *before* opting out, so the opt-out share becomes measurable.
- `sync_failed` / `sync_completed` {`reason_code`, `queued_count`}
- `app_start` {`cold_start_ms`}
- A `market` super-property (`EG` / `GCC`) and `app_language` (`ar` / `en`) that are **not** redacted. Both are coarse, non-PHI, and needed for segmentation.
- Acquisition: store install referrer / UTM on first open.
- Search: `search_performed` {`result_count`}, with only term categories or hashes kept and no free text, unless you approve storing redacted terms.

## 13. Questions for the team

1. What ran on the iOS simulator on 19, 20 and 22 Nov, and is it docshots or E2E?
2. Was there any campaign, store feature or outreach around 28 Oct–1 Nov (the launch spike)?
3. Which store-review accounts exist, so they can be excluded?
4. What are the KPI targets and the official "active user" definition? The prompt's placeholders weren't filled in.
5. Should web (PWA) analytics be enabled? There's no web traffic in PostHog.

---

## Appendix

**Metric definitions (fixed; the prompt's placeholders weren't filled in, so these are the routine's own and need sign-off):**
- *Core action* = `checkIn.saved`, `check_in_completed`, `quick_log_saved`, `medication.added`, `dose.taken`, `dose.skipped`, `health_profile_updated`, `emergency_qr_token_minted` or `nearby_locate`.
- *Active user* = performed a core action in the window.
- *Activated user* = first core action within 7 days of first being seen. (No sign-up event exists, so first-seen is used.)
- *Churned* = core action in the previous 30 days (11 Oct–10 Nov) and no events in the last 14 days.
- *D1 / D7* = any event ≥ 1 / 7 days after first seen.

**Filters:** `person_id NOT IN COHORT 254064` (matches 0 persons) **and** `coalesce($is_emulator, false) = false`. Timezone: Africa/Cairo (UTC+2). Windows: current 18–24 Nov, previous 11–17 Nov, trend 26 Oct–24 Nov. Significance: two-proportion z-test.

**Data quality:**
- Simulator contamination (Critical #1).
- 75 person profiles vs ~456 real persons in 30 days: most events are personless. Only 48 persons were identified. Persons outnumber installs ~4.5×.
- `$app_version` is present on 100% of events, and `$os` on all of them. No `platform` or `release` super-property exists.
- `country_code`, `preferred_language` and `provider` are redacted, so market and language splits aren't possible.
- The PostHog geo-IP country (EG/SA only) is visible but unreliable at this size.
- Ingestion lag: median 0 h, p90 ≤ 6.4 h in the window.
- Android had no events between 21 and 24 Nov. That could be batching or real.

**Calendar:** there's no Ramadan or Eid in the window, and no Egyptian or Saudi public holiday on 18–24 Nov. No campaigns were supplied.

**Key queries:** [simulator split][q-emu] · [weekly KPIs][q-wk] · [check-in funnel][q-ci] · [errors][q-err]

[q-emu]: https://eu.posthog.com/project/286220/sql?open_query=SELECT%20properties.%24os%20AS%20os%2C%20coalesce%28toString%28properties.%24is_emulator%29%2C%27null%27%29%20AS%20emu%2C%20toDate%28toTimeZone%28timestamp%2C%27Africa/Cairo%27%29%29%20AS%20day%2C%20uniq%28person_id%29%20AS%20users%20FROM%20events%20WHERE%20timestamp%20%3E%3D%20toDateTime%28%272026-11-15%2022%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-24%2022%3A00%3A00%27%29%20GROUP%20BY%20os%2C%20emu%2C%20day%20ORDER%20BY%20day
[q-wk]: https://eu.posthog.com/project/286220/sql?open_query=SELECT%20intDiv%28dateDiff%28%27second%27%2C%20toDateTime%28%272026-10-27%2022%3A00%3A00%27%29%2C%20timestamp%29%2C%20604800%29%20AS%20wk%2C%20uniq%28person_id%29%20AS%20wau_any%2C%20uniqIf%28person_id%2C%20event%20IN%20%28%27checkIn.saved%27%2C%27check_in_completed%27%2C%27quick_log_saved%27%2C%27medication.added%27%2C%27dose.taken%27%2C%27dose.skipped%27%2C%27health_profile_updated%27%2C%27emergency_qr_token_minted%27%2C%27nearby_locate%27%29%29%20AS%20wau_core%2C%20uniqIf%28person_id%2C%20event%3D%27Application%20Installed%27%29%20AS%20installs%2C%20uniqIf%28person_id%2C%20event%3D%27user_signed_in%27%29%20AS%20signins%20FROM%20events%20WHERE%20timestamp%20%3E%3D%20toDateTime%28%272026-10-27%2022%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-24%2022%3A00%3A00%27%29%20AND%20coalesce%28properties.%24is_emulator%2C%20false%29%20%3D%20false%20AND%20person_id%20NOT%20IN%20COHORT%20254064%20GROUP%20BY%20wk%20ORDER%20BY%20wk
[q-ci]: https://eu.posthog.com/project/286220/sql?open_query=SELECT%20event%2C%20toString%28properties.step%29%20AS%20step%2C%20uniq%28person_id%29%20AS%20users%20FROM%20events%20WHERE%20event%20IN%20%28%27check_in_started%27%2C%27check_in_step_viewed%27%2C%27check_in_abandoned%27%2C%27check_in_completed%27%29%20AND%20timestamp%20%3E%3D%20toDateTime%28%272026-10-25%2022%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-24%2022%3A00%3A00%27%29%20AND%20coalesce%28properties.%24is_emulator%2C%20false%29%20%3D%20false%20GROUP%20BY%20event%2C%20step%20ORDER%20BY%20event%2C%20step
[q-err]: https://eu.posthog.com/project/286220/sql?open_query=SELECT%20properties.type%20AS%20err_type%2C%20properties.%24os%20AS%20os%2C%20properties.%24app_version%20AS%20version%2C%20count%28%29%20AS%20n%2C%20uniq%28person_id%29%20AS%20users%20FROM%20events%20WHERE%20event%20%3D%20%27app_error%27%20AND%20timestamp%20%3E%3D%20toDateTime%28%272026-10-25%2022%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-24%2022%3A00%3A00%27%29%20AND%20coalesce%28properties.%24is_emulator%2C%20false%29%20%3D%20false%20GROUP%20BY%20err_type%2C%20os%2C%20version%20ORDER%20BY%20users%20DESC
