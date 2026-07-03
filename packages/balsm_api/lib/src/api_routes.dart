/// Single source of truth for every Balsm API path.
///
/// Keep this 1:1 with the .NET controllers so the wire contract stays
/// diffable in one place. Fixed paths are `static const`; paths carrying a
/// path parameter are `static String` builders. Never write a `'/…'` route
/// literal at a call site — reference a member here.
///
/// Grouped per backend module; each group builds its leaves from one base
/// constant so the prefix lives in exactly one spot.
class ApiRoutes {
  ApiRoutes._();

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const _auth = '/auth';
  static const authOtpRequest = '$_auth/otp/request';
  static const authOtpVerify = '$_auth/otp/verify';
  static const authGoogle = '$_auth/google';
  static const authApple = '$_auth/apple';
  static const authSignOut = '$_auth/sign-out';
  static const authRefresh = '$_auth/refresh';
  static const authRecoveryClaim = '$_auth/recovery/claim';

  // ── Account ───────────────────────────────────────────────────────────────
  static const _account = '/account';
  static const accountSelf = '$_account/self';
  static const accountHandleClaim = '$_account/handle/claim';
  static const accountHandleAvailable = '$_account/handle/available';
  static const accountLanguage = '$_account/language';
  static const accountCountry = '$_account/country';

  // ── Emergency QR ──────────────────────────────────────────────────────────
  static const _emergencyQr = '/emergency-qr';
  static const emergencyQrMint = '$_emergencyQr/mint';
  static const emergencyQrRevoke = '$_emergencyQr/revoke';
  static String emergencyQrResolve(String tokenId) =>
      '$_emergencyQr/resolve/$tokenId';

  // ── Sessions ──────────────────────────────────────────────────────────────
  static const _sessions = '/sessions';
  static const sessions = _sessions;
  static const sessionsRevokeAll = '$_sessions/revoke-all';
  static String session(String sessionId) => '$_sessions/$sessionId';

  // ── Deletion ──────────────────────────────────────────────────────────────
  static const _deletion = '/deletion';
  static const deletionIntake = '$_deletion/intake';
  static const deletionCancel = '$_deletion/cancel';

  // ── Disclosure ────────────────────────────────────────────────────────────
  static const disclosureAccept = '/disclosure/accept';

  // ── Geofence ──────────────────────────────────────────────────────────────
  static const geofenceDeniedCountries = '/geofence/denied-countries';
}
