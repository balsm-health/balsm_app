/// Avatar colour of a member profile — the design's member palette
/// (`MC_TONES`). Presentation-only: stored as [wire] in `health_profile.tone`
/// so a member keeps the same colour everywhere; the app maps it to tokens.
enum MemberTone {
  aqua,
  emerald,
  blue,
  violet,
  mint;

  /// Stable stored code (the enum name).
  String get wire => name;

  /// Parses a stored code; null for null/unknown.
  static MemberTone? tryFromWire(String? code) {
    for (final t in values) {
      if (t.name == code) return t;
    }
    return null;
  }

  /// The tone for the [index]-th member, cycling through the palette — the
  /// design's `tones[s.members.length % tones.length]`.
  static MemberTone forIndex(int index) => values[index % values.length];
}
