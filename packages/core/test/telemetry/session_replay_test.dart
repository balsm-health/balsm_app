import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Recorder implements ReplayRecorder {
  final calls = <String>[];
  @override
  Future<void> start() async => calls.add('start');
  @override
  Future<void> stop() async => calls.add('stop');
}

/// Screen recording runs only with analytics consent, screen-recording
/// consent and an allowed screen — and stops the moment any of them is lost.
void main() {
  late _Recorder rec;
  late SessionReplayGate gate;

  setUp(() {
    rec = _Recorder();
    gate = SessionReplayGate(recorder: rec, allowedRoutes: {'welcome', 'otp'});
  });

  test('starts stopped and stays stopped until all three hold', () {
    gate.update(route: 'welcome');
    gate.setAnalyticsEnabled(true);
    expect(gate.recording, isFalse);
    expect(rec.calls, isEmpty);
    gate.update(replayEnabled: true);
    expect(gate.recording, isTrue);
    expect(rec.calls, ['start']);
  });

  test('leaving for a screen not on the list stops it', () {
    gate
      ..setAnalyticsEnabled(true)
      ..update(replayEnabled: true, route: 'otp');
    gate.update(route: 'app');
    expect(gate.recording, isFalse);
    expect(rec.calls, ['start', 'stop']);
  });

  test('switching either consent off stops it', () {
    gate
      ..setAnalyticsEnabled(true)
      ..update(replayEnabled: true, route: 'welcome');
    gate.setAnalyticsEnabled(false);
    expect(rec.calls, ['start', 'stop']);
    gate.setAnalyticsEnabled(true);
    gate.update(replayEnabled: false);
    expect(rec.calls, ['start', 'stop', 'start', 'stop']);
  });

  test('no duplicate calls while nothing changes', () {
    gate
      ..setAnalyticsEnabled(true)
      ..update(replayEnabled: true, route: 'welcome')
      ..update(route: 'otp')
      ..update(replayEnabled: true);
    expect(rec.calls, ['start']);
  });

  test('screen-recording consent defaults to off and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final kv = SharedPrefsKVDataSource(await SharedPreferences.getInstance());
    final consent = await ReplayConsent.load(kv);
    expect(kReplayConsentDefault, isFalse);
    expect(consent.enabled, isFalse);
    await consent.set(true);
    expect((await ReplayConsent.load(kv)).enabled, isTrue);
  });
}
