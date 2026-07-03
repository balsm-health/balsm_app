import 'allowlist.dart';

const _redacted = '[redacted]';

/// Deny-by-default scrub for any telemetry map (breadcrumb data, event props,
/// error context). Every top-level key not in [kTelemetryAllowlist] has its
/// value replaced by `'[redacted]'`. Shallow by design (matches
/// `PhiLeakInterceptor.scrubForTelemetry`): a non-allowlisted key's entire
/// value — including any nested PHI — is redacted wholesale.
Map<String, dynamic> scrubTelemetry(Map<dynamic, dynamic>? data) {
  if (data == null || data.isEmpty) return const {};
  return {
    for (final e in data.entries)
      e.key.toString():
          kTelemetryAllowlist.contains(e.key.toString()) ? e.value : _redacted,
  };
}
