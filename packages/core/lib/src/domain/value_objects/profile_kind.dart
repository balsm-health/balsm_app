/// What a health profile on this device is about — the account holder
/// themself, a person they manage, or a baby before birth.
///
/// Persisted as [wire] in `health_profile.kind`. Exactly one [self] profile
/// exists per account (`health_profile.is_self = 1`); [dependent] and
/// [prenatal] profiles are siblings under the same account, each its own
/// PHI partition. Birth turns a [prenatal] profile into a [dependent] one and
/// keeps its id, so the prenatal records become the child's earliest history.
enum ProfileKind {
  self,
  dependent,
  prenatal;

  /// Stable stored code (the enum name). Locale-independent.
  String get wire => name;

  /// Parses a stored code; unknown or null falls back to [dependent] — the
  /// kind that can never be mistaken for the account holder.
  static ProfileKind fromWire(String? code) {
    for (final k in values) {
      if (k.name == code) return k;
    }
    return dependent;
  }
}
