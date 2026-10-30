import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_source/key_value_data_source.dart';
import 'analytics_consent.dart';

/// Screen recordings are OFF until the patient turns them on (opt-IN) —
/// Profile → Privacy & data → "Share screen recordings". Separate from, and
/// stricter than, product analytics: a recording shows how screens are used,
/// so it needs its own yes.
const bool kReplayConsentDefault = false;

/// The patient's screen-recording consent: loaded once at bootstrap, changed
/// from Privacy & data. Device-wide, like [AnalyticsConsent], so the next
/// account to sign in cannot inherit a yes it never gave.
class ReplayConsent extends ChangeNotifier {
  ReplayConsent({required bool enabled, required TelemetryPrefs prefs})
      : _enabled = enabled,
        _prefs = prefs;

  static Future<ReplayConsent> load(GlobalKVDataSource kv) async {
    final prefs = TelemetryPrefs(kv);
    return ReplayConsent(enabled: await prefs.replayEnabled(), prefs: prefs);
  }

  final TelemetryPrefs _prefs;
  bool _enabled;

  bool get enabled => _enabled;

  Future<void> set(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    await _prefs.setReplayEnabled(value);
  }
}

/// Overridden at bootstrap with the loaded instance; the default throws so a
/// screen can never read an unloaded consent and assume either answer.
final replayConsentProvider = ChangeNotifierProvider<ReplayConsent>(
  (ref) => throw UnimplementedError('replayConsentProvider is overridden at bootstrap'),
);

/// Starts and stops the vendor's screen recorder. The PostHog adapter
/// implements it; the gate never imports a vendor SDK.
abstract class ReplayRecorder {
  Future<void> start();
  Future<void> stop();
}

/// Records only while three things hold: analytics consent, screen-recording
/// consent, and a screen on [allowedRoutes]. Anything else — a health screen,
/// an unknown route, either switch off — stops the recorder. Deny by default:
/// it starts stopped and nothing records until [update] proves all three.
class SessionReplayGate implements AnalyticsConsentSink {
  SessionReplayGate({required ReplayRecorder recorder, required this.allowedRoutes}) : _recorder = recorder;

  final ReplayRecorder _recorder;

  /// Routes with no health data on them (sign-in funnel and the like).
  final Set<String> allowedRoutes;

  bool _analytics = false;
  bool _replay = false;
  String? _route;
  bool _recording = false;

  /// Whether the recorder is running now.
  bool get recording => _recording;

  @override
  void setAnalyticsEnabled(bool enabled) {
    _analytics = enabled;
    _apply();
  }

  /// Feed the current screen-recording consent and/or route.
  void update({bool? replayEnabled, String? route}) {
    if (replayEnabled != null) _replay = replayEnabled;
    if (route != null) _route = route;
    _apply();
  }

  void _apply() {
    final want = _analytics && _replay && _route != null && allowedRoutes.contains(_route);
    if (want == _recording) return;
    _recording = want;
    // Fire-and-forget: a recorder error must never break navigation.
    want ? _recorder.start().ignore() : _recorder.stop().ignore();
  }
}
