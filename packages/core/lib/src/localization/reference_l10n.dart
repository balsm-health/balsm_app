import '../domain/value_objects/country_code.dart';
import '../domain/value_objects/language_code.dart';
import '../domain/value_objects/nationality.dart';
import 'translation_catalog.dart';

/// Resolves the localized display strings for country/language/nationality
/// value objects from the core i69n bundle (`country.<code>.name|demonym`,
/// `language.<code>.name`).
///
/// The value objects stay pure (structural facts only); presentation calls
/// these with a [TranslationCatalog] + locale. On a missing translation the
/// helpers fall back to the raw code (never a bare i69n key).
extension CountryCodeL10n on CountryCode {
  /// Localized country name, e.g. `Egypt` / `مصر`.
  String name(TranslationCatalog catalog, {String locale = 'en'}) =>
      _resolve(catalog, 'country.${value.toLowerCase()}.name', locale, value);

  /// Localized demonym, e.g. `Egyptian` / `مصري`.
  String demonym(TranslationCatalog catalog, {String locale = 'en'}) =>
      _resolve(
          catalog, 'country.${value.toLowerCase()}.demonym', locale, value);
}

extension LanguageCodeL10n on LanguageCode {
  /// The language's name in the given [locale] (distinct from [nativeName],
  /// which is the endonym). E.g. `LanguageCode.ar.name(...)` → `Arabic` / `العربية`.
  String name(TranslationCatalog catalog, {String locale = 'en'}) =>
      _resolve(
          catalog, 'language.${value.toLowerCase()}.name', locale, nativeName);
}

extension NationalityL10n on Nationality {
  /// Localized demonym, e.g. `Egyptian` / `مصري`.
  String demonym(TranslationCatalog catalog, {String locale = 'en'}) =>
      country.demonym(catalog, locale: locale);
}

String _resolve(
    TranslationCatalog catalog, String key, String locale, String fallback) {
  final value = catalog.translate(key, locale: locale);
  // translate() returns the key itself on a miss — fall back to the code.
  return value == key ? fallback : value;
}
