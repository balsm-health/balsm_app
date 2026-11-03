/// Sex recorded on a managed (dependent) health profile — used for growth
/// references and grammatically gendered copy about that person.
///
/// Null on the profile means "not recorded". Never set on a prenatal profile:
/// the app does not record fetal sex before birth (Mother & Child design rule,
/// enforced by `HealthProfile`). Distinct from [Gender], which describes the
/// signed-in account holder for copy addressed to them.
///
/// Persisted as [wire] in `health_profile.sex`.
enum Sex {
  female,
  male;

  /// Stable stored code (the enum name). Locale-independent.
  String get wire => name;

  /// Parses a stored code; null for null/unknown.
  static Sex? tryFromWire(String? code) {
    for (final s in values) {
      if (s.name == code) return s;
    }
    return null;
  }
}
