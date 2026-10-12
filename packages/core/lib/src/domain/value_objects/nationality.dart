import 'country_code.dart';
import 'value_object.dart';

/// A person's nationality — distinct from residence country: someone may hold
/// Egyptian [Nationality] while living in Saudi Arabia. Backed by a
/// [CountryCode].
///
/// The localized demonym ("Egyptian" / "مصري") is a translation — resolve it
/// via the `NationalityL10n` extension (`localization/reference_l10n.dart`),
/// not a const field.
class Nationality extends ValueObject {
  const Nationality(this.country);

  factory Nationality.ofCode(String isoCode) => Nationality(CountryCode.fromCode(isoCode));

  final CountryCode country;

  @override
  List<Object?> get props => [country];

  @override
  String toString() => 'Nationality(${country.value})';
}
