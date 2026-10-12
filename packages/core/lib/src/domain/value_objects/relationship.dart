/// Emergency-contact relationship — a fixed, localizable set.
///
/// A native enhanced enum (the modern replacement for the `super_enum`
/// package): each value carries a stable [wire] code (persisted / sent over the
/// wire, locale-independent) and a baked-in [englishLabel] fallback. The
/// localized display label lives in the core i69n bundle
/// (`relation.<name>`) and is resolved via the `RelationshipL10n` extension
/// (`localization/reference_l10n.dart`) — never a const field, mirroring
/// [CountryCode]'s name/demonym.
///
/// [other] is the neutral fallback for an unrecognized / legacy free-text value.
enum Relationship {
  spouse('Spouse'),
  partner('Partner'),
  parent('Parent'),
  child('Child'),
  sibling('Sibling'),
  grandparent('Grandparent'),
  relative('Relative'),
  friend('Friend'),
  guardian('Guardian'),
  caregiver('Caregiver'),
  other('Other');

  const Relationship(this.englishLabel);

  /// Baked English label — the fallback when a locale has no translation.
  final String englishLabel;

  /// Stable stored/wire code (the enum name, e.g. `spouse`). Locale-independent.
  String get wire => name;

  /// Parse a stored/wire code; returns null for null/unknown (e.g. legacy
  /// free-text values), so the caller can keep the original string.
  static Relationship? tryFromCode(String? code) {
    final c = code?.trim().toLowerCase();
    if (c == null || c.isEmpty) return null;
    for (final r in values) {
      if (r.name == c) return r;
    }
    return null;
  }

  /// Like [tryFromCode] but falls back to [other] for any unrecognized value.
  static Relationship fromCode(String? code) => tryFromCode(code) ?? other;
}
