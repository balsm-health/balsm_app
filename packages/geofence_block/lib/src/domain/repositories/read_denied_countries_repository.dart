/// Read-side repository exposing the set of country codes for which signup is
/// geofence-blocked.
///
/// PHI-free: country codes are not personal health information.
abstract interface class ReadDeniedCountriesRepository {
  /// Returns `true` when [countryCode] (ISO-3166 alpha-2) is on the deny list.
  Future<bool> isDenied(String countryCode);

  /// Emits the current list of denied country codes whenever it changes.
  Stream<List<String>> watchDeniedCountryCodes();
}
