import 'package:balsm_api/balsm_api.dart';

import 'allowlist.dart';

/// Replacement value for a key that is not on [kTelemetryAllowlist]. Aliases the
/// canonical marker so every scrubber on an egress path uses the same one.
const kTelemetryRedacted = kRedacted;

/// Deny-by-default scrub for any telemetry map (breadcrumb data, event props,
/// error context). Every top-level key not in [kTelemetryAllowlist] has its
/// value replaced by `'[redacted]'`. Shallow by design (matches
/// `PhiLeakInterceptor.scrubForTelemetry`): a non-allowlisted key's entire
/// value — including any nested PHI — is redacted wholesale.
///
/// Allowlisting a key is not always enough: a URL-valued key keeps its name but
/// has its value reduced to a route template with no query and no fragment,
/// because the emergency-QR AES key and the magic sign-in token live in exactly
/// those two parts. See [redactUrl].
Map<String, dynamic> scrubTelemetry(Map<dynamic, dynamic>? data) {
  if (data == null || data.isEmpty) return const {};
  return {
    for (final e in data.entries)
      e.key.toString(): kTelemetryAllowlist.contains(e.key.toString())
          ? redactIfUrlValued(e.key.toString(), e.value)
          : kTelemetryRedacted,
  };
}
