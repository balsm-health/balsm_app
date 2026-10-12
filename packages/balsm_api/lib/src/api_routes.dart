// ignore_for_file: constant_identifier_names

/// Single source of truth for every Balsm API path.
///
/// Keep this 1:1 with the .NET controllers so the wire contract stays
/// diffable in one place. Fixed paths are `static const` (snake_case); paths
/// carrying a path parameter are `static String` builders (lowerCamelCase —
/// they are methods, not constants). Never write a `'/…'` route literal at a
/// call site — reference a member here.
///
/// Grouped per backend module; each group builds its leaves from one base
/// constant so the prefix lives in exactly one spot.
class ApiRoutes {
  ApiRoutes._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const _auth = '/auth';
  static const auth_otp_request = '$_auth/otp/request';
  static const auth_otp_verify = '$_auth/otp/verify';
  static const auth_otp_verify_link = '$_auth/otp/verify-link';
  static const auth_google = '$_auth/google';
  static const auth_apple = '$_auth/apple';
  static const auth_sign_out = '$_auth/sign-out';
  static const auth_refresh = '$_auth/refresh';
  static const auth_recovery_claim = '$_auth/recovery/claim';
  static const auth_password_sign_in = '$_auth/password/sign-in';
  static const auth_password = '$_auth/password';
  static const auth_password_reset = '$_auth/password/reset';

  // ── Account ───────────────────────────────────────────────────────────────
  static const _account = '/account';
  static const account_self = '$_account/self';
  static const account_handle_claim = '$_account/handle/claim';
  // Availability probe is a POST with a `{handle}` body (server: handle/check).
  static const account_handle_check = '$_account/handle/check';
  static const account_language = '$_account/language';
  static const account_country = '$_account/country';
  static const account_profile = '$_account/profile';

  // ── Emergency QR ──────────────────────────────────────────────────────────
  static const _emergency_qr = '/emergency-qr';
  static const emergency_qr_mint = '$_emergency_qr/mint';
  static const emergency_qr_active = '$_emergency_qr/active';
  static const emergency_qr_scans = '$_emergency_qr/scans';
  static String emergencyQrRevoke(String tokenId) => '$_emergency_qr/$tokenId/revoke';
  static String emergencyQrCiphertext(String tokenId) => '$_emergency_qr/$tokenId/ciphertext';
  static String emergencyQrResolve(String tokenId) => '$_emergency_qr/resolve/$tokenId';

  // ── Sessions ──────────────────────────────────────────────────────────────
  static const _sessions = '/sessions';
  static const sessions = _sessions;
  static const sessions_revoke_all = '$_sessions/revoke-all';
  static String session(String sessionId) => '$_sessions/$sessionId';

  // ── Deletion ──────────────────────────────────────────────────────────────
  static const _deletion = '/deletion';
  static const deletion_intake = '$_deletion/intake';
  static const deletion_cancel = '$_deletion/cancel';

  // ── Disclosure ────────────────────────────────────────────────────────────
  static const disclosure_accept = '/disclosure/accept';

  // ── Geofence ──────────────────────────────────────────────────────────────
  static const geofence_denied_countries = '/geofence/denied-countries';

  // ── Care directory ────────────────────────────────────────────────────────
  static const _care = '/care';
  static const care_entities = '$_care/entities';

  /// Map pins — the same search projected to id/type/lat/lng. ~99 bytes a pin
  /// against ~340 a full row, so the viewport can be covered instead of a knot
  /// around its centre.
  static const care_pins = '$_care/pins';

  /// One place by id — what a tapped pin fetches, since pins carry no details.
  static String careEntity(String id) => '$care_entities/$id';

  /// Offline map packs catalogue (basemap + places per governorate).
  static const care_packs = '$_care/packs';

  // ── Care team (the patient's own providers, cloud-mirrored) ───────────────
  // Distinct from the care directory above: that is Balsm-owned NON-PHI
  // reference data, this is the patient's own PHI.
  static const _care_team = '/care-team';
  static const care_team_providers = '$_care_team/providers';

  /// One provider by id — DELETE tombstones it server-side so the removal
  /// propagates to the patient's other devices.
  static String careTeamProvider(String id) => '$care_team_providers/$id';

  // ── Platform ──────────────────────────────────────────────────────────────
  /// Host readiness probe. Anonymous, and the only endpoint safe to call
  /// against a server the app is not signed in to — which is what the Dev
  /// Config connection check does.
  static const health = '/api/v1/health';
}
