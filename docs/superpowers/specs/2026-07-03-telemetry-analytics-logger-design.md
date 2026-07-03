# Telemetry / Analytics Logger — Design

**Date:** 2026-07-03
**Status:** Approved (design review with Hossam)
**Scope:** `packages/core` (+ app wiring)

## Goal

One provider-agnostic abstraction for **user-action analytics, structured
logs, and crash/error reporting**. Sentry is the first backend: every action
is a breadcrumb, a marked subset of key actions are also events, logs/crashes
are events. PHI-safe by construction (health app; telemetry leaves the device).

## The abstraction

```dart
enum LogLevel { debug, info, warning, error }

abstract class AnalyticsLogger {
  void logEvent(String name, {Map<String, Object?>? props, bool key = false});
  void log(String message, {LogLevel level = LogLevel.info, Map<String, Object?>? props});
  void logError(Object error, {StackTrace? stackTrace, String? message,
                Map<String, Object?>? context, bool fatal = false});
  void setUser(String? id);   // opaque non-PHI id only, or null to clear
  Future<void> flush();
}
```

- `logEvent` — user action. Always a breadcrumb; `key: true` also emits an event.
- `log` — debug/info → breadcrumb; warning/error → event.
- `logError` — handled or uncaught error → event.
- Ships with `NoopAnalyticsLogger` (default / tests) and `SentryAnalyticsLogger`.

## Sentry backend mapping

| Call | Sentry primitive |
|---|---|
| `logEvent(name, props)` | `addBreadcrumb(category: 'user_action', message: name, data: scrub(props))` |
| `logEvent(..., key: true)` | above **plus** `captureMessage(name, level: info)` with scrubbed context |
| `log` debug/info | `addBreadcrumb(category: 'log', level, data: scrub(props))` |
| `log` warning/error | `captureMessage(message, level)` with scrubbed context |
| `logError` | `captureException(error, stackTrace, level: fatal ? fatal : error)` + scrubbed context |
| `setUser(id)` | `configureScope((s) => s.setUser(SentryUser(id: id)))` — id only |
| `flush` | best-effort (`Sentry.close` is not used; batching handles delivery) — no-op stub acceptable |

Breadcrumbs = free action trail (only sent attached to an event). Key events +
logs + crashes = the searchable/countable/alertable data. A later
PostHog/Amplitude backend = one more `AnalyticsLogger` impl, no call-site change.

## PHI safety — deny-by-default (non-negotiable)

- **`TelemetryScrubber`** filters every `props` / `context` / breadcrumb `data`
  map against **one canonical non-PHI allowlist** in
  `core/lib/src/telemetry/allowlist.dart`. Any key not on the allowlist →
  `'[redacted]'`. Deny-by-default: unknown keys never escape. Shallow scrub
  (top-level keys), matching `PhiLeakInterceptor.scrubForTelemetry`.
- **Event names / messages must be compile-time constants**, never user data.
  Enforced by convention + a new `flutter-log-telemetry` skill (not the
  compiler).
- **Fix the no-op `sentry_init` scrub:** implement `beforeSend` /
  `beforeBreadcrumb` to apply the same allowlist to event contexts/extra and
  breadcrumb data — a second defense layer (today they return the event
  unchanged). `sentry_init` references the canonical core allowlist.
- `setUser` takes an opaque id only (no email/handle/DOB).
- `balsm_api`'s `PhiLeakInterceptor` keeps its own allowlist copy (core must not
  depend on it in reverse; the PHI-fuzz test guards that the copies agree).

## Auto-capture

- **`EventBusAnalyticsForwarder`** — subscribes to the existing
  `eventBus.events` and forwards every domain `AppEvent` as
  `logEvent(e.eventName, props: e.toJson())` (scrubbed in the logger). Domain
  events are the user actions. A `kKeyEventNames` set marks which also emit as
  events (e.g. `emergency_qr_minted`, `deletion_requested`).
- **`AnalyticsRouteObserver`** (`NavigatorObserver`) — on push/pop →
  `logEvent('screen_view', props: {'route': <name>})`. Route names are non-PHI.
- **Explicit API** for taps not modeled as domain events.

## Files (`packages/core/lib/src/telemetry/`)

| File | Responsibility |
|---|---|
| `analytics_logger.dart` | `AnalyticsLogger` interface, `LogLevel`, `NoopAnalyticsLogger` |
| `allowlist.dart` | canonical non-PHI key allowlist (`kTelemetryAllowlist`) |
| `telemetry_scrubber.dart` | `scrubTelemetry(Map) → Map` deny-by-default |
| `sentry_analytics_logger.dart` | `SentryAnalyticsLogger implements AnalyticsLogger` |
| `event_bus_forwarder.dart` | `EventBusAnalyticsForwarder` + `kKeyEventNames` |
| `analytics_route_observer.dart` | `AnalyticsRouteObserver` |
| `providers.dart` | `analyticsLoggerProvider` (default Noop; app overrides) |

Modified: `crash/sentry_init.dart` (real scrub via canonical allowlist),
`core.dart` (exports). App: override `analyticsLoggerProvider` with
`SentryAnalyticsLogger` after `initSentry()`; attach the route observer + start
the forwarder at boot.

## Testing

- `telemetry_scrubber` — deny-by-default: allowlisted keys survive, unknown →
  `[redacted]`; empty/null tolerated.
- `NoopAnalyticsLogger` — no throw, returns.
- `EventBusAnalyticsForwarder` / `AnalyticsRouteObserver` — via a
  `FakeAnalyticsLogger` recording calls; assert event name + scrubbed props +
  key flag.
- `SentryAnalyticsLogger` stays thin glue (Sentry statics not unit-tested);
  covered indirectly by the scrubber tests.

## Out of scope

Real product-analytics backend (PostHog/Amplitude — abstraction leaves room);
on-device log persistence; Sentry replay/tracing.
