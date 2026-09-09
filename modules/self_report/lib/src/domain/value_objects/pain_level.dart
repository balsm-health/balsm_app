/// Self-reported pain intensity on the standard 0–10 numeric rating scale
/// (0 = none, 10 = worst imaginable).
class PainLevel {
  const PainLevel(this.value) : assert(value >= 0 && value <= 10);

  final int value;

  static const none = PainLevel(0);

  bool get isNone => value == 0;

  /// Clinical band for this score.
  ///
  /// The cut-offs are the conventional NRS-11 groupings, and they were living
  /// in a check-in widget's `painInfo` helper. They decide what a check-in
  /// summary, a trend and a clinician-facing report each call the same score,
  /// so they belong to the scale, not to one screen. Which colour a band gets
  /// stays with the screen.
  PainBand get band {
    if (value == 0) return PainBand.none;
    if (value <= 3) return PainBand.mild;
    if (value <= 6) return PainBand.moderate;
    if (value <= 9) return PainBand.severe;
    return PainBand.worst;
  }

  @override
  bool operator ==(Object other) => other is PainLevel && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// Conventional NRS-11 severity groupings for a [PainLevel].
enum PainBand { none, mild, moderate, severe, worst }
