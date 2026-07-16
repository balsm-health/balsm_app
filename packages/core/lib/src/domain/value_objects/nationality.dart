import 'country_code.dart';
import 'value_object.dart';

/// A person's nationality — distinct from residence country: someone may hold
/// Egyptian [Nationality] while living in Saudi Arabia. Backed by a
/// [CountryCode] so it reuses the same curated demonym/name data.
class Nationality extends ValueObject {
  const Nationality(this.country);

  factory Nationality.ofCode(String isoCode) =>
      Nationality(CountryCode(isoCode));

  final CountryCode country;

  /// English demonym, e.g. `Egyptian`.
  String get demonymEn => country.demonymEn;

  /// Arabic demonym, e.g. `مصري`.
  String get demonymAr => country.demonymAr;

  @override
  List<Object?> get props => [country];

  @override
  String toString() => demonymEn;
}
