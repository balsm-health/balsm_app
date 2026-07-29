import 'package:sentry_flutter/sentry_flutter.dart';

import 'analytics_logger.dart';
import 'telemetry_scrubber.dart';

/// Sentry-backed [AnalyticsLogger].
///
/// - actions → breadcrumbs (free trail); key actions also → events.
/// - logs: debug/info → breadcrumbs, warning/error → events.
/// - errors → captureException.
///
/// Every map is scrubbed deny-by-default here, at the source, so contexts set
/// on the Sentry scope are already PHI-safe (the `beforeSend` scrub in
/// `sentry_init` is a second layer). Requires `Sentry` to be initialised.
class SentryAnalyticsLogger implements AnalyticsLogger {
  const SentryAnalyticsLogger();

  @override
  void logEvent(String name, {Map<String, Object?>? props, bool key = false}) {
    final data = scrubTelemetry(props);
    Sentry.addBreadcrumb(Breadcrumb(
      category: 'user_action',
      message: name,
      data: data,
      level: SentryLevel.info,
    ));
    if (key) {
      Sentry.captureMessage(
        name,
        level: SentryLevel.info,
        withScope: (scope) => scope.setContexts('action', data),
      );
    }
  }

  @override
  void log(String message, {LogLevel level = LogLevel.info, Map<String, Object?>? props}) {
    final data = scrubTelemetry(props);
    final sentryLevel = _toSentryLevel(level);
    if (level == LogLevel.warning || level == LogLevel.error) {
      Sentry.captureMessage(
        message,
        level: sentryLevel,
        withScope: (scope) => scope.setContexts('log', data),
      );
    } else {
      Sentry.addBreadcrumb(Breadcrumb(
        category: 'log',
        message: message,
        data: data,
        level: sentryLevel,
      ));
    }
  }

  @override
  void logError(Object error,
      {StackTrace? stackTrace, String? message, Map<String, Object?>? context, bool fatal = false}) {
    final data = scrubTelemetry(context);
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.level = fatal ? SentryLevel.fatal : SentryLevel.error;
        if (message != null) scope.setContexts('message', {'value': message});
        if (data.isNotEmpty) scope.setContexts('error_context', data);
      },
    );
  }

  @override
  void setUser(String? id) {
    // Opaque id ONLY — never email/handle/DOB.
    Sentry.configureScope(
      (scope) => scope.setUser(id == null ? null : SentryUser(id: id)),
    );
  }

  @override
  Future<void> flush() async {
    // Sentry batches + flushes on its own; no per-call flush is exposed.
  }

  SentryLevel _toSentryLevel(LogLevel level) => switch (level) {
        LogLevel.debug => SentryLevel.debug,
        LogLevel.info => SentryLevel.info,
        LogLevel.warning => SentryLevel.warning,
        LogLevel.error => SentryLevel.error,
      };
}
