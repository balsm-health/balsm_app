import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_source/key_value_data_source.dart';
import '../data_source/module_preferences.dart';

/// Product analytics is ON until the patient turns it off (opt-OUT model) —
/// Profile → Privacy & data → "Anonymous analytics".
///
/// This flag governs **product analytics only** (PostHog: which screens are
/// used, which flows complete, campaign attribution). It deliberately does NOT
/// gate crash/error reporting (Sentry), which is diagnostic data the app needs
/// to stay safe to use and which carries no behavioural profile. Keeping the
/// two separate is why turning analytics off does not blind crash reporting.
const bool kAnalyticsConsentDefault = true;

/// Telemetry preference group (`telemetry.*`).
///
/// Device-wide (global KV, not the per-user store) on purpose: the choice
/// belongs to whoever holds the device, so it must survive sign-out and not be
/// silently re-enabled by the next account to sign in.
class TelemetryPrefs extends ModulePreferences {
  const TelemetryPrefs(super.kv) : super(namespace: 'telemetry');

  Future<bool> analyticsEnabled() async => await read<bool>('analyticsEnabled') ?? kAnalyticsConsentDefault;

  Future<void> setAnalyticsEnabled(bool v) => write('analyticsEnabled', v);

  /// First-touch campaign parameters, as captured from the link that first
  /// opened the app. Raw here; `CampaignAttribution` does the filtering.
  Future<Map<String, dynamic>?> campaign() => read<Map<String, dynamic>>('campaign');

  Future<void> setCampaign(Map<String, dynamic> v) => write('campaign', v);
}

/// A telemetry backend whose egress is gated on the patient's product-analytics
/// consent. Implemented by [PostHogAnalyticsLogger]; Sentry does not implement
/// it (see [kAnalyticsConsentDefault]).
abstract class AnalyticsConsentSink {
  /// Called with the current consent at boot and again on every change.
  void setAnalyticsEnabled(bool enabled);
}

/// The patient's product-analytics consent: loaded once at bootstrap, mutated
/// from the Privacy & data screen.
///
/// [set] is the single write path — it persists the choice, pushes it to every
/// [AnalyticsConsentSink] (so the backend stops collecting immediately, not on
/// the next launch), and notifies listeners.
class AnalyticsConsent extends ChangeNotifier {
  AnalyticsConsent({
    required bool enabled,
    required TelemetryPrefs prefs,
    List<AnalyticsConsentSink> sinks = const [],
  })  : _enabled = enabled,
        _prefs = prefs {
    sinks.forEach(addSink);
  }

  /// Reads the persisted choice and applies it to [sinks] before the first
  /// frame, so a patient who opted out never emits an event on this launch.
  static Future<AnalyticsConsent> load(
    GlobalKVDataSource kv, {
    List<AnalyticsConsentSink> sinks = const [],
  }) async {
    final prefs = TelemetryPrefs(kv);
    return AnalyticsConsent(enabled: await prefs.analyticsEnabled(), prefs: prefs, sinks: sinks);
  }

  final TelemetryPrefs _prefs;
  final _sinks = <AnalyticsConsentSink>[];
  bool _enabled;

  bool get enabled => _enabled;

  /// Registers a backend and immediately applies the current consent to it, so
  /// a sink built after [load] cannot start out disagreeing with the patient.
  void addSink(AnalyticsConsentSink sink) {
    _sinks.add(sink);
    sink.setAnalyticsEnabled(_enabled);
  }

  Future<void> set(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    for (final sink in _sinks) {
      sink.setAnalyticsEnabled(value);
    }
    notifyListeners();
    await _prefs.setAnalyticsEnabled(value);
  }
}

/// The patient's product-analytics consent. Overridden at bootstrap with the
/// loaded instance (same pattern as `patientAppStateProvider`); the default
/// throws so a screen can never read an unloaded consent and assume `true`.
final analyticsConsentProvider = ChangeNotifierProvider<AnalyticsConsent>(
  (ref) => throw UnimplementedError('analyticsConsentProvider is overridden at bootstrap'),
);
