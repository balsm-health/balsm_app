---
name: flutter-log-telemetry
description: Log user actions, structured logs, and errors through the AnalyticsLogger facade (core/src/telemetry) — never a vendor SDK directly, never PHI. Use when adding analytics/telemetry, tracking a user action or screen, logging a message, reporting a handled error, or when you see Sentry.* / print() / debugPrint() / a raw logging call in feature code.
metadata:
  type: convention
---

# Log Telemetry via AnalyticsLogger

All analytics, logs, and error reporting go through the **`AnalyticsLogger`**
facade in `packages/core/lib/src/telemetry/`. Feature code never imports
`sentry_flutter` (or any vendor SDK) and never calls `print`/`debugPrint` for
diagnostics. Backends are swappable (Sentry today, PostHog/Amplitude later)
without touching call sites.

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
  never for high-frequency actions.
- Most domain user-actions are already captured automatically by the
  `EventBusAnalyticsForwarder` (every `AppEvent`) and screen views by
  `AnalyticsRouteObserver`. Use `logEvent` for taps not modeled as events.

## PHI rules (health app — telemetry leaves the device)

1. **Event names / log messages are compile-time constants** — never
   interpolate user data (`'view_$email'` ❌).
2. **Props are scrubbed deny-by-default** against
   `kTelemetryAllowlist` (`telemetry/allowlist.dart`): any key not on the list
   is redacted. So passing `{'email': …}` is safe (it's dropped), but it's also
   pointless — only pass known non-PHI keys.
3. **To add a new prop key, add it to `kTelemetryAllowlist`** — and only if it
   can never carry PHI (no email, handle, user id, DOB, medication/condition,
   free text). When in doubt, leave it out.
4. **`setUser` takes an opaque id only** — never email/handle/DOB.

## Do / Don't

| Do | Don't |
|----|-------|
| `ref.watch(analyticsLoggerProvider).logEvent('x')` | `Sentry.captureMessage('x')` in feature code |
| `logError(e, stackTrace: st)` | `print(e)` / `debugPrint(e)` |
| const event name + allowlisted props | `logEvent('view_$userId')` |
| add a non-PHI key to `kTelemetryAllowlist` | pass PHI props and hope |
| `key: true` for rare milestones | `key: true` on `dose.taken` (high volume) |

## Checklist

- [ ] Uses `analyticsLoggerProvider`, not a vendor SDK.
- [ ] Event name/message is a constant (no user data).
- [ ] Any new prop key is added to `kTelemetryAllowlist` and is non-PHI.
- [ ] `key: true` only for low-volume milestones.
- [ ] No `print`/`debugPrint` for diagnostics.
