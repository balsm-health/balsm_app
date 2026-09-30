---
name: flutter-log-telemetry
description: Log user actions, structured logs, and errors through the AnalyticsLogger facade (core/src/telemetry) — Sentry for crashes, PostHog for product analytics, never a vendor SDK directly, never PHI. Use when adding analytics/telemetry, tracking a user action or screen, logging a message, reporting a handled error, wiring analytics consent, or when you see Sentry.* / Posthog() / print() / debugPrint() / a raw logging call in feature code.
metadata:
  type: convention
---

# Log Telemetry via AnalyticsLogger

All analytics, logs, and error reporting go through the **`AnalyticsLogger`**
facade in `packages/core/lib/src/telemetry/`. Feature code never imports
`sentry_flutter` or `posthog_flutter` (or any vendor SDK) and never calls
`print`/`debugPrint` for diagnostics.

Two backends run at once behind that one interface, fanned out by
`MultiAnalyticsLogger`:

| Backend | What it is for | Consent |
|---|---|---|
| **Sentry** | crashes, handled errors, diagnostic breadcrumbs | always on — diagnostics needed to keep the app safe to use |
| **PostHog** (EU Cloud) | product analytics: screens, funnels, campaign attribution | **opt-out**, the patient can switch it off |

Writing a new call site means thinking about neither. Both receive the same
call, each maps it to its own primitives, and both scrub against the same
allowlist.

## Get the logger

```dart
final analytics = ref.watch(analyticsLoggerProvider);
```

## The API

```dart
analytics.logEvent('handle_claimed');                 // user action → breadcrumb
analytics.logEvent('emergency_qr_minted', key: true); // + Sentry event (countable)
analytics.log('cache miss', level: LogLevel.info);     // info/debug → breadcrumb
analytics.log('retry exhausted', level: LogLevel.warning); // warn/error → event
analytics.logError(e, stackTrace: st, message: 'mint failed'); // → event
analytics.setUser(userId);                             // opaque id ONLY
```

- **Breadcrumbs vs events:** every `logEvent` is a breadcrumb (free trail
  attached to the next crash). `key: true` also emits a searchable Sentry event
  — reserve for low-volume business/security milestones (see `kKeyEventNames`),
  never for high-frequency actions. **`key` is a Sentry concern only:** PostHog
  captures every `logEvent` regardless, because a funnel with holes at the
  non-key steps is useless.
- **`log` at debug/info never reaches PostHog** — those are diagnostics, not
  behaviour. `warning`/`error` arrive there as one `app_log` event, and
  `logError` as one `app_error` event carrying the exception's *type* only.
- Most domain user-actions are already captured automatically by the
  `EventBusAnalyticsForwarder` (every `AppEvent`) and screen views by
  `AnalyticsRouteObserver`. Use `logEvent` for taps not modeled as events.

## PHI rules (health app — telemetry leaves the device)

1. **Event names / log messages are compile-time constants** — never
   interpolate user data (`'view_$email'` ❌).
2. **Props are scrubbed deny-by-default** against the one canonical allowlist,
   `kNonPhiAllowlist` in `balsm_api/src/transport/non_phi_allowlist.dart`
   (core's `kTelemetryAllowlist` is an alias, not a copy): any key not on the
   list is redacted. So passing `{'email': …}` is safe (it's dropped), but it's
   also pointless — only pass known non-PHI keys.
3. **To add a new prop key, add it to `kNonPhiAllowlist`** — and only if it can
   never carry PHI (no email, handle, user id, DOB, medication/condition, free
   text). When in doubt, leave it out. Never add a second copy of the list.
4. **Never use `'name'` as a prop key.** It is banned from the allowlist. In a
   health app it is the medication name, allergy name, condition name, contact
   name and patient name — `MedicationAdded.toJson()` carries
   `'name': <medication>`, and because the EventBusAnalyticsForwarder sends
   every event's JSON verbatim, having `name` allowlisted shipped medication
   names to telemetry. Use a key that can only ever hold a constant, like
   `log_message`.
5. **A URL is not safe just because `url` is allowlisted.** URL-valued keys have
   their value rewritten by `redactUrl` — no query, no fragment, opaque path
   segments masked — because the emergency-QR AES key is a fragment (`#k=`) and
   the magic sign-in token is a query param (`?t=`). Never hand-build a prop
   that embeds a full href some other way.
6. **`setUser` takes an opaque id only** — never email/handle/DOB. On sign-out
   (`setUser(null)`) PostHog is `reset()`, so the next account on the device does
   not inherit the previous person.
7. **Session replay stays off.** It screenshots whatever is on screen, which in
   this app is the patient's own health data. `sessionReplay = false` in
   `posthog_init.dart` is not a default to revisit.
8. **`$`-prefixed PostHog properties pass the scrub** — they are SDK-generated
   (`$screen_name`, `$app_version`). Never set one yourself from app data.

## Build identity

`brand` (`balsm` / `balsm_pro`) and `flavor` (`dev` / `staging` / `prod`) are
registered once at boot as PostHog super properties, so **every** event already
carries them. Do not pass either by hand — `logEvent('x', props: {'flavor': …})`
is redundant, and hand-setting one on a single event is how a dashboard ends up
disagreeing with itself. Add a new build-wide dimension in
`postHogBuildProperties`, not at a call site.

## Consent

Product analytics is **opt-out**: on unless the patient turns it off in
Profile → Privacy & data. `AnalyticsConsent` (`telemetry/analytics_consent.dart`)
owns the choice; it is device-wide, so it survives sign-out.

```dart
ref.read(analyticsConsentProvider).set(false); // stops PostHog immediately
```

Do **not** add your own `if (consentEnabled)` guard around a `logEvent`. The
PostHog backend is an `AnalyticsConsentSink` and gates itself — and the SDK is
opted out too, so even natively captured events stop. A guard at the call site
would also silence Sentry, which the switch is deliberately not about.

## Do / Don't

| Do | Don't |
|----|-------|
| `ref.watch(analyticsLoggerProvider).logEvent('x')` | `Sentry.captureMessage('x')` / `Posthog().capture(…)` in feature code |
| `logError(e, stackTrace: st)` | `print(e)` / `debugPrint(e)` |
| const event name + allowlisted props | `logEvent('view_$userId')` |
| add a non-PHI key to `kNonPhiAllowlist` | add a second copy of the allowlist |
| `props: {'log_message': kConst}` | `props: {'name': …}` — banned, it is PHI everywhere else |
| `key: true` for rare milestones | `key: true` on `dose.taken` (high volume) |
| let the PostHog backend gate itself on consent | `if (consent) analytics.logEvent(…)` at the call site |

## Checklist

- [ ] Uses `analyticsLoggerProvider`, not a vendor SDK.
- [ ] Event name/message is a constant (no user data).
- [ ] Any new prop key is added to `kNonPhiAllowlist` and is non-PHI.
- [ ] No `'name'` prop key, and no raw URL in a prop.
- [ ] `key: true` only for low-volume milestones.
- [ ] No `print`/`debugPrint` for diagnostics.
- [ ] No consent check at the call site — the backend owns that.

Design: `docs/superpowers/specs/2026-09-30-posthog-product-analytics.md`.
