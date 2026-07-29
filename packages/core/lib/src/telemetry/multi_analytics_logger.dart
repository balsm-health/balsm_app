import 'analytics_logger.dart';

/// Fan-out [AnalyticsLogger]: forwards every call to each backend in
/// [providers], in order. Lets the app run several telemetry providers at once
/// — e.g. Sentry always, plus a console sink added only in debug builds.
class MultiAnalyticsLogger implements AnalyticsLogger {
  const MultiAnalyticsLogger(this.providers);

  final List<AnalyticsLogger> providers;

  @override
  void logEvent(String name, {Map<String, Object?>? props, bool key = false}) {
    for (final p in providers) {
      p.logEvent(name, props: props, key: key);
    }
  }

  @override
  void log(String message, {LogLevel level = LogLevel.info, Map<String, Object?>? props}) {
    for (final p in providers) {
      p.log(message, level: level, props: props);
    }
  }

  @override
  void logError(Object error,
      {StackTrace? stackTrace, String? message, Map<String, Object?>? context, bool fatal = false}) {
    for (final p in providers) {
      p.logError(error, stackTrace: stackTrace, message: message, context: context, fatal: fatal);
    }
  }

  @override
  void setUser(String? id) {
    for (final p in providers) {
      p.setUser(id);
    }
  }

  @override
  Future<void> flush() async {
    for (final p in providers) {
      await p.flush();
    }
  }
}
