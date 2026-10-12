import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every call instead of reaching the platform channel.
class _FakePostHogClient implements PostHogClient {
  final captures = <({String event, Map<String, Object>? props})>[];
  final identified = <String>[];
  int resets = 0;
  int enables = 0;
  int disables = 0;
  int flushes = 0;

  @override
  Future<void> capture(String eventName, Map<String, Object>? properties) async {
    captures.add((event: eventName, props: properties));
  }

  @override
  Future<void> identify(String userId) async => identified.add(userId);

  @override
  Future<void> reset() async => resets++;

  @override
  Future<void> enable() async => enables++;

  @override
  Future<void> disable() async => disables++;

  @override
  Future<void> flush() async => flushes++;
}

/// A client whose every call fails — telemetry must never surface an error to
/// the app (an unawaited failure would otherwise reach
/// `platformDispatcher.onError`, which reports through this same logger).
class _ThrowingPostHogClient implements PostHogClient {
  @override
  Future<void> capture(String eventName, Map<String, Object>? properties) async => throw StateError('boom');

  @override
  Future<void> identify(String userId) async => throw StateError('boom');

  @override
  Future<void> reset() async => throw StateError('boom');

  @override
  Future<void> enable() async => throw StateError('boom');

  @override
  Future<void> disable() async => throw StateError('boom');

  @override
  Future<void> flush() async => throw StateError('boom');
}

void main() {
  group('scrubPostHogProperties', () {
    test('allowlisted keys survive, unknown keys are redacted', () {
      final out = scrubPostHogProperties({
        'route': '/meds',
        'utm_campaign': 'ramadan-2026',
        'email': 'a@b.c',
        'medication': 'metformin',
      });
      expect(out['route'], '/meds');
      expect(out['utm_campaign'], 'ramadan-2026');
      expect(out['email'], '[redacted]');
      expect(out['medication'], '[redacted]');
    });

    test(r'$-prefixed SDK properties pass through untouched', () {
      final out = scrubPostHogProperties({r'$screen_name': '/meds', r'$app_version': '1.2.0'});
      expect(out[r'$screen_name'], '/meds');
      expect(out[r'$app_version'], '1.2.0');
    });

    test('null values are dropped, not redacted to null', () {
      final out = scrubPostHogProperties({'count': null, r'$screen_name': null, 'route': '/home'});
      expect(out.containsKey('count'), isFalse);
      expect(out.containsKey(r'$screen_name'), isFalse);
      expect(out['route'], '/home');
    });

    test('a non-allowlisted key redacts its whole nested value', () {
      final out = scrubPostHogProperties({
        'profile': {'email': 'a@b.c', 'dob': '1990-01-01'},
      });
      expect(out['profile'], '[redacted]');
    });

    test('null / empty tolerated', () {
      expect(scrubPostHogProperties(null), isEmpty);
      expect(scrubPostHogProperties(const {}), isEmpty);
    });
  });

  group('PostHogAnalyticsLogger', () {
    test('logEvent captures with scrubbed props, ignoring the key flag', () async {
      final client = _FakePostHogClient();
      PostHogAnalyticsLogger(client: client)
        ..logEvent('dose_taken', props: {'count': 2, 'medication': 'metformin'})
        ..logEvent('emergency_qr_token_minted', key: true);
      await pumpEventQueue();

      expect(client.captures.map((c) => c.event), ['dose_taken', 'emergency_qr_token_minted']);
      expect(client.captures.first.props, {'count': 2, 'medication': '[redacted]'});
    });

    test('debug/info logs are dropped; warning/error become one app_log event', () async {
      final client = _FakePostHogClient();
      PostHogAnalyticsLogger(client: client)
        ..log('cache miss', level: LogLevel.debug)
        ..log('cache miss', level: LogLevel.info)
        ..log('retry exhausted', level: LogLevel.warning);
      await pumpEventQueue();

      expect(client.captures, hasLength(1));
      expect(client.captures.single.event, kPostHogLogEvent);
      expect(client.captures.single.props, {'log_message': 'retry exhausted', 'level': 'warning'});
    });

    test('logError carries the exception TYPE, never its message text', () async {
      final client = _FakePostHogClient();
      PostHogAnalyticsLogger(client: client).logError(
        FormatException('patient dob 1990-01-01 is invalid'),
        message: 'mint failed',
        fatal: true,
      );
      await pumpEventQueue();

      final props = client.captures.single.props!;
      expect(client.captures.single.event, kPostHogErrorEvent);
      expect(props['type'], 'FormatException');
      expect(props['level'], 'fatal');
      expect(props['log_message'], 'mint failed');
      expect(props.values.join(' '), isNot(contains('1990-01-01')));
    });

    test('setUser identifies with the opaque id; null resets', () async {
      final client = _FakePostHogClient();
      PostHogAnalyticsLogger(client: client)
        ..setUser('usr_123')
        ..setUser(null);
      await pumpEventQueue();

      expect(client.identified, ['usr_123']);
      expect(client.resets, 1);
    });

    test('disabled: every call is a no-op AND the SDK is opted out', () async {
      final client = _FakePostHogClient();
      final logger = PostHogAnalyticsLogger(client: client)..setAnalyticsEnabled(false);
      logger
        ..logEvent('dose_taken')
        ..log('retry exhausted', level: LogLevel.error)
        ..logError(StateError('x'))
        ..setUser('usr_123');
      await logger.flush();
      await pumpEventQueue();

      expect(client.disables, 1);
      expect(client.captures, isEmpty);
      expect(client.identified, isEmpty);
      expect(client.resets, 0);
      expect(client.flushes, 0);
    });

    test('re-enabling opts the SDK back in and resumes capture', () async {
      final client = _FakePostHogClient();
      final logger = PostHogAnalyticsLogger(client: client, enabled: false)..setAnalyticsEnabled(true);
      logger.logEvent('dose_taken');
      await pumpEventQueue();

      expect(client.enables, 1);
      expect(logger.enabled, isTrue);
      expect(client.captures, hasLength(1));
    });

    test('an unchanged consent value does not re-toggle the SDK', () async {
      final client = _FakePostHogClient();
      PostHogAnalyticsLogger(client: client).setAnalyticsEnabled(true);
      await pumpEventQueue();

      expect(client.enables, 0);
      expect(client.disables, 0);
    });

    test('a failing backend never surfaces an error to the caller', () async {
      final logger = PostHogAnalyticsLogger(client: _ThrowingPostHogClient());
      logger
        ..logEvent('dose_taken')
        ..log('boom', level: LogLevel.error)
        ..logError(StateError('x'))
        ..setUser('usr_123')
        ..setAnalyticsEnabled(false);
      await expectLater(logger.flush(), completes);
      await pumpEventQueue();
    });
  });
}
