import 'bcp47_tag.dart';
import 'currency_code.dart';
import 'value_object.dart';

/// ISO 3166-1 alpha-2 country — the reference hub for country-derived
/// **structural** i18n facts: [dialCode], [currency], [defaultTimezone],
/// [defaultLocale]. These never change and are needed synchronously in pure
/// logic (e.g. phone validation), so they stay compile-time const.
///
/// Localized names and demonyms are NOT here — they live in the core i69n
/// bundle (`country.<code>.name` / `.demonym`); resolve them via the
/// `CountryCodeL10n` extension (see `localization/reference_l10n.dart`).
///
/// Known countries carry curated metadata; any other well-formed 2-letter
/// code is accepted with neutral defaults so the type never blocks an
/// unlisted country.
class CountryCode extends ValueObject {
  const CountryCode._(this.value, this._meta);

  factory CountryCode(String code) {
    final upper = code.trim().toUpperCase();
    if (upper.length != 2 || !_isAlpha(upper)) {
      throw ArgumentError('Invalid ISO 3166-1 country code: $code');
    }
    return CountryCode._(upper, _data[upper]);
  }

  /// The 2-letter uppercase ISO code, e.g. `EG`.
  final String value;

  final _CountryMeta? _meta;

  static const _deniedDefault = {'CU', 'IR', 'KP', 'SY'};

  bool isDenied({Set<String>? deniedList}) =>
      (deniedList ?? _deniedDefault).contains(value);

  /// International calling code including `+`, e.g. `+20`. Empty when unknown.
  String get dialCode => _meta?.dialCode ?? '';

  /// Official currency; defaults to USD when the country is unlisted.
  CurrencyCode get currency => _meta?.currency ?? CurrencyCode.usd;

  String get defaultTimezone => _meta?.timezone ?? 'UTC';

  Bcp47Tag get defaultLocale => _meta?.locale ?? Bcp47Tag.en;

  /// True for the curated set (has full metadata).
  bool get isKnown => _meta != null;

  static const _data = <String, _CountryMeta>{
    'EG': _CountryMeta('+20', CurrencyCode.egp, 'Africa/Cairo', Bcp47Tag.arEG),
    'SA': _CountryMeta('+966', CurrencyCode.sar, 'Asia/Riyadh', Bcp47Tag.arSA),
    'AE': _CountryMeta('+971', CurrencyCode.aed, 'Asia/Dubai', Bcp47Tag.arAE),
    'QA': _CountryMeta('+974', CurrencyCode.qar, 'Asia/Qatar', Bcp47Tag.arEG),
    'KW': _CountryMeta('+965', CurrencyCode.kwd, 'Asia/Kuwait', Bcp47Tag.arEG),
    'BH': _CountryMeta('+973', CurrencyCode.bhd, 'Asia/Bahrain', Bcp47Tag.arEG),
    'OM': _CountryMeta('+968', CurrencyCode.omr, 'Asia/Muscat', Bcp47Tag.arEG),
    'JO': _CountryMeta('+962', CurrencyCode.jod, 'Asia/Amman', Bcp47Tag.arEG),
    'LB': _CountryMeta('+961', CurrencyCode.usd, 'Asia/Beirut', Bcp47Tag.arEG),
    'MA': _CountryMeta(
        '+212', CurrencyCode.usd, 'Africa/Casablanca', Bcp47Tag.arEG),
    'US': _CountryMeta('+1', CurrencyCode.usd, 'America/New_York', Bcp47Tag.en),
    'GB': _CountryMeta('+44', CurrencyCode.gbp, 'Europe/London', Bcp47Tag.en),
  };

  /// The curated country codes, in reference-table order.
  static List<CountryCode> get known =>
      [for (final code in _data.keys) CountryCode._(code, _data[code])];

  static bool _isAlpha(String s) =>
      s.codeUnits.every((u) => u >= 0x41 && u <= 0x5A);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}

class _CountryMeta {
  const _CountryMeta(this.dialCode, this.currency, this.timezone, this.locale);
  final String dialCode;
  final CurrencyCode currency;
  final String timezone;
  final Bcp47Tag locale;
}
