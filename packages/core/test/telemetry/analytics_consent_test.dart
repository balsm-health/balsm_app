import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingSink implements AnalyticsConsentSink {
  final applied = <bool>[];

  @override
  void setAnalyticsEnabled(bool enabled) => applied.add(enabled);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPrefsKVDataSource> kv([Map<String, Object>? seed]) async {
    SharedPreferences.setMockInitialValues(seed ?? {});
    return SharedPrefsKVDataSource(await SharedPreferences.getInstance());
  }

  test('fresh install: analytics is ON (opt-out model) and pushed to sinks', () async {
    final sink = _RecordingSink();
    final consent = await AnalyticsConsent.load(await kv(), sinks: [sink]);

    expect(kAnalyticsConsentDefault, isTrue);
    expect(consent.enabled, isTrue);
    expect(sink.applied, [true]);
  });

  test('a persisted opt-out is applied to sinks before the first frame', () async {
    final sink = _RecordingSink();
    final consent = await AnalyticsConsent.load(
      await kv({'telemetry.analyticsEnabled': false}),
      sinks: [sink],
    );

    expect(consent.enabled, isFalse);
    expect(sink.applied, [false]);
  });

  test('set persists, pushes to sinks, and notifies', () async {
    final sink = _RecordingSink();
    final store = await kv();
    final consent = await AnalyticsConsent.load(store, sinks: [sink]);
    var notified = 0;
    consent.addListener(() => notified++);

    await consent.set(false);

    expect(consent.enabled, isFalse);
    expect(sink.applied, [true, false]);
    expect(notified, 1);
    expect(await TelemetryPrefs(store).analyticsEnabled(), isFalse);
  });

  test('setting the value it already has is a no-op', () async {
    final sink = _RecordingSink();
    final consent = await AnalyticsConsent.load(await kv(), sinks: [sink]);
    var notified = 0;
    consent.addListener(() => notified++);

    await consent.set(true);

    expect(sink.applied, [true]); // only the boot-time apply
    expect(notified, 0);
  });

  test('the choice is device-wide, so it survives a re-load (sign-out/in)', () async {
    final store = await kv();
    await (await AnalyticsConsent.load(store)).set(false);

    expect((await AnalyticsConsent.load(store)).enabled, isFalse);
  });
}
