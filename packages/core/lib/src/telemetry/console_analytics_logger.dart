import 'dart:developer' as developer;

import 'analytics_logger.dart';
import 'telemetry_scrubber.dart';

/// [AnalyticsLogger] that prints every call to the dev console via
/// `dart:developer.log`. A debug-only sink — add it to the analytics provider
/// list ONLY under `kDebugMode`; release builds must never carry it.
///
/// PHI: `props`/`context` are run through [scrubTelemetry] (deny-by-default)
/// before printing. The console is a log sink like any other, so a
/// non-allowlisted key's value is redacted here exactly as it is before egress
/// to Sentry — add fields to `kTelemetryAllowlist` if you need them visible.
/// `name`/`message` are compile-time constants by the facade contract, so they
/// print as-is.
class ConsoleAnalyticsLogger implements AnalyticsLogger {
  const ConsoleAnalyticsLogger();

  static const _name = 'balsm';

  @override
  void logEvent(String name, {Map<String, Object?>? props, bool key = false}) {
    developer.log(
      '${key ? '★ ' : '▸ '}$name${_fmt(props)}',
      name: '$_name.event',
      level: 800, // INFO
    );
  }

  @override
  void log(String message,
      {LogLevel level = LogLevel.info, Map<String, Object?>? props}) {
    developer.log(
      '$message${_fmt(props)}',
      name: '$_name.log',
      level: _level(level),
    );
  }

  @override
  void logError(Object error,
      {StackTrace? stackTrace,
      String? message,
      Map<String, Object?>? context,
      bool fatal = false}) {
    developer.log(
      '${fatal ? 'FATAL ' : ''}${message ?? error.toString()}${_fmt(context)}',
      name: '$_name.error',
      level: fatal ? 1200 : 1000, // SEVERE / ERROR
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void setUser(String? id) {
    // Opaque, non-PHI id by the facade contract — safe to print verbatim.
    developer.log('setUser($id)', name: '$_name.user', level: 700);
  }

  @override
  Future<void> flush() async {}

  String _fmt(Map<dynamic, dynamic>? props) {
    final scrubbed = scrubTelemetry(props);
    return scrubbed.isEmpty ? '' : ' $scrubbed';
  }

  int _level(LogLevel l) => switch (l) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      };
}
