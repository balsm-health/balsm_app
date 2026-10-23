import 'package:sentry_flutter/sentry_flutter.dart';

import 'analytics_logger.dart';
import 'feedback_reporter.dart';
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

/// Sentry-backed [FeedbackReporter]: each submission lands in Sentry's User
/// Feedback inbox, tagged with its rating and topics so it can be filtered.
///
/// The note is the feedback's message, sent as typed — that is its purpose.
/// Everything else on the event (breadcrumbs, the route) goes through the same
/// scrub as crash events: `sentry_init` routes `beforeSendFeedback` to it.
class SentryFeedbackReporter implements FeedbackReporter {
  const SentryFeedbackReporter();

  /// Sentry drops a feedback whose message is blank, so a submission without
  /// a note sends a dash. The rating and topics are in the tags, not here.
  ///
  /// Sentry's spam filter archived the earlier `(rating only)` placeholder
  /// within seconds; a dash relies on spam detection being off for the project.
  static const ratingOnly = '-';

  /// The Sentry payload for [feedback]. [userId] is the opaque id telemetry
  /// already knows the patient by (null for a device-only or signed-out
  /// account); it goes in `name` because that is the field Sentry's feedback
  /// list shows — without it every entry reads "Anonymous User". Never a real
  /// name, handle or email.
  static SentryFeedback build(UserFeedback feedback, {String? userId}) {
    final note = feedback.note?.trim();
    return SentryFeedback(
      message: note == null || note.isEmpty ? ratingOnly : note,
      name: userId,
    );
  }

  @override
  Future<bool> send(UserFeedback feedback) async {
    final payload = build(feedback);
    final id = await Sentry.captureFeedback(
      payload,
      withScope: (scope) {
        // The scope's user is whatever [SentryAnalyticsLogger.setUser] put
        // there, so the device-only rule is already applied.
        payload.name = scope.user?.id;
        scope.setTag('feedback.rating', '${feedback.rating}');
        if (feedback.topics.isNotEmpty) scope.setTag('feedback.topics', feedback.topics.join(','));
      },
    );
    return id != SentryId.empty();
  }
}
