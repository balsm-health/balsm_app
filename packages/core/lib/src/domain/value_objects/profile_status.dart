/// Lifecycle of a health profile. A [closed] profile keeps every record it
/// holds (soft-close, never a delete) but can no longer be the active profile:
/// selecting one falls back to the account holder's self profile.
///
/// Persisted as [wire] in `health_profile.status`.
enum ProfileStatus {
  active,
  closed;

  /// Stable stored code (the enum name). Locale-independent.
  String get wire => name;

  /// Parses a stored code; unknown or null reads as [active] — the value every
  /// pre-existing row was backfilled with.
  static ProfileStatus fromWire(String? code) => code == closed.name ? closed : active;
}
