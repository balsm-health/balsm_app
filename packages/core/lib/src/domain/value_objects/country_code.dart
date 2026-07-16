// ignore_for_file: constant_identifier_names
import 'currency_code.dart';
import 'value_object.dart';

/// ISO 3166-1 alpha-2 country — the reference hub for country-derived
/// **structural** i18n facts: [dialCode], [currency], [defaultTimezone].
/// These never change and are needed synchronously in pure logic (e.g. phone
/// validation), so they stay compile-time const.
///
/// Locale is deliberately NOT here — it is a user preference (any country
/// hosts speakers of many languages), resolved from device locale + user
/// setting, not derived from country.
///
/// Localized names and demonyms are NOT here — they live in the core i69n
/// bundle (`country.<code>.name` / `.demonym`); resolve them via the
/// `CountryCodeL10n` extension (see `localization/reference_l10n.dart`).
///
/// Curated countries are exposed as full-name consts ([egypt], [saudi_arabia],
/// …) and gathered in [known]; the `String` factory resolves via [known] and
/// returns neutral defaults for any other well-formed 2-letter code, so the
/// type never blocks an unlisted country.
class CountryCode extends ValueObject {
  const CountryCode._(this.value, this._meta);

  /// Resolve an arbitrary ISO code (from JSON/API/DB/route params) to a
  /// curated instance, or a bare one with neutral defaults. Throws
  /// [ArgumentError] on malformed input.
  factory CountryCode(String code) {
    final upper = code.trim().toUpperCase();
    if (upper.length != 2 || !_isAlpha(upper)) {
      throw ArgumentError('Invalid ISO 3166-1 country code: $code');
    }
    return _byCode[upper] ?? CountryCode._(upper, null);
  }

  /// The 2-letter uppercase ISO code, e.g. `EG`.
  final String value;

  final _CountryMeta? _meta;

  // Denied/geofenced countries are NOT modelled here — that list is
  // server-driven (geofence_block's DeniedCountriesPort, GET
  // /geofence/denied-countries), never a hardcoded const.

  /// International calling code including `+`, e.g. `+20`. Empty when unknown.
  String get dialCode => _meta?.dialCode ?? '';

  /// Official currency; defaults to USD when the country is unlisted.
  CurrencyCode get currency => _meta?.currency ?? CurrencyCode.usd;

  String get defaultTimezone => _meta?.timezone ?? 'UTC';

  /// True for the curated set (has full metadata).
  bool get isKnown => _meta != null;

  static const egypt = CountryCode._('EG', _CountryMeta('+20', CurrencyCode.egp, 'Africa/Cairo'));
  static const saudi_arabia = CountryCode._('SA', _CountryMeta('+966', CurrencyCode.sar, 'Asia/Riyadh'));
  static const united_arab_emirates = CountryCode._('AE', _CountryMeta('+971', CurrencyCode.aed, 'Asia/Dubai'));
  static const qatar = CountryCode._('QA', _CountryMeta('+974', CurrencyCode.qar, 'Asia/Qatar'));
  static const kuwait = CountryCode._('KW', _CountryMeta('+965', CurrencyCode.kwd, 'Asia/Kuwait'));
  static const bahrain = CountryCode._('BH', _CountryMeta('+973', CurrencyCode.bhd, 'Asia/Bahrain'));
  static const oman = CountryCode._('OM', _CountryMeta('+968', CurrencyCode.omr, 'Asia/Muscat'));
  static const jordan = CountryCode._('JO', _CountryMeta('+962', CurrencyCode.jod, 'Asia/Amman'));
  static const lebanon = CountryCode._('LB', _CountryMeta('+961', CurrencyCode.usd, 'Asia/Beirut'));
  static const morocco = CountryCode._('MA', _CountryMeta('+212', CurrencyCode.usd, 'Africa/Casablanca'));
  static const united_states = CountryCode._('US', _CountryMeta('+1', CurrencyCode.usd, 'America/New_York'));
  static const united_kingdom = CountryCode._('GB', _CountryMeta('+44', CurrencyCode.gbp, 'Europe/London'));

  /// The curated countries, in reference order.
  static const known = [
    egypt, saudi_arabia, united_arab_emirates, qatar, kuwait, bahrain,
    oman, jordan, lebanon, morocco, united_states, united_kingdom,
  ];

  /// Derived string index for the [CountryCode.new] factory.
  static final Map<String, CountryCode> _byCode = {
    for (final c in known) c.value: c,
  };

  static bool _isAlpha(String s) => s.codeUnits.every((u) => u >= 0x41 && u <= 0x5A);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}

class _CountryMeta {
  const _CountryMeta(this.dialCode, this.currency, this.timezone);
  final String dialCode;
  final CurrencyCode currency;
  final String timezone;
}
