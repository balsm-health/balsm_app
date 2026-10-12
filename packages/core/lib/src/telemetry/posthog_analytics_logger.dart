import 'dart:async';

import 'package:balsm_api/balsm_api.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'allowlist.dart';
import 'analytics_consent.dart';
import 'analytics_logger.dart';
import 'telemetry_scrubber.dart';

/// Event name for a `log` at `warning`/`error` level. PostHog is a product
/// analytics store, not a log sink — one countable event carrying the level and
/// the (constant) message keeps funnels clean while still surfacing that
/// something went wrong to a cohort.
const kPostHogLogEvent = 'app_log';

/// Event name for a handled/uncaught error. Deliberately carries no exception
/// text (see [PostHogAnalyticsLogger.logError]) — Sentry owns the detail.
const kPostHogErrorEvent = 'app_error';

/// The PostHog surface this package uses, behind an interface.
///
/// `Posthog()` is a platform-channel singleton, so a logger calling it directly
/// is untestable — and this is a PHI egress path in a health app, which is
/// exactly the code that must be covered. [LivePostHogClient] is the one
/// implementation that talks to the SDK; tests substitute a fake.
abstract class PostHogClient {
  Future<void> capture(String eventName, Map<String, Object>? properties);
  Future<void> identify(String userId);
  Future<void> reset();
  Future<void> enable();
  Future<void> disable();
  Future<void> flush();
}

/// [PostHogClient] backed by the real SDK. Requires `initPostHog()` to have run.
class LivePostHogClient implements PostHogClient {
  const LivePostHogClient();

  @override
  Future<void> capture(String eventName, Map<String, Object>? properties) =>
      Posthog().capture(eventName: eventName, properties: properties);

  @override
  Future<void> identify(String userId) => Posthog().identify(userId: userId);

  @override
  Future<void> reset() => Posthog().reset();

  @override
  Future<void> enable() => Posthog().enable();

  @override
  Future<void> disable() => Posthog().disable();

  @override
  Future<void> flush() => Posthog().flush();
}

/// PostHog-backed [AnalyticsLogger] — the product-analytics backend (which
/// screens are used, which flows complete, campaign attribution).
///
/// Differences from the Sentry backend, both deliberate:
///
/// - **`key` is ignored.** Sentry needs the breadcrumb/event split because
///   breadcrumbs are free and events cost quota. In PostHog every action *is* a
///   countable event — dropping the non-key ones would leave every funnel with
///   holes at exactly the steps that matter.
/// - **`debug`/`info` logs are dropped.** They are diagnostics, not behaviour;
///   Sentry keeps them as breadcrumbs.
///
/// Consent: the patient can switch product analytics off (Privacy & data). This
/// logger is an [AnalyticsConsentSink] — while disabled every call is a no-op
/// *and* the SDK is opted out, so nothing the facade does not see (lifecycle
/// events, rage clicks) escapes either.
class PostHogAnalyticsLogger implements AnalyticsLogger, AnalyticsConsentSink {
  PostHogAnalyticsLogger({
    PostHogClient client = const LivePostHogClient(),
    bool enabled = kAnalyticsConsentDefault,
  })  : _client = client,
        _enabled = enabled;

  final PostHogClient _client;
  bool _enabled;

  /// Whether product analytics is currently collecting.
  bool get enabled => _enabled;

  @override
  void setAnalyticsEnabled(bool enabled) {
    if (enabled == _enabled) return;
    _enabled = enabled;
    // Belt and braces: the facade gate above stops everything routed through
    // this class, and the SDK opt-out stops what is not — `$application_opened`
    // and friends are captured natively.
    _fire(enabled ? _client.enable() : _client.disable());
  }

  @override
  void logEvent(String name, {Map<String, Object?>? props, bool key = false}) {
    if (!_enabled) return;
    _fire(_client.capture(name, scrubPostHogProperties(props)));
  }

  @override
  void log(String message, {LogLevel level = LogLevel.info, Map<String, Object?>? props}) {
    if (!_enabled) return;
    if (level == LogLevel.debug || level == LogLevel.info) return;
    _fire(_client.capture(kPostHogLogEvent, {
      ...scrubPostHogProperties(props),
      // `message` is a compile-time constant by the facade contract. NOT under
      // a 'name' key — see kNonPhiAllowlist for why that one is banned.
      'log_message': message,
      'level': level.name,
    }));
  }

  @override
  void logError(Object error,
      {StackTrace? stackTrace, String? message, Map<String, Object?>? context, bool fatal = false}) {
    if (!_enabled) return;
    _fire(_client.capture(kPostHogErrorEvent, {
      ...scrubPostHogProperties(context),
      // The exception's type, never its `toString()`: a message can quote the
      // row, field or query that produced it, and that is PHI. Sentry receives
      // the full exception (scrubbed there); PostHog only needs to know that a
      // cohort hit an error of this class.
      'type': error.runtimeType.toString(),
      'level': fatal ? 'fatal' : 'error',
      if (message != null) 'log_message': message,
    }));
  }

  @override
  void setUser(String? id) {
    if (!_enabled) return;
    // Opaque id ONLY — never email/handle/DOB. `reset()` on sign-out so the
    // next account on this device does not inherit the previous person.
    _fire(id == null ? _client.reset() : _client.identify(id));
  }

  @override
  Future<void> flush() async {
    if (!_enabled) return;
    await _client.flush().catchError((_) {});
  }

  /// Telemetry must never break the app, and an unawaited platform-channel
  /// failure would otherwise reach `platformDispatcher.onError` — which reports
  /// through this very logger.
  void _fire(Future<void> call) => unawaited(call.catchError((_) {}));
}

/// Deny-by-default scrub for PostHog event properties, plus the two rules the
/// Sentry path does not need:
///
/// 1. **`$`-prefixed keys pass through.** They are generated by the PostHog SDK
///    itself (`$screen_name`, `$app_version`, `$lib`, …) from build metadata and
///    route names, never from patient input, and redacting them would strip the
///    dimensions every PostHog report is built on.
/// 2. **Null values are dropped.** `Posthog().capture` takes
///    `Map<String, Object>`, so a null would not survive the platform channel
///    anyway; dropping it here keeps a redacted-to-null key from looking like
///    data.
///
/// Everything else goes through [kTelemetryAllowlist] exactly as
/// [scrubTelemetry] does: an unknown key's value becomes `'[redacted]'`.
Map<String, Object> scrubPostHogProperties(Map<dynamic, dynamic>? props) {
  if (props == null || props.isEmpty) return const {};
  final out = <String, Object>{};
  for (final entry in props.entries) {
    final key = entry.key.toString();
    if (key.startsWith(r'$')) {
      final value = entry.value;
      if (value != null) out[key] = value as Object;
      continue;
    }
    if (!kTelemetryAllowlist.contains(key)) {
      out[key] = kTelemetryRedacted;
      continue;
    }
    // Allowlisted by name is not enough for a URL — the emergency-QR AES key is
    // a fragment and the magic sign-in token is a query param.
    final value = redactIfUrlValued(key, entry.value);
    if (value != null) out[key] = value;
  }
  return out;
}
