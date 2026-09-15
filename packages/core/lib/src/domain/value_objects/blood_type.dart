/// ABO/Rh blood group plus the rare Bombay phenotype (Oh).
///
/// [code] is the stable wire/storage string (drift column, QR payload JSON) —
/// existing rows carry exactly these values. An unknown blood type is a null
/// `BloodType?`, never an enum member: absence of knowledge is not a group.
///
/// Bombay matters clinically: routine typing reads it as O, but Bombay
/// patients can only receive Bombay blood — an emergency card must be able
/// to say it (never force the dangerous "O" approximation).
enum BloodType {
  aPositive('A+'),
  aNegative('A-'),
  bPositive('B+'),
  bNegative('B-'),
  abPositive('AB+'),
  abNegative('AB-'),
  oPositive('O+'),
  oNegative('O-'),
  bombay('Oh');

  const BloodType(this.code);

  /// Stable storage/wire value.
  final String code;

  /// Display label — the code, with Bombay spelled out.
  String get label => this == BloodType.bombay ? 'Oh (Bombay)' : code;

  /// Null for null/unrecognized input (legacy free-text rows degrade to
  /// "unknown" rather than crashing a profile load).
  static BloodType? tryParse(String? code) {
    if (code == null) return null;
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }
}
