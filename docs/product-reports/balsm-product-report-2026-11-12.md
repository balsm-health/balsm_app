# Balsm Product Report: 5–11 Nov 2026

**Product:** Balsm patient app (Flutter) · **PostHog project:** Balsm App (286220, EU)
**Window:** Thu 5 Nov – Wed 11 Nov 2026 (Africa/Cairo), compared with 29 Oct – 4 Nov. The 30-day trend covers 13 Oct – 11 Nov.
**Generated:** 12 Nov 2026 by the scheduled *Product Analysis* routine. The internal, test and store-review filter was applied to every query (Appendix A2).

> **Read this first.** PostHog gives the same phone a new ID every time the app is launched (Critical #1). Because of that, every "user" number in PostHog's own tools counts app launches, not people. This report counts **devices** instead, using an approximate device fingerprint (Appendix A1). Device counts this small (under 40 a week) are directional, and **no comparison in this report is statistically significant**.

---

## 1. Executive summary

- **State:** The base is very small and still early. About **27 real devices** were active this week, down from 38 (−29%, not significant). **3 devices** did a core health action, down from 4.
- **Biggest win:** Check-in tracking is live in v0.8.0. For the first time this week we can see check-ins start and finish: 4 started one and 1 finished (counted by person ID).
- **Biggest problem:** The analytics can't follow a person. A sign-out `reset()` also runs on every launch for signed-out and device-only users, so **124 devices showed up as 521 "people"** in 30 days. Until that's fixed, retention, activation and churn can't be measured.
- **Latest version (0.8.0):** **Ship / keep.** It shows no new errors among real users and no significant funnel change against 0.1.0. iOS rage-taps are up (9 of 14 devices that started on 0.8.0, against 25 of 58 on 0.1.0; p=0.15), which is worth watching.
- **Top recommendation:** Stop calling `reset()` at boot. Call it only when a user actually signs out. Then add the missing `user_signed_up`, `provider` and screen-route data, so next week's report can measure real funnels.

## 2. Critical

1. **PHI or privacy leak: none found.** I checked every event's property keys. `medication.added` sends `name`, `userId` and `medicationId` keys, and `health_profile_updated` sends `user_id` and `field_changed`, but in all 10 and 59 events in the last 30 days those values are the scrubber's `[redacted]` placeholder ([check][L_phi]). `$device_name` on Android holds a device codename, not a person's name. The safeguard works, but `MedicationAdded.toJson()` still puts the medication name into the analytics call. The scrubber is the only thing stopping it (see Rec. 4).
2. **Broken tracking: identity resets on every launch.** At boot, `main_balsm.dart:344` calls `analytics.setUser(telemetryUserId(...))`. That returns `null` for signed-out and device-only accounts, and `setUser(null)` calls `Posthog().reset()`. Measured result: 124 device fingerprints map to 521 person IDs, 119 of the 124 devices are split, and one device has 44 IDs ([query][L_identity]). In the 30 days, 93% of IDs (473 of 506) were seen on only one day. Retention, lifecycle, new-vs-returning, activation and churn in PostHog are invalid until this is fixed.
3. **Broken tracking: the sign-up event never arrives.** `user_signed_up` is emitted in code (`sign_up_use_case.dart`) but has **0 events in 30 days**. Sign-up conversion, a core KPI, can't be computed.
4. **Broken tracking: every screen is "/".** All 843 `screen_view` events in the 30 days have `route = "/"`, so paths, drop-off screens and feature adoption by screen are blind.

## 3. KPI scorecard (devices; this week vs last week)

| Metric | This week | Last week | Δ | Significance | Target status | Note |
|---|---|---|---|---|---|---|
| Weekly active devices | 27 | 38 | −11 (−28.9%) | not significant (p=0.17) | — | Egypt 10 (was 21), GCC 14 (was 16) |
| **North star (proxy):** devices with a core action | 3 | 4 | −1 (−25%) | too little data | no target set | 11.1% of active devices (was 10.5%) |
| New devices | 15 | 24 | −9 (−37.5%) | not significant (p=0.15) | — | Installs aren't visible in PostHog |
| New devices that accepted the disclosure (proxy for onboarding) | 60.0% (9/15) | 45.8% (11/24) | +14.2 pp (+31%) | too little data | ex. ≥45%: **on track (provisional)** | Proxy only; the sign-up event is missing |
| New devices that signed in | 6.7% (1/15) | 8.3% (2/24) | −1.7 pp | too little data | — | Most use device-only mode, which can't be told apart (`provider` is redacted) |
| Week-over-week device retention | 13.2% (5/38) | 16.5% (14/85)* | −3.3 pp (−20%) | too little data | ex. D7 ≥25%: **off track** | *Previous base = all devices active before 29 Oct |
| Active devices on ≥2 days in the week | 1 | 5 | −4 | too little data | — | Users mostly open the app once |
| Real-user devices with an `app_error` | 0 | 0 | — | — | ex. crash-free ≥99.5%: **on track, low confidence** | Every error this week came from 3 excluded internal devices; Sentry is the crash source of truth |
| Median session length (iOS / Android) | 6 s / 11.5 s | 11 s / 0 s | — | — | — | 37 of 70 sessions under 10 s this week |

Targets come from the routine template's examples because no project targets are set yet. Please confirm them (Q1).

## 4. Version comparison (devices grouped by the first version they used, measured over each device's first 7 days)

| Metric | 0.1.0 (13–30 Oct) | 0.8.0 (since 30 Oct) | Δ pp | Δ % | Significance |
|---|---|---|---|---|---|
| Devices | 104 | 20 | | | |
| Accepted disclosure (iOS) | 51.7% (30/58) | 57.1% (8/14) | +5.4 | +10.5% | not significant (p=0.72) |
| Did a core action within 7 days | 13.5% (14/104) | 15.0% (3/20) | +1.5 | +11.4% | not significant (p=0.86) |
| D1 return | 11.5% (12/104) | 5.6% (1/18) | −6.0 | −51.9% | too little data (p=0.45) |
| Rage-tapped (iOS) | 43.1% (25/58) | 64.3% (9/14) | +21.2 | +49.1% | not significant (p=0.15) |
| `app_error` (real users) | 6 Android devices | 0 | | | too little data |

There isn't an N-2 column. Builds 0.1.4 to 0.4.1 were seen on 2–8 Android devices each, only on 28–29 Oct, which looks like internal or Play-track testing. 0.8.0 is still marked *Unreleased* in `CHANGELOG.md` but already reaches iOS and Android users.

- **Regressions:** none significant. The iOS rage-tap increase is the one to watch. It is concentrated in **Saudi, mostly Arabic-locale iOS** devices (8 of 14 this week, against 1 of 5 in Egypt; p=0.15), which suggests an RTL or touch-target issue. Confidence: low. Rage-taps are reported only against the whole Flutter view, so the element can't be identified ([query][L_rage]).
- **Verdict on 0.8.0: SHIP / KEEP.** Nothing argues for a rollback.
- **Update prompt:** 0.1.0 still accounts for 3 of 69 person IDs active this week (4%), which is below the 10% threshold. Show the existing app-update prompt once a newer store build is live.

## 5. Platform comparison (this week, devices)

| Metric | iOS | Android | Web | Desktop | Gap | Significance |
|---|---|---|---|---|---|---|
| Active devices | 19 (was 24) | 8 (was 14) | 0 | 0 (macOS: 2 devices in 30 days) | | |
| New devices | 11 | 4 | — | — | | |
| New → disclosure accepted | 7/11 (64%) | 2/4 (50%) | — | — | 14 pp | too little data |
| Devices with a core action | 2 | 1 | — | — | | too little data |
| Retained from last week | 3/24 (12.5%) | 2/14 (14.3%) | — | — | 1.8 pp | too little data |
| Rage-taps | 9/19 devices | 0 | — | — | | iOS only (could be an SDK difference) |
| Median session | 6 s | 11.5 s | — | — | | |

- **Weakest platform: Android.** Active devices fell 43% (14 → 8), and it had the past spikes from automated or test traffic. The **iOS-specific signal** is rage-taps.
- **Web:** no `posthog-js` events at all. Either the web build doesn't send analytics or nobody uses it (Q2).
- **Cross-platform users** can't be counted, because accounts aren't identified consistently (Critical #2).

## 6. Growth & engagement

- **Top of funnel:** 15 new devices this week (24 last week). There's no UTM or acquisition data: the `utm_*` and `initial_*` properties exist on persons but were never filled.
- **Search / unmet demand:** not instrumented. `quick_log_searched` is defined in code but has never been received.
- **Notifications:** not instrumented. There are no push permission, delivery or open events.
- **Churn risk:** **8 devices** did a core action before 29 Oct and have been silent for 14+ days. All were on 0.1.0 (5 Android, 3 iOS), and their last event was a `screen_view` or app open. Because of fragmentation, treat this as a lower bound.
- **Analytics consent opt-out share:** not measurable. When a user opts out, nothing is sent, and there's no opt-out counter event. Unknown share of users invisible.

## 7. Findings

1. **Identity reset at boot fragments every user** (facts: Critical #2). *Why:* `setUser(null)` → `reset()` runs on cold start, not only on sign-out. **Confidence: high**, confirmed in code and data.
2. **Saudi Arabia is now the largest market.** GCC had 14 active devices against Egypt's 10. Egypt fell 21 → 10 (−52%); GCC was 16 → 14. Not significant. *Why:* unknown, as there are no campaign or UTM data. **Confidence: low.**
3. **Engagement is shallow.** Of 27 active devices, 3 did a core action and 1 came back on a second day. The median iOS session lasts 6 s. *Why:* this may be partly the masked-replay or app-switch pattern, or users opening the app without a reason to stay. **Confidence: medium.**
4. **Check-ins are abandoned at step 0.** 4 person IDs started a check-in, 3 abandoned it at step 0 and 1 completed it (first week of data). **Confidence: low** (n=4).
5. **Quick log gets opened from the tab bar but rarely saved.** It was opened by 6 people and saved once (wellbeing). **Confidence: low.**

## 8. UX friction from session replays

I couldn't do this. Replay is by design limited to the sign-in screens, fully masked, and doesn't capture taps (#137). The 20 most recent recordings all show **0 clicks and 0 active seconds**. One example is a [rage-tap session from 10 Nov](https://eu.posthog.com/project/286220/replay/01a1c529-ad92-76f1-b3b2-1a1f0b63e713), which is 44 s long with nothing visible. Replay can't explain friction under the current privacy settings, and that is an accepted trade-off.

## 9. Experiments & flags

- **Experiments:** none. **Surveys:** none created yet, although survey support shipped in #136.
- `sync`: at 100% since 10 Oct. **Recommend cleanup:** remove the flag from code.
- `sync_care` and `beta_banner`: at 0% since 10 and 14 Oct. **Recommend:** either delete them or document why they're parked. I recommend only and did not change anything.

## 10. Recommendations (impact × confidence ÷ effort)

1. **Stop resetting identity at boot.** Call `reset()` only on a real `UserSignedOut`. For device-only accounts, keep PostHog's anonymous ID across launches. *Fixes:* Critical #2. *Expected effect:* person IDs ≈ devices, so retention, activation and churn become measurable. *Effort:* **S**. *Validate:* next week, the ratio of person IDs to device fingerprints should be ≤1.2 (now 4.2).
2. **Fix the missing funnel data.** Make `user_signed_up` arrive (it's probably emitted before the analytics consent or opt-in takes effect). Add `provider` (device / email / google / apple, which are constant values) to `kNonPhiAllowlist`. Send the real route name in `screen_view`. *Fixes:* Critical #3–4. *Effort:* **S–M**. *Validate:* the events and properties appear with more than 0 values within 48 h of release.
3. **Investigate iOS rage-taps for Arabic users in Saudi Arabia.** Test the home, quick-log and check-in screens on an iPhone in Arabic, looking for small tap targets and gestures broken in right-to-left layout. *Fixes:* Finding 2 and §4. *Effort:* **S**. *Validate:* the share of iOS devices with rage-taps (now 47%) drops below 20%. That needs at least 2 weeks at the current volume.
4. **Remove `name` and `userId` from `MedicationAdded.toJson()`'s analytics path.** This adds a second safeguard behind the scrubber. *Effort:* **S**. *Validate:* `medication.added` arrives without the `name` key.
5. **Make the check-in's first step shorter.** Only do this after #1–2 ship and there are at least 30 check-in starts. *Hypothesis:* 3 of 4 abandon at step 0, and showing the first question pre-filled raises completion. Metric: started → completed, with at least 100 starts per arm.

## 11. Follow-up on last report

This is the first run. No earlier report was found, and the report location isn't configured.

## 12. Instrumentation gaps (no PHI)

- `user_signed_up` {provider, step_count}: fix delivery.
- `user_signed_in.provider`: allowlist it. It's an enum, not PHI.
- `screen_view.route`: the real route name, with IDs masked.
- `onboarding_step_viewed` {step, total_steps} and `onboarding_completed` {duration_ms}.
- `push_permission_result` {result}, `notification_opened` {type}.
- `quick_log_searched` {result_count, has_results}: fix delivery, never send the search text.
- `analytics_consent_changed` {enabled}: send it *before* opting out, so the opt-out share can be measured.
- `app_error.type` arrives obfuscated (e.g. `_ZZa`, `_gbb`). Upload symbol maps or send a constant error label.
- Web: confirm whether `posthog-js` is initialized in the web build.

## 13. Questions for the team

1. What are the official targets for activation, D7 retention and crash-free users, and what's the definition of the north star?
2. Is the web app live for patients? It sent no analytics in 30 days.
3. Was there any GCC or Saudi marketing push, or an Egypt push that ended, between 13 Oct and 11 Nov?
4. Where should this report be stored for next week's follow-up? I pushed it to the branch `claude/dreamy-noether-y389x7` for now.
5. Which Discord role should be mentioned for critical items? The role ID isn't configured.

---

## Appendix

**A1. Metric definitions** (the routine template's placeholders weren't filled in, so these are the definitions I used)
- *Device* = a hash of OS, device model, OS version, screen width and height, and GeoIP city. It is approximate: identical phones in one city merge together, and a phone that changes city splits.
- *Active* = any event. *Core action* = `checkIn.saved`, `check_in_completed`, `quick_log_saved`, `medication.added`, `dose.taken`, `dose.skipped`, `health_profile_updated`, `emergency_qr_token_minted` or `nearby_locate`.
- *Activated* = a core action within 7 days of first seen. *Churned* = activated before the last 14 days and silent for the last 14 days.
- *Significance* = two-proportion z-test, or a binomial test for counts. "Too little data" means fewer than about 100 devices per group.

**A2. Filters.** I excluded every person ID that, at any time since 1 Sep, sent an event with `flavor = dev`, `$is_emulator = true`, `$is_testflight = true` or GeoIP country = US (Google Play pre-launch and App Review traffic; for example, 35 US Android devices on 20 Oct, none of which signed in). That removed **114 IDs**. I also excluded cohort 254064 "Internal / Test users". **That cohort matches 0 people**, because no person has `$internal_or_test_user` set, so it currently filters nothing.

**A3. Data quality.**
- Identity fragmentation (Critical #2).
- 93% of person IDs appear on only one day.
- Only 54 person profiles exist; most events don't create a profile.
- Ingestion lag is small (median 11–14 s, p95 ≤111 s, 2 events over 24 h), so offline batching isn't distorting this week.
- 6 Nov had almost no traffic (1 internal device). It isn't an ingestion outage.
- Egypt's daylight-saving time ended on 30 Oct, and the windows use Cairo calendar days.

**A4. Calendar.** No Ramadan, Eid or public holiday in Egypt or KSA in either window. There are no PostHog annotations and no known campaigns.

**A5. Links.** [Daily active trend by OS][L_daily] · [Identity fragmentation][L_identity] · [Rage-taps][L_rage] · [PHI redaction check][L_phi] · [Patient journeys dashboard](https://eu.posthog.com/project/286220/dashboard/1073404) · [Replay list](https://eu.posthog.com/project/286220/replay)

[L_daily]: https://eu.posthog.com/project/286220/sql?open_query=WITH%20excluded%20AS%20%28SELECT%20DISTINCT%20person_id%20FROM%20events%20WHERE%20timestamp%20%3E%3D%20toDateTime%28%272026-09-01%2000%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-12%2002%3A00%3A00%27%29%20AND%20%28toString%28properties.flavor%29%20%3D%20%27dev%27%20OR%20toString%28properties.%24is_emulator%29%20%3D%20%27true%27%20OR%20toString%28properties.%24is_testflight%29%20%3D%20%27true%27%20OR%20toString%28properties.%24geoip_country_code%29%20%3D%20%27US%27%29%29%20SELECT%20toDate%28toTimeZone%28timestamp%2C%27Africa%2FCairo%27%29%29%20AS%20day%2C%20uniq%28person_id%29%20AS%20dau%2C%20uniqIf%28person_id%2C%20toString%28properties.%24os%29%3D%27Android%27%29%20AS%20android%2C%20uniqIf%28person_id%2C%20toString%28properties.%24os%29%20IN%20%28%27iOS%27%2C%27iPadOS%27%29%29%20AS%20ios%20FROM%20events%20WHERE%20timestamp%20%3E%3D%20toDateTime%28%272026-10-12%2021%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-11%2022%3A00%3A00%27%29%20AND%20person_id%20NOT%20IN%20%28SELECT%20person_id%20FROM%20excluded%29%20GROUP%20BY%20day%20ORDER%20BY%20day
[L_identity]: https://eu.posthog.com/project/286220/sql?open_query=WITH%20excluded%20AS%20%28SELECT%20DISTINCT%20person_id%20FROM%20events%20WHERE%20timestamp%20%3E%3D%20toDateTime%28%272026-09-01%2000%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-12%2002%3A00%3A00%27%29%20AND%20%28toString%28properties.flavor%29%20%3D%20%27dev%27%20OR%20toString%28properties.%24is_emulator%29%20%3D%20%27true%27%20OR%20toString%28properties.%24is_testflight%29%20%3D%20%27true%27%20OR%20toString%28properties.%24geoip_country_code%29%20%3D%20%27US%27%29%29%2C%20f%20AS%20%28SELECT%20cityHash64%28concat%28toString%28properties.%24os%29%2C%20%27%7C%27%2C%20toString%28properties.%24device_model%29%2C%20%27%7C%27%2C%20toString%28properties.%24os_version%29%2C%20%27%7C%27%2C%20toString%28properties.%24screen_width%29%2C%20%27%7C%27%2C%20toString%28properties.%24screen_height%29%2C%20%27%7C%27%2C%20coalesce%28toString%28properties.%24geoip_city_name%29%2C%27%27%29%29%29%20AS%20fp%2C%20uniq%28person_id%29%20AS%20n_persons%20FROM%20events%20WHERE%20timestamp%20%3E%3D%20toDateTime%28%272026-10-12%2021%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-11%2022%3A00%3A00%27%29%20AND%20person_id%20NOT%20IN%20%28SELECT%20person_id%20FROM%20excluded%29%20GROUP%20BY%20fp%29%20SELECT%20count%28%29%20AS%20devices%2C%20sum%28n_persons%29%20AS%20person_ids%2C%20countIf%28n_persons%20%3E%201%29%20AS%20split_devices%2C%20max%28n_persons%29%20AS%20max_ids_per_device%20FROM%20f
[L_rage]: https://eu.posthog.com/project/286220/sql?open_query=WITH%20excluded%20AS%20%28SELECT%20DISTINCT%20person_id%20FROM%20events%20WHERE%20timestamp%20%3E%3D%20toDateTime%28%272026-09-01%2000%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-12%2002%3A00%3A00%27%29%20AND%20%28toString%28properties.flavor%29%20%3D%20%27dev%27%20OR%20toString%28properties.%24is_emulator%29%20%3D%20%27true%27%20OR%20toString%28properties.%24is_testflight%29%20%3D%20%27true%27%20OR%20toString%28properties.%24geoip_country_code%29%20%3D%20%27US%27%29%29%20SELECT%20toDate%28toTimeZone%28timestamp%2C%27Africa%2FCairo%27%29%29%20AS%20day%2C%20toString%28properties.%24os%29%20AS%20os%2C%20toString%28properties.%24app_version%29%20AS%20v%2C%20count%28%29%20AS%20rageclicks%2C%20uniq%28person_id%29%20AS%20persons%20FROM%20events%20WHERE%20event%20%3D%20%27%24rageclick%27%20AND%20timestamp%20%3E%3D%20toDateTime%28%272026-10-28%2022%3A00%3A00%27%29%20AND%20timestamp%20%3C%20toDateTime%28%272026-11-11%2022%3A00%3A00%27%29%20AND%20person_id%20NOT%20IN%20%28SELECT%20person_id%20FROM%20excluded%29%20GROUP%20BY%20day%2C%20os%2C%20v%20ORDER%20BY%20day
[L_phi]: https://eu.posthog.com/project/286220/sql?open_query=SELECT%20event%2C%20countIf%28toString%28properties.name%29%20%3D%20%27%5Bredacted%5D%27%29%20AS%20name_redacted%2C%20countIf%28length%28coalesce%28toString%28properties.name%29%2C%27%27%29%29%3E0%29%20AS%20name_any%20FROM%20events%20WHERE%20event%20IN%20%28%27medication.added%27%2C%27health_profile_updated%27%2C%27dose.taken%27%2C%27dose.skipped%27%29%20AND%20timestamp%20%3E%3D%20now%28%29%20-%20INTERVAL%2030%20DAY%20GROUP%20BY%20event
