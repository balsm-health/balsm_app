import 'package:app/balsm_app/app_state.dart';
import 'package:app/balsm_app/screens/profile_subscreens.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the PostHog backend: records what consent it was handed.
class _RecordingSink implements AnalyticsConsentSink {
  final applied = <bool>[];

  @override
  void setAnalyticsEnabled(bool enabled) => applied.add(enabled);
}

/// Records every facade call, so we can assert nothing is emitted after an
/// opt-out.
class _RecordingLogger implements AnalyticsLogger {
  final events = <String>[];

  @override
  void logEvent(String name, {Map<String, Object?>? props, bool key = false}) => events.add(name);

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

/// Profile → Privacy & data → "Anonymous analytics" is the patient's product
/// analytics switch. It is the one toggle on that screen that is wired to
/// anything, so it gets its own test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
      ({
        AnalyticsConsent consent,
        _RecordingSink sink,
        _RecordingLogger logger,
        TelemetryPrefs prefs,
        PatientAppState state
      })> pump(
    WidgetTester tester, {
    Map<String, Object> seed = const {},
  }) async {
    SharedPreferences.setMockInitialValues(seed);
    final kv = SharedPrefsKVDataSource(await SharedPreferences.getInstance());
    final sink = _RecordingSink();
    final consent = await AnalyticsConsent.load(kv, sinks: [sink]);
    final logger = _RecordingLogger();
    final state = PatientAppState();

    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        analyticsConsentProvider.overrideWith((ref) => consent),
        analyticsLoggerProvider.overrideWithValue(logger),
      ],
      child: AppScope(
        state: state,
        child: MaterialApp(home: PrivacyDataScreen(s: state)),
      ),
    ));
    await tester.pumpAndSettle();
    return (consent: consent, sink: sink, logger: logger, prefs: TelemetryPrefs(kv), state: state);
  }

  /// The row's switch: the `_PSwitch` GestureDetector that follows the label.
  Finder analyticsSwitch(WidgetTester tester, PatientAppState s) {
    final row = find.ancestor(
      of: find.text(s.strings.privacy.pv_analytics),
      matching: find.byType(Row),
    );
    return find.descendant(of: row.last, matching: find.byType(GestureDetector)).first;
  }

  testWidgets('a fresh install shows analytics ON (opt-out model)', (tester) async {
    final env = await pump(tester);
    expect(env.consent.enabled, isTrue);
    expect(env.sink.applied, [true]);
  });

  testWidgets('a persisted opt-out is reflected in the toggle', (tester) async {
    final env = await pump(tester, seed: {'telemetry.analyticsEnabled': false});
    expect(env.consent.enabled, isFalse);
    expect(env.sink.applied, [false]);
  });

  testWidgets('turning it off persists, reaches the backend, and emits nothing after', (tester) async {
    final env = await pump(tester);

    await tester.tap(analyticsSwitch(tester, env.state));
    await tester.pumpAndSettle();

    expect(env.consent.enabled, isFalse);
    // The backend is told BEFORE the change event is logged, so the event that
    // records the opt-out is itself already gated.
    expect(env.sink.applied, [true, false]);
    expect(await env.prefs.analyticsEnabled(), isFalse);
  });

  testWidgets('turning it back on persists and logs the change', (tester) async {
    final env = await pump(tester, seed: {'telemetry.analyticsEnabled': false});

    await tester.tap(analyticsSwitch(tester, env.state));
    await tester.pumpAndSettle();

    expect(env.consent.enabled, isTrue);
    expect(env.sink.applied, [false, true]);
    expect(env.logger.events, contains('analytics_consent_changed'));
    expect(await env.prefs.analyticsEnabled(), isTrue);
  });
}
