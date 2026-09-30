import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Dev Config log bundle is filled by this sink. It is a log sink like
/// Sentry or the console, so it must scrub the same way before anything is
/// buffered.
void main() {
  final buffer = DevLogBuffer.instance;
  setUp(buffer.clear);

  test('events, logs and errors land in the buffer at the right level', () {
    DevLogAnalyticsLogger(buffer: buffer)
      ..logEvent('deep_link_opened', props: {'source': 'map', 'result': 'ok'})
      ..log('sync_started')
      ..log('sync_slow', level: LogLevel.warning)
      ..logError(StateError('boom'), message: 'sync_failed');
    expect(buffer.entries.map((e) => e.level), ['log', 'log', 'warn', 'error']);
    expect(buffer.entries.first.message, contains('source'));
    expect(buffer.entries.first.message, contains('map'));
    expect(buffer.errorCount, 1);
    expect(buffer.warnCount, 1);
  });

  test('a value under a non-allowlisted key never reaches the buffer', () {
    DevLogAnalyticsLogger(buffer: buffer).logEvent('medication_added', props: {'medication': 'Metformin 500mg'});
    expect(buffer.entries.single.message, isNot(contains('Metformin')));
  });

  test('an exception\'s own text is not buffered — only its type', () {
    DevLogAnalyticsLogger(buffer: buffer).logError(Exception('patient Layla Hassan, DOB 1990-01-01'));
    final line = buffer.entries.single.message;
    expect(line, isNot(contains('Layla')));
    expect(line, isNot(contains('1990')));
  });
}
