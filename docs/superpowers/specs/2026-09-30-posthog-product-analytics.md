# PostHog Product Analytics — Design

**Date:** 2026-09-30
**Status:** Implemented — app (`packages/core` + `app/`) and website
**Scope:** `balsm_app`, `website`
**Supersedes nothing.** Builds on
[2026-07-03 Telemetry / Analytics Logger](./2026-07-03-telemetry-analytics-logger-design.md),
whose "Out of scope" line reserved exactly this: *"Real product-analytics backend
(PostHog/Amplitude — abstraction leaves room)."*

## Goal

Answer product questions the crash reporter cannot: which screens patients
actually use, where flows are abandoned, which campaign brought an install, how
retention moves. Add it **without** widening the PHI surface, and let the patient
switch it off.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Vendor | PostHog | The 2026-07-03 design already named it. Self-hostable, so the residency question stays answerable later. |
| Region | **EU Cloud** (`https://eu.i.posthog.com`) | Behavioural data for a MENA health app stays in the EU, not US Cloud. Overridable per build (`POSTHOG_HOST`) — point it at a self-hosted instance and there is no third party at all. |
| Consent model | **Opt-out** — on by default, patient can disable | Product decision. A funnel nobody opts into measures nothing. The switch is one tap in a screen patients already visit, and the default lives in one constant (`kAnalyticsConsentDefault`) if that call is ever reversed. |
| What the switch covers | PostHog only, **not** Sentry | Crash reporting is diagnostic data needed to keep a health app safe to use, carries no behavioural profile, and is already PHI-scrubbed. Blinding it would make the app less safe for the patient who opted out. The UI string says "Anonymous analytics — help us improve the app", which is what it now does. |
| Session replay | **Off, permanently** | Mobile replay is screenshot-based. Every screen in this app is the patient's own health data. |
| Web (Flutter) | **No analytics** | `Posthog().setup()` is a no-op on web; enabling it needs a `posthog-js` snippet in `app/web/index.html` whose autocapture reads on-screen text. Not in a PHI app. Product analytics is mobile-only by design. |

## App architecture

No new abstraction: `PostHogAnalyticsLogger` is one more `AnalyticsLogger`, fanned
out alongside Sentry by the existing `MultiAnalyticsLogger`. **No call site
changed.** The ~forty existing `logEvent` sites, the `EventBusAnalyticsForwarder`
(every domain `AppEvent`) and the `AnalyticsRouteObserver` (`screen_view`) all
started feeding PostHog for free, which is the payoff for the 2026-07-03 facade.

### Call mapping

| Facade call | Sentry | PostHog |
|---|---|---|
| `logEvent(name, props)` | breadcrumb | `capture(name, scrubbed(props))` |
| `logEvent(…, key: true)` | breadcrumb **+** event | same as above — `key` is ignored |
| `log` debug/info | breadcrumb | **dropped** |
| `log` warning/error | event | `capture('app_log', {log_message, level, …})` |
| `logError` | `captureException` (full detail) | `capture('app_error', {type, level, log_message?})` |
| `setUser(id)` | `setUser(SentryUser(id))` | `identify(userId: id)` |
| `setUser(null)` | clears user | `reset()` |

Two deliberate asymmetries:

- **`key` is ignored.** Sentry needs the breadcrumb/event split because
  breadcrumbs are free and events cost quota. In PostHog every action *is* a
  countable event; dropping the non-key ones would leave every funnel with holes
  at exactly the steps being measured.
- **`logError` sends the exception's `runtimeType`, never its message.** An
  exception string can quote the row, field or query that produced it, and that is
  PHI. Sentry receives the full exception (scrubbed there); PostHog only needs to
  know that a cohort hit an error of this class.

### Files

| File | Responsibility |
|---|---|
| `core/src/telemetry/posthog_analytics_logger.dart` | `PostHogAnalyticsLogger`, the `PostHogClient` seam, `scrubPostHogProperties` |
| `core/src/telemetry/posthog_init.dart` | `initPostHog(…)` — SDK config, super properties |
| `core/src/telemetry/analytics_consent.dart` | `TelemetryPrefs`, `AnalyticsConsent`, `AnalyticsConsentSink`, `analyticsConsentProvider` |
| `core/src/telemetry/campaign_attribution.dart` | `kCampaignParameters`, `campaignPropertiesFrom`, `CampaignAttribution` |
| `balsm_api/src/transport/non_phi_allowlist.dart` | `kNonPhiAllowlist`, `kRedacted`, `redactUrl` — the one canonical list |

Modified: `core/src/telemetry/allowlist.dart` (now an alias of the canonical
list), `telemetry_scrubber.dart` (URL redaction), `crash/sentry_init.dart`
(`transaction` + `request.url` redaction), `balsm_api`'s `PhiLeakInterceptor`
(aliases the canonical list), `core/src/config/flavor.dart` (`posthogApiKey`,
`posthogHost`), `core.dart` (exports),
`app/lib/brands/balsm/main_balsm.dart` (boot wiring, `setUser` on every session
transition, campaign capture),
`app/lib/balsm_app/screens/profile_subscreens.dart` (the toggle),
`app/lib/balsm_app/screens/walkthrough_screen.dart` + `i18n/*` (first-run
disclosure), `app/test/architecture_test.dart` (vendor-import guard),
`AndroidManifest.xml` + `Info.plist` (`AUTO_INIT: false`), `app/env/*`.

### Why `PostHogClient` exists

`Posthog()` is a platform-channel singleton, so a logger calling it directly is
untestable — and this is a PHI egress path, which is exactly the code that has to
be covered. One thin interface, one live implementation, a fake in tests. Sentry
got away without one because it is glue over statics with no branching; this
logger has a consent gate and three distinct mappings worth asserting.

## Telling builds apart in the dashboard

Every event carries which build produced it, as PostHog **super properties**:

| Property | Values | Where |
|---|---|---|
| `brand` | `balsm`, `balsm_pro` | app only — the site is not a brand |
| `flavor` | `dev`, `staging`, `prod` | app **and** website |

Super properties, not per-call props, for two reasons. They ride on *every* event
including the natively captured ones (`$application_opened`, `$rageclick`) that
never pass through `AnalyticsLogger` — so a dashboard filtered to `flavor = prod`
does not silently lose the lifecycle events every retention chart is built on.
And the native SDK merges them after `beforeSend`, so they cannot be scrubbed
away by mistake. Both are build metadata resolved from `--dart-define`s; neither
can carry PHI, and both are on `kTelemetryAllowlist` so a call site may also pass
them explicitly.

The names are the codebase's own (`FlavorConfig.brand` / `.flavor`), not invented
dashboard synonyms. **Web vs mobile needs no property** — PostHog's own `$lib`
already separates `posthog-js` from `posthog-flutter`. On the website `flavor` is
derived from `NEXT_PUBLIC_SENTRY_ENV` (`production` → `prod`, `staging` →
`staging`, else `dev`), so PostHog and Sentry never disagree about which deploy an
event came from.

The app value comes from `postHogBuildProperties(FlavorConfig)` — a pure function
so the mapping is unit-testable; `initPostHog` registers each entry after
`setup()`.

### Campaign attribution

posthog-js reads `utm_*` off the URL by itself, so the website was covered from
day one; the app was not, and allowlisting the keys did nothing on its own
because nothing populated them.

`CampaignAttribution.resolve` reads the campaign parameters off the link that
launched the app and registers them as super properties alongside `brand` and
`flavor`. **First touch, not last**: the question a campaign report answers is
"which ad produced this patient", which is settled by the first link that ever
opened the app — overwriting it later would re-attribute an existing patient to
whatever they most recently clicked, flattering retargeting and losing the
acquisition source. The value is persisted device-wide next to the consent flag.

Only the seven parameters in `kCampaignParameters` are read, only from the query,
and values are length-capped: a marketing link is attacker-controllable input as
far as the app is concerned, and these ride on every subsequent event. The
allowlist is re-applied on read, so a value written by a future build cannot
widen what reaches telemetry. The link's own token and fragment are never
touched. The boot-path call is guarded and time-boxed — attribution is never
worth delaying, let alone failing, a launch.

True install attribution (a click before the App Store, with no link to read)
still needs SKAdNetwork or an MMP; that remains out of scope.

### If filtering is not enough

One project with a `flavor` filter keeps dev/staging events in the same event
quota and one careless saved-insight forgets the filter. To split projects per
environment instead, give each flavor its own project token: move
`POSTHOG_API_KEY` out of `env/shared.json` and into `env/<brand>/<flavor>.json`.
Note the define order — builds pass the flavor file **first** and `shared.json`
second, and the later file wins, so a key left in `shared.json` would override the
per-flavor one rather than the other way round.

## Defects found and fixed while wiring this up

Adding a second telemetry backend meant auditing the egress path, which surfaced
four problems that predate this work. All four are fixed here.

**1. `'name'` was allowlisted, so medication names were leaving the device.**
`MedicationAdded.toJson()` carries `'name': <medication>`, and
`EventBusAnalyticsForwarder` forwards every `AppEvent`'s JSON verbatim as props.
With `name` on the allowlist the value survived the scrub — and `medication.added`
is in `kKeyEventNames`, so it was emitted as a *searchable Sentry event*, not a
breadcrumb that only ships alongside a crash. `name` is now banned from the
allowlist; the one internal use moved to `log_message`. The fuzz suite asserts
no key is ever both allowed and denied, which is what would have caught this.

**2. URL secrets were passed through verbatim.** `contracts/crash-allowlist.json`
requires every captured URL to be reduced to a route template with the fragment
stripped, *because the emergency-QR AES key is the fragment* (`/t/{jti}#k=<key>`)
and the magic sign-in token is a query param (`?t=<token>`). Nothing implemented
it: `url` was allowlisted by name and its value was never touched. `redactUrl`
now drops the query and fragment and masks opaque path segments, and is applied
by all three scrubbers plus Sentry's `transaction` and `request.url`, which the
SDK fills in by itself and which therefore never passed through the logger.

**3. The allowlist had five copies and nothing bound them.** `allowlist.dart`
claimed "the PHI-leak fuzz test guards that the copies agree"; no such test
existed, and the copies had drifted ~15 keys apart. There is now one list
(`kNonPhiAllowlist` in `balsm_api`, the lowest package both egress paths reach),
aliased by core and by `PhiLeakInterceptor`. The dead copy in `corpus.dart` is
deleted, the test's copy is gone, and a test asserts the remaining references are
`identical`.

**4. `setUser` was never called, so sign-out never reset the analytics identity.**
Nothing in the app called it — for Sentry either. That is a privacy defect rather
than a metrics one: on a shared device the next account to sign in kept emitting
under the previous patient's person. It is now called on the boot seed, on
`UserSignedIn`, on `UserSignedOut` and on `SessionExpired`, alongside the cache
and permanent-QR sweeps that were already there for exactly this reason.

### Two guards that were giving false green

The fuzz test that should have caught #1 and #2 was itself broken: its Dio case
asserted the interceptor strips PHI from the *request body*, which contradicts
the interceptor's documented contract (it must not mutate the body; it stashes a
scrubbed copy in `extra['phi_safe_body']`). It had been failing permanently, so
nobody read it. It now asserts on the copy, and covers the URL secrets and the
`MedicationAdded` shape.

`translation_completeness_test.dart` read a directory that no longer exists and
called `fail()` at load time, dying with `OutsideTestException` on every run. It
now discovers `*.i69n.jsonc` pairs by glob across app, core and modules — 11
pairs, 1132 keys, currently 100% complete — and asserts it found bundles at all,
so a path change fails loudly instead of passing vacuously.

**Still outstanding, not fixed here:** `custom_lint` is commented out of every
package's `analysis_options.yaml` ("isolate leak", 2026-07-31), so
`melos run boundaries` reports a vacuous green and all six `balsm_boundary_lint`
DDD rules are inert. The vendor-import guard added for this work is therefore a
test in `app/test/architecture_test.dart`, next to the existing Drift and
module-independence rules, rather than a seventh lint rule that would never run.

## PHI safety

Same deny-by-default model as the Sentry path, with two PostHog-specific rules in
`scrubPostHogProperties`:

1. **`$`-prefixed keys pass through.** They are SDK-generated from build metadata
   and route names (`$screen_name`, `$app_version`, `$lib`), never from patient
   input, and redacting them would strip the dimensions every PostHog report is
   built on.
2. **Null values are dropped.** `Posthog().capture` takes `Map<String, Object>`,
   so a null would not survive the platform channel; dropping it keeps a
   redacted-to-null key from looking like data.

Layers, outermost last:

1. `PostHogAnalyticsLogger` scrubs at the source.
2. `PostHogConfig.beforeSend` scrubs again — covers any Dart-captured event that
   reached the SDK without going through the logger. (Natively captured events do
   **not** run these callbacks; they carry `$` properties only and no app data.)
3. The consent gate short-circuits the logger *and* opts the SDK out, so
   natively-captured events stop too.

### Allowlist additions

`step`, `variant`, `enabled`, `source`, `result` (structural product dimensions)
and `campaign`, `referrer`, `utm_source`, `utm_medium`, `utm_campaign`,
`utm_content`, `utm_term` (campaign attribution — these describe the ad that
brought the install, never the person). Nothing here can name a patient, a
medication or a condition.

### SDK configuration

Manual init (`AUTO_INIT: false` in `AndroidManifest.xml` and `Info.plist`) is
load-bearing, not tidiness: automatic init would start collecting before the
patient's consent had been read off disk and before `beforeSend` was installed.

Off: `sessionReplay`, `surveys` (renders PostHog UI over the app and needs
`PosthogObserver`, which would bypass the scrubbed `AnalyticsRouteObserver`),
`preloadFeatureFlags` / `sendFeatureFlagEvents` (unused; keeps a network
round-trip out of every cold start), push-notification capture (Balsm has no
PostHog push).

On: `captureApplicationLifecycleEvents` (sessions / DAU / retention come from
these — and they are captured natively, which is why consent has to reach the SDK
itself, not just the facade) and rage-click capture (coordinates only, useful UX
signal, covered by consent).

## Consent

`AnalyticsConsent` holds the choice, persists it through `TelemetryPrefs`
(`telemetry.*` namespace) and pushes every change to its `AnalyticsConsentSink`s.

Device-wide (global KV, not the per-user store) on purpose: the choice belongs to
whoever holds the device, so it survives sign-out and is not silently re-enabled
by the next account to sign in.

Boot order in `bootstrap()` matters — read the choice, build the logger with it,
*then* `initPostHog(analyticsEnabled:)`. A patient who opted out emits nothing on
this launch, not even the native `$application_opened`.

The UI is the existing `pv_analytics` row in Profile → Privacy & data, which was
a design placeholder wired to nothing (`bool analytics = false` + `setState`). It
is now the real switch; the other toggles on that screen remain placeholders.
Turning it **off** applies consent before logging the change event, so the event
recording an opt-out is itself already gated.

## Website (balsm.health)

`posthog-js`, initialised in the existing `src/instrumentation-client.ts`
alongside Sentry. Same opt-out model, choice in `localStorage`
(`balsm.analytics`) — the site has no accounts, so there is nowhere else to put
it. The control is a text button in the footer's legal row next to the PDPL line,
not a cookie banner: an interstitial on every first visit would interrupt the
reader to ask about something already running.

- Ingestion is proxied through a first-party `/ingest` rewrite to EU Cloud
  (`next.config.ts`). Ad blockers drop `*.i.posthog.com` by hostname, which would
  delete a large and non-random slice of exactly the campaign data these numbers
  exist to measure — the same trade Sentry already makes with
  `tunnelRoute: '/monitoring'`. It also keeps ingestion same-origin, so the CSP
  needs no third-party entry. `skipTrailingSlashRedirect` is required, and
  `ingest` had to be added to the `middleware.ts` matcher exclusions or next-intl
  would locale-prefix it and every request would 404.
- `disable_session_recording: true` — the waitlist form would be recorded as the
  reader types into it.
- `capture_pageview: 'history_change'` + `capture_pageleave` handle App Router
  navigations without a provider component. Set explicitly rather than via
  `defaults` so an SDK upgrade cannot change behaviour underneath us.
- The waitlist form carries `ph-no-capture` (no autocapture on that subtree) and
  emits one deliberate `waitlist_submitted` event with `{source, locale, result}`
  — `result` separates a new signup from someone already on the list, which read
  the same on screen but are very different numbers in a funnel.

## Compliance

PostHog EU Cloud is a **new sub-processor** and is recorded in
`Balsm-Core/agents/rules/AGENTS.md`. Still outstanding, outside this change:

- Privacy notice + Apple/Google data-safety filings must disclose it.
- **First-run disclosure now exists**: the walkthrough's data-ownership slide
  says analytics is on and where to switch it off. Opt-out without that was the
  weak point in the consent decision; it is not a substitute for the privacy
  notice above.
- The website has no privacy-policy page at all; the footer control is the only
  disclosure there today.
- **PostHog project settings:** enable *Discard client IP data*. Client-side SDKs
  cannot suppress the request IP, and `$ip: null` is not expressible through the
  Flutter channel (`Map<String, Object>` rejects nulls) — so this has to be set
  server-side, once, per project.
- `POSTHOG_API_KEY` / `NEXT_PUBLIC_POSTHOG_KEY` are empty in the committed
  templates. Analytics is inert until a real project token is filled in.

## Testing

- `scrubPostHogProperties` — allowlist, `$`-passthrough, null-dropping, nested
  redaction, null/empty input.
- `PostHogAnalyticsLogger` against a fake `PostHogClient` — each call mapping,
  `key` ignored, debug/info dropped, `logError` carrying no exception text,
  identify/reset, the disabled path (no captures *and* SDK opted out), re-enable,
  no-op on an unchanged value, and a throwing backend never surfacing an error.
- `postHogBuildProperties` — every brand × flavor combination, the underscored
  `balsm_pro` name, the two axes moving independently, and both keys surviving
  the scrub.
- `AnalyticsConsent` — default on, persisted opt-out applied before the first
  frame, `set` persisting + notifying + reaching sinks, no-op on an unchanged
  value, and survival across a re-load.
- `app/test/analytics_consent_toggle_test.dart` — the Privacy & data row itself:
  reflects persisted state, and a tap persists, reaches the backend before the
  change event is logged, and round-trips.

`PostHogAnalyticsLogger`'s glue to the real SDK and `initPostHog` are not unit
tested (platform channels), matching how `SentryAnalyticsLogger` and `initSentry`
are treated.

## Out of scope

Feature flags and experiments; PostHog surveys; session replay (permanently);
analytics in the Flutter **web** build; a privacy-policy page for the website;
SKAdNetwork / MMP install attribution (PostHog sees campaign parameters that
reach the app, not Apple's postbacks — see the `attribution-setup` skill).
