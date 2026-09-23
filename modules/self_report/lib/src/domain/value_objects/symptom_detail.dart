/// Observable detail the patient can add to a reported symptom.
///
/// Ported from `quicklog.jsx` `QuickSymptomDetail`, which asks for colour,
/// quantity and blood on urine and for blood on stool. Everything here is the
/// patient's own observation, recorded verbatim — self-report is a journal,
/// NOT a symptom checker, so nothing is interpreted, scored, or flagged.
/// PHI: on-device only.
class SymptomDetail {
  const SymptomDetail({this.urineColor, this.urineMl, this.blood = false});

  /// One of [UrineColor], or null when not reported.
  final UrineColor? urineColor;

  /// Volume passed, in millilitres. Null when not reported; the design's
  /// stepper moves in 50ml steps but any value the patient types is kept.
  final int? urineMl;

  /// The patient saw blood. A plain observation, carrying no severity.
  final bool blood;

  /// True when nothing was actually reported — such a detail is not persisted.
  bool get isEmpty => urineColor == null && urineMl == null && !blood;

  SymptomDetail copyWith({
    UrineColor? urineColor,
    bool clearUrineColor = false,
    int? urineMl,
    bool clearUrineMl = false,
    bool? blood,
  }) =>
      SymptomDetail(
        urineColor: clearUrineColor ? null : (urineColor ?? this.urineColor),
        urineMl: clearUrineMl ? null : (urineMl ?? this.urineMl),
        blood: blood ?? this.blood,
      );

  @override
  bool operator ==(Object other) =>
      other is SymptomDetail && other.urineColor == urineColor && other.urineMl == urineMl && other.blood == blood;

  @override
  int get hashCode => Object.hash(urineColor, urineMl, blood);
}

/// The urine colours the design offers, with the swatch it paints for each.
///
/// A closed, patient-facing vocabulary — descriptive words, not a clinical
/// chart, and deliberately not mapped to any hydration or diagnosis scale.
enum UrineColor {
  pale('pale', 0xFFF5F0C8),
  yellow('yellow', 0xFFE8D24A),
  dark('dark', 0xFF8A6A1E),
  red('red', 0xFFC4453C),
  brown('brown', 0xFF5C4029);

  const UrineColor(this.id, this.swatch);

  /// Stable storage key.
  final String id;

  /// ARGB of the swatch the picker paints (`URINE_COLORS[].swatch`).
  final int swatch;

  /// The two light swatches need dark ink for the selected check mark.
  bool get isLightSwatch => this == pale || this == yellow;

  static UrineColor? fromId(String? id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return null;
  }
}
