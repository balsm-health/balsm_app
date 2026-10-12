import 'package:balsm_api/balsm_api.dart';

import '../data_source/key_value_data_source.dart';
import 'analytics_consent.dart';

/// Campaign parameters read off the link that brought someone in.
///
/// Only these, and only from the query string. They describe the ad or post,
/// never the person, and every one is on [kNonPhiAllowlist] — a parameter that
/// is not on this list is ignored rather than passed through, so a marketing
/// link cannot smuggle an arbitrary key into telemetry.
const Set<String> kCampaignParameters = {
  'utm_source',
  'utm_medium',
  'utm_campaign',
  'utm_content',
  'utm_term',
  'campaign',
  'referrer',
};

/// Extracts the campaign parameters from [uri]'s query. Empty when there are
/// none, which is the common case (a normal launch has no link at all).
///
/// Values are length-capped: these end up on every subsequent event as super
/// properties, and a link is attacker-controllable input from the app's point
/// of view.
Map<String, String> campaignPropertiesFrom(Uri uri) {
  final out = <String, String>{};
  uri.queryParameters.forEach((key, value) {
    final k = key.toLowerCase();
    if (!kCampaignParameters.contains(k)) return;
    final v = value.trim();
    if (v.isEmpty) return;
    out[k] = v.length > 100 ? v.substring(0, 100) : v;
  });
  return out;
}

/// First-touch campaign as super properties, renamed `initial_<param>`.
///
/// The rename is what keeps the two attributions apart. Registered super
/// properties ride on every event, and an event prop of the SAME name overrides
/// them only on the events that set it. Registering first touch as plain
/// `utm_campaign` would mean `deep_link_opened` reports the link's own campaign
/// while an organic open silently inherits the install's — the same column
/// meaning two different things. `initial_*` mirrors PostHog's own
/// `$initial_utm_*` convention on the web SDK, so both surfaces read alike.
Map<String, String> initialCampaignSuperProperties(Map<String, String> firstTouch) => {
      for (final e in firstTouch.entries) 'initial_${e.key}': e.value,
    };

/// First-touch campaign attribution.
///
/// **First touch, not last.** The question a campaign report answers is "which
/// ad produced this patient", and that is settled by the first link that ever
/// opened the app. Overwriting it on a later link would re-attribute an
/// existing patient to whatever they most recently clicked, which flatters
/// retargeting and loses the acquisition source entirely.
///
/// Stored in the device-wide telemetry preference group, so it survives
/// sign-out like the analytics consent beside it.
class CampaignAttribution {
  const CampaignAttribution._();

  /// Returns the campaign to attribute this install to, recording [launchUri]'s
  /// parameters if nothing has been recorded yet.
  ///
  /// Never throws: a malformed link must not stop the app booting.
  static Future<Map<String, String>> resolve(
    GlobalKVDataSource kv, {
    Uri? launchUri,
  }) async {
    try {
      final prefs = TelemetryPrefs(kv);
      final stored = _filter(await prefs.campaign());
      if (stored.isNotEmpty) return stored;

      if (launchUri == null) return const {};
      final fresh = campaignPropertiesFrom(launchUri);
      if (fresh.isEmpty) return const {};
      await prefs.setCampaign(fresh);
      return fresh;
    } catch (_) {
      // Attribution is never worth a failed launch.
      return const {};
    }
  }

  /// Re-applies the allowlist on read, so a value written by an older build
  /// cannot widen what reaches telemetry today.
  static Map<String, String> _filter(Map<String, dynamic>? raw) {
    if (raw == null) return const {};
    return {
      for (final e in raw.entries)
        if (kCampaignParameters.contains(e.key) && e.value is String) e.key: e.value as String,
    };
  }
}
