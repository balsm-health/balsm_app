import 'value_object.dart';

/// ISO 4217 currency.
///
/// Carries [minorUnitDigits] so amounts are never hard-coded to 2 decimals —
/// KWD/BHD/JOD/OMR use **3**, JPY uses **0**. Use [minorUnitsPerMajor] to
/// convert between major units and the integer minor units [Money] stores.
class CurrencyCode extends ValueObject {
  const CurrencyCode._(
    this.value,
    this.minorUnitDigits,
    this.symbol,
    this.englishName,
  );

  /// Look up a known currency, or accept any well-formed 3-letter code
  /// (defaulting to 2 minor-unit digits). Throws [ArgumentError] on malformed
  /// input.
  factory CurrencyCode(String code) {
    final upper = code.trim().toUpperCase();
    final known = _byCode[upper];
    if (known != null) return known;
    if (upper.length != 3 || !_isAlpha(upper)) {
      throw ArgumentError('Invalid ISO 4217 currency code: $code');
    }
    return CurrencyCode._(upper, 2, upper, upper);
  }

  /// The 3-letter ISO 4217 code, e.g. `EGP`.
  final String value;

  /// Number of decimal digits in the currency's minor unit (2 for most,
  /// 3 for KWD/BHD/JOD, 0 for JPY).
  final int minorUnitDigits;

  /// Display symbol, e.g. `E£`, `SR`, `$`.
  final String symbol;

  final String englishName;

  /// Minor units per one major unit — `10^minorUnitDigits`
  /// (100 for EGP, 1000 for KWD, 1 for JPY).
  int get minorUnitsPerMajor {
    var n = 1;
    for (var i = 0; i < minorUnitDigits; i++) {
      n *= 10;
    }
    return n;
  }

  static const egp = CurrencyCode._('EGP', 2, 'E£', 'Egyptian Pound');
  static const sar = CurrencyCode._('SAR', 2, 'SR', 'Saudi Riyal');
  static const aed = CurrencyCode._('AED', 2, 'AED', 'UAE Dirham');
  static const qar = CurrencyCode._('QAR', 2, 'QR', 'Qatari Riyal');
  static const kwd = CurrencyCode._('KWD', 3, 'KD', 'Kuwaiti Dinar');
  static const bhd = CurrencyCode._('BHD', 3, 'BD', 'Bahraini Dinar');
  static const jod = CurrencyCode._('JOD', 3, 'JD', 'Jordanian Dinar');
  static const omr = CurrencyCode._('OMR', 3, 'ر.ع.', 'Omani Rial');
  static const usd = CurrencyCode._('USD', 2, r'$', 'US Dollar');
  static const eur = CurrencyCode._('EUR', 2, '€', 'Euro');
  static const gbp = CurrencyCode._('GBP', 2, '£', 'Pound Sterling');

  static const _all = [
    egp, sar, aed, qar, kwd, bhd, jod, omr, usd, eur, gbp,
  ];
  static final Map<String, CurrencyCode> _byCode = {
    for (final c in _all) c.value: c,
  };

  static bool _isAlpha(String s) =>
      s.codeUnits.every((u) => u >= 0x41 && u <= 0x5A);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}
