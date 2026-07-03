/// The single canonical set of **non-PHI** keys allowed to leave the device in
/// telemetry (breadcrumbs, event contexts, Sentry payloads). Deny-by-default:
/// any key NOT in this set is redacted before egress (see [scrubTelemetry]).
///
/// PHI rule: never add a key that can carry email, handle, user id, date of
/// birth, medication/condition names, free-text, or any health data. When in
/// doubt, leave it out — the scrub will redact it.
///
/// `balsm_api`'s `PhiLeakInterceptor` keeps its own copy (core must not depend
/// on it in reverse); the PHI-leak fuzz test guards that the copies agree.
library;

const Set<String> kTelemetryAllowlist = {
  // Sentry envelope / diagnostic fields
  'event_id', 'timestamp', 'platform', 'level', 'logger', 'transaction',
  'environment', 'release', 'dist', 'type', 'value', 'reason',
  // Stacktrace frame fields
  'stacktrace', 'module', 'function', 'filename', 'lineno', 'colno', 'abs_path',
  // HTTP diagnostics (non-PHI)
  'status_code', 'method', 'url', 'correlationId',
  // Non-PHI domain/telemetry fields
  'expires_in_seconds', 'ttl_seconds', 'is_new_user', 'deletion_state',
  'token_id', 'expires_at', 'revoked', 'revoked_count',
  // Analytics dimensions
  'route', 'screen', 'action', 'name', 'category', 'count', 'duration_ms',
  'flavor', 'locale',
};
