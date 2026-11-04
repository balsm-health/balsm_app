/// How the requester says the other person is related to them — the relation
/// chips of the "Add family member" flow, and the wire code of a link's
/// `relation`. A child or parent chip carries the person's sex because the
/// chip does (son, daughter, mother, father).
enum LinkRelation {
  son,
  daughter,
  mother,
  father,
  spouse,
  neighbour,
  friend,
  other;

  /// Stable wire code (the enum name). Locale-independent.
  String get wire => name;

  /// Parses a wire code; anything unknown reads as [other].
  static LinkRelation fromWire(String? code) {
    final c = code?.trim().toLowerCase();
    for (final r in values) {
      if (r.name == c) return r;
    }
    return other;
  }
}
