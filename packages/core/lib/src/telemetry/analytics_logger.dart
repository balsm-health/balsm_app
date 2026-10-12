/// Severity for [AnalyticsLogger.log].
enum LogLevel { debug, info, warning, error }

/// Provider-agnostic telemetry facade: user-action analytics, structured logs,
/// and crash/error reporting behind one interface. Backends (Sentry today,
/// PostHog/Amplitude later) implement this; call sites never import a vendor
/// SDK.
///
/// PHI rule: [name]/[message] MUST be compile-time constants, never user data.
/// All `props`/`context` maps are scrubbed deny-by-default before egress.
abstract class AnalyticsLogger {
  /// A user action. Always recorded as a breadcrumb (the trail attached to the
  /// next error). When [key] is true it is ALSO emitted as a standalone event
  /// (searchable/countable) — reserve for low-volume business milestones.
  void logEvent(String name, {Map<String, Object?>? props, bool key = false});

  /// A structured log line. `debug`/`info` become breadcrumbs; `warning`/
  /// `error` become events (visible + alertable).
  void log(String message, {LogLevel level = LogLevel.info, Map<String, Object?>? props});

  /// A handled or uncaught error → event. [fatal] marks a crash.
  void logError(Object error,
      {StackTrace? stackTrace, String? message, Map<String, Object?>? context, bool fatal = false});

  /// Associate telemetry with an opaque, non-PHI user id (or null to clear).
  void setUser(String? id);

  /// Best-effort flush of pending telemetry.
  Future<void> flush();
}

/// Does nothing. The default binding and the test double — telemetry stays
/// off until a real backend is wired in the app's ProviderScope.
class NoopAnalyticsLogger implements AnalyticsLogger {
  const NoopAnalyticsLogger();

  @override
  void logEvent(String name, {Map<String, Object?>? props, bool key = false}) {}

  @override
  void log(String message, {LogLevel level = LogLevel.info, Map<String, Object?>? props}) {}

  @override
  void logError(Object error,
      {StackTrace? stackTrace, String? message, Map<String, Object?>? context, bool fatal = false}) {}

  @override
  void setUser(String? id) {}

  @override
  Future<void> flush() async {}
}
