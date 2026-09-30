import '../dev/dev_log_buffer.dart';
import 'analytics_logger.dart';
import 'telemetry_scrubber.dart';

/// [AnalyticsLogger] that appends every call to the Dev Config log buffer, so
/// "Send to Sentry" / "Save encrypted file" carry the app's real trail.
///
/// The buffer used to hook only `debugPrint` and uncaught errors, and the app
/// logs through this facade instead, so a manual diagnostic bundle arrived
/// empty. Add this sink only where the buffer is installed (dev/staging): prod
/// never holds app logs in memory.
///
/// PHI: identical to [ConsoleAnalyticsLogger] — `props`/`context` go through
/// [scrubTelemetry] (deny-by-default) and `name`/`message` are compile-time
/// constants. The bundle adds `DevDiagnostics.redactLine` on top before egress.
class DevLogAnalyticsLogger implements AnalyticsLogger {
  DevLogAnalyticsLogger({DevLogBuffer? buffer}) : _buffer = buffer ?? DevLogBuffer.instance;

  final DevLogBuffer _buffer;

  @override
  void logEvent(String name, {Map<String, Object?>? props, bool key = false}) =>
      _buffer.add('log', '${key ? '★ ' : '▸ '}$name${_fmt(props)}');

  @override
  void log(String message, {LogLevel level = LogLevel.info, Map<String, Object?>? props}) => _buffer.add(
        switch (level) {
          LogLevel.warning => 'warn',
          LogLevel.error => 'error',
          LogLevel.debug || LogLevel.info => 'log',
        },
        '$message${_fmt(props)}',
      );

  /// The error's type only, never `toString()`: exception messages can quote
  /// the data that failed (a name, a value), and that text isn't scrubbed.
  @override
  void logError(Object error,
          {StackTrace? stackTrace, String? message, Map<String, Object?>? context, bool fatal = false}) =>
      _buffer.add('error', '${fatal ? 'FATAL ' : ''}${message ?? error.runtimeType}${_fmt(context)}');

  @override
  void setUser(String? id) {}

  @override
  Future<void> flush() async {}

  String _fmt(Map<String, Object?>? props) {
    final scrubbed = scrubTelemetry(props);
    return scrubbed.isEmpty ? '' : ' $scrubbed';
  }
}
