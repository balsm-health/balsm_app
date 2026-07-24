/// Self-reported pain intensity on the standard 0–10 numeric rating scale
/// (0 = none, 10 = worst imaginable).
class PainLevel {
  const PainLevel(this.value) : assert(value >= 0 && value <= 10);

  final int value;

  static const none = PainLevel(0);

  bool get isNone => value == 0;

  @override
  bool operator ==(Object other) => other is PainLevel && other.value == value;
  @override
  int get hashCode => value.hashCode;
}
