import 'package:posthog_flutter/posthog_flutter.dart';

import 'feature_flags.dart';

/// Flags served by PostHog.
///
/// Asking PostHog for flags sends it this device's analytics id, so it is
/// product analytics as far as the patient's choice goes: with [allowed] false
/// — no PostHog project in this build, or the patient opted out — no request
/// is made and every flag reads as "no opinion".
///
/// `initPostHog` keeps `preloadFeatureFlags` off, so [refresh] is the only
/// thing that fetches them.
class PostHogFlagSource implements FeatureFlagSource {
  PostHogFlagSource({required bool Function() allowed}) : _allowed = allowed;

  final bool Function() _allowed;

  /// False until one fetch has completed with consent on. Without it the SDK
  /// would answer from flags it cached before the patient opted out.
  bool _fetched = false;

  @override
  String get name => 'posthog';

  @override
  Future<void> refresh() async {
    if (!_allowed()) {
      _fetched = false;
      return;
    }
    await Posthog().reloadFeatureFlags();
    _fetched = true;
  }

  @override
  Future<bool?> read(String key) async {
    if (!_fetched || !_allowed()) return null;
    final value = await Posthog().getFeatureFlag(key);
    // A boolean flag is itself. A multivariate flag is on for any variant: the
    // app's flags are switches, and a variant name means "in the rollout".
    if (value is bool) return value;
    if (value is String) return value.isNotEmpty;
    return null;
  }
}
