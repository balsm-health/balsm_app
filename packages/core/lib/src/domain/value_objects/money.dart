import 'currency_code.dart';
import 'value_object.dart';

/// A monetary amount as integer [minorUnits] of a [currency] — never a float,
/// so arithmetic stays exact. The number of minor units per major unit comes
/// from [CurrencyCode.minorUnitsPerMajor] (100 for EGP, **1000 for KWD/BHD/
/// JOD**, 1 for JPY), so 3-decimal Gulf dinars are handled correctly.
class Money extends ValueObject {
  const Money({required this.currency, required this.minorUnits});

  /// Build from a major-unit amount (e.g. `Money.fromMajor(12.5, CurrencyCode.egp)`
  /// → 1250 piastres). Rounds to the currency's minor-unit precision.
  factory Money.fromMajor(num amount, CurrencyCode currency) => Money(
        currency: currency,
        minorUnits: (amount * currency.minorUnitsPerMajor).round(),
      );

  final CurrencyCode currency;
  final int minorUnits;

  /// The amount in major units (e.g. `12.50`).
  double get amount => minorUnits / currency.minorUnitsPerMajor;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(currency: currency, minorUnits: minorUnits + other.minorUnits);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(currency: currency, minorUnits: minorUnits - other.minorUnits);
  }

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('currency mismatch: ${currency.value} vs ${other.currency.value}');
    }
  }

  /// `EGP 12.50` — symbol/format is a presentation concern; this is a debug
  /// form.
  @override
  String toString() => '${currency.value} ${amount.toStringAsFixed(currency.minorUnitDigits)}';

  @override
  List<Object?> get props => [currency, minorUnits];
}
