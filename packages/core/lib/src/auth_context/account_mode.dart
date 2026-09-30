/// Whether the signed-in account has server credentials.
///
/// `deviceOnly` accounts were created offline: they have a `balsm.user_id`
/// but no access/refresh token, and must never reach an authenticated
/// endpoint (a 401 there would run the sign-out path and orphan their data).
enum AccountMode {
  online,
  deviceOnly;

  String get wire => name;

  static AccountMode fromWire(String? v) => v == deviceOnly.name ? deviceOnly : online;
}

/// Secure-storage key holding [AccountMode.wire].
const kAccountModeKey = 'balsm.account_mode';

/// Raised locally instead of sending an authenticated request for a
/// device-only account. Callers treat it like being offline.
class DeviceOnlyAccountException implements Exception {
  const DeviceOnlyAccountException();
  @override
  String toString() => 'DeviceOnlyAccountException';
}
