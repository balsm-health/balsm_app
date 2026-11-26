/// Lifecycle of a pregnancy, persisted as [wire] in `pregnancy.status`.
/// [birth] and [ended] are both closed; [birth] means at least one baby was
/// born.
enum PregnancyStatus {
  active,
  birth,
  ended;

  /// Stable stored code (the enum name).
  String get wire => name;

  /// Parses a stored code; unknown or null reads as [ended] — a row the app
  /// cannot read is never taken for a pregnancy still in progress.
  static PregnancyStatus fromWire(String? code) {
    for (final s in values) {
      if (s.name == code) return s;
    }
    return ended;
  }
}

/// Whom a pregnancy item is about, persisted as [wire] in
/// `pregnancy_item.about`.
enum ItemAbout {
  /// The mother's own results ("Me").
  me,

  /// One or more babies (`pregnancy_item_baby`).
  baby;

  String get wire => name;

  static ItemAbout fromWire(String? code) => code == baby.name ? baby : me;
}

/// What a pregnancy item is, persisted as [wire] in `pregnancy_item.kind`.
enum ItemKind {
  /// A scan or report (file).
  scan,

  /// Measurements of one baby, entered exactly as written in the report.
  measure,

  /// A test or other document (file).
  doc;

  String get wire => name;

  static ItemKind fromWire(String? code) {
    for (final k in values) {
      if (k.name == code) return k;
    }
    return doc;
  }
}

/// Where a baby of a pregnancy stands, read from its profile: still
/// [active] (prenatal), [born] (now a dependent), or [closed] (no longer
/// followed — kept, never shown again).
enum BabyStatus { active, born, closed }
