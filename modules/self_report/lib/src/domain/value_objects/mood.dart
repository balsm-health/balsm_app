/// Self-reported overall mood on a 1–5 scale (1 = very low, 5 = great).
/// The label in the current locale resolves from the i69n bundle
/// (`mood.<value>`); this value object holds only the structural score.
class Mood {
  const Mood(this.score) : assert(score >= 1 && score <= 5);

  final int score;

  static const veryLow = Mood(1);
  static const low = Mood(2);
  static const ok = Mood(3);
  static const good = Mood(4);
  static const great = Mood(5);

  /// i69n key fragment (`mood.veryLow` … `mood.great`).
  String get key => switch (score) {
        1 => 'veryLow',
        2 => 'low',
        3 => 'ok',
        4 => 'good',
        _ => 'great',
      };

  @override
  bool operator ==(Object other) => other is Mood && other.score == score;
  @override
  int get hashCode => score.hashCode;
}
