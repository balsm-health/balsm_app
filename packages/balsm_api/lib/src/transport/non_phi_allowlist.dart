/// The single canonical set of **non-PHI** field names allowed to leave the
/// device, and the redaction applied to the ones that are allowed by name but
/// whose *value* can still carry a secret.
///
/// Deny-by-default: any key NOT in [kNonPhiAllowlist] has its value replaced by
/// [kRedacted] on every egress path.
///
/// **This file is the only copy.** It lives in `balsm_api` rather than `core`
/// because `core` depends on `balsm_api` and not the reverse, so this is the
/// lowest package both egress paths can reach:
///
/// - `PhiLeakInterceptor.scrubForTelemetry` — the safe copy of an API request
///   body handed to loggers.
/// - `core`'s `kTelemetryAllowlist` / `scrubTelemetry` — analytics props,
///   breadcrumb data, error contexts (Sentry + PostHog).
///
/// It used to be duplicated across four places that had already drifted apart.
/// Do not reintroduce a second copy — alias this one.
///
/// PHI rule: never add a key that can carry email, handle, user id, date of
/// birth, medication/condition names, free text, or any health data. When in
/// doubt, leave it out — the scrub will redact it.
library;

/// Replacement value for a key that is not on [kNonPhiAllowlist].
const String kRedacted = '[redacted]';

const Set<String> kNonPhiAllowlist = {
  // Sentry envelope / diagnostic fields
  'event_id', 'timestamp', 'platform', 'level', 'logger', 'transaction',
  'environment', 'release', 'dist', 'type', 'value', 'reason',
  // Stacktrace frame fields
  'stacktrace', 'module', 'function', 'filename', 'lineno', 'colno', 'abs_path',
  // HTTP diagnostics (non-PHI). NOTE: 'url' and 'transaction' are allowed by
  // NAME but their VALUE is rewritten by [redactUrl] — see below.
  'status_code', 'method', 'url', 'correlationId',
  // Non-PHI domain/telemetry fields
  'expires_in_seconds', 'ttl_seconds', 'is_new_user', 'deletion_state',
  'token_id', 'expires_at', 'revoked', 'revoked_count',
  // Analytics dimensions.
  //
  // 'name' is deliberately ABSENT. It is the most collision-prone key in a
  // health app — medication name, allergy name, condition name, contact name,
  // patient name are all PHI and all serialize to `name`. It used to be on this
  // list, and `MedicationAdded.toJson()` carries `'name': <medication>`, which
  // the EventBusAnalyticsForwarder forwards verbatim — so medication names were
  // reaching telemetry as searchable events. Use a key that can only ever hold a
  // constant, like 'log_message', never 'name'.
  'route', 'screen', 'action', 'category', 'count', 'duration_ms',
  // A compile-time-constant log/error label. Never user data — the
  // AnalyticsLogger contract requires messages to be constants.
  'log_message',
  // Build identity (brand: balsm/balsm_pro, flavor: dev/staging/prod).
  'flavor', 'brand', 'locale',
  // Product-analytics dimensions. Structural only — a funnel step index, an
  // experiment arm, the state a toggle moved to.
  'step', 'variant', 'enabled', 'source', 'result',
  // Campaign attribution. These describe the ad that produced the install,
  // never the person.
  // Plain `utm_*` = the campaign on THIS event (e.g. the link that just opened
  // the app); `initial_*` = first touch, registered once as super properties.
  'campaign', 'referrer',
  'utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term',
  'initial_campaign', 'initial_referrer',
  'initial_utm_source', 'initial_utm_medium', 'initial_utm_campaign', 'initial_utm_content', 'initial_utm_term',
};

/// Keys whose value is a URL and must be reduced before egress. Allowlisting
/// the key is not enough — see [redactUrl].
const Set<String> kUrlValuedKeys = {'url', 'transaction', 'referrer'};

/// Path segments that are real route names rather than identifiers. Anything
/// else long enough to be an id or token is masked by [redactUrl].
const Set<String> _knownPathSegments = {
  'api',
  'v1',
  'v2',
  'auth',
  'account',
  'profile',
  'emergency',
  'care',
  'link',
  'health',
  'sessions',
  'deletion',
  'disclosure',
  'medications',
  'records',
  'prescriptions',
  'geofence',
  'directory',
  'packs',
  'delete',
  'me',
  't',
};

/// Reduces a URL to a parameterized route template, with **no query and no
/// fragment**.
///
/// This is a confidentiality control, not tidiness. Two concrete secrets ride
/// in those parts:
///
/// - The emergency-QR AES key is the URL **fragment** (`/t/{jti}#k=<key>`). It
///   is the one thing that makes the ciphertext on the server readable, and it
///   is never supposed to exist off the device outside the QR image itself. An
///   un-stripped href in a breadcrumb would hand it to the telemetry backend.
/// - The magic sign-in link carries its token in the **query**
///   (`balsm://auth/link?t=<token>`), which is a live credential.
///
/// Opaque path segments (a jti, a uuid, a handle) are replaced with `:id`, so
/// `/t/01J8.../` becomes `/t/:id` — enough to group routes in a dashboard,
/// not enough to identify anyone.
///
/// Unparseable input is redacted wholesale rather than passed through.
String redactUrl(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null) return kRedacted;

  final segments =
      uri.pathSegments.map((s) => _knownPathSegments.contains(s.toLowerCase()) ? s : ':id').toList(growable: false);
  final path = segments.isEmpty ? '' : '/${segments.join('/')}';

  // Rebuilt field by field: query and fragment are dropped by omission, so a
  // new URL part can never be forwarded by accident.
  if (!uri.hasScheme) return path.isEmpty ? kRedacted : path;
  final authority = uri.hasAuthority ? '//${uri.host}${uri.hasPort ? ':${uri.port}' : ''}' : '';
  return '${uri.scheme}:$authority$path';
}

/// Applies [redactUrl] when [key] is URL-valued, otherwise returns [value].
Object? redactIfUrlValued(String key, Object? value) =>
    kUrlValuedKeys.contains(key) && value is String ? redactUrl(value) : value;
