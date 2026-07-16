import 'bcp47_tag.dart';
import 'currency_code.dart';
import 'value_object.dart';

/// ISO 3166-1 alpha-2 country — the reference hub for country-derived i18n
/// data: [dialCode], [currency], localized names and demonyms, timezone, and
/// default locale.
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

  /// English country name (falls back to the code).
  String get nameEn => _meta?.nameEn ?? value;

  /// Arabic country name (falls back to the English name).
  String get nameAr => _meta?.nameAr ?? nameEn;

  /// English demonym, e.g. `Egyptian` (falls back to the English name).
  String get demonymEn => _meta?.demonymEn ?? nameEn;

  /// Arabic demonym, e.g. `مصري` (falls back to the English demonym).
  String get demonymAr => _meta?.demonymAr ?? demonymEn;

  String get defaultTimezone => _meta?.timezone ?? 'UTC';

  Bcp47Tag get defaultLocale => _meta?.locale ?? Bcp47Tag.en;

  /// True for the curated set (has full metadata).
  bool get isKnown => _meta != null;

  static const _data = <String, _CountryMeta>{
    'EG': _CountryMeta('+20', CurrencyCode.egp, 'Egypt', 'مصر', 'Egyptian',
        'مصري', 'Africa/Cairo', Bcp47Tag.arEG),
    'SA': _CountryMeta('+966', CurrencyCode.sar, 'Saudi Arabia', 'السعودية',
        'Saudi', 'سعودي', 'Asia/Riyadh', Bcp47Tag.arSA),
    'AE': _CountryMeta('+971', CurrencyCode.aed, 'United Arab Emirates',
        'الإمارات', 'Emirati', 'إماراتي', 'Asia/Dubai', Bcp47Tag.arAE),
    'QA': _CountryMeta('+974', CurrencyCode.qar, 'Qatar', 'قطر', 'Qatari',
        'قطري', 'Asia/Qatar', Bcp47Tag.arEG),
    'KW': _CountryMeta('+965', CurrencyCode.kwd, 'Kuwait', 'الكويت', 'Kuwaiti',
        'كويتي', 'Asia/Kuwait', Bcp47Tag.arEG),
    'BH': _CountryMeta('+973', CurrencyCode.bhd, 'Bahrain', 'البحرين',
        'Bahraini', 'بحريني', 'Asia/Bahrain', Bcp47Tag.arEG),
    'OM': _CountryMeta('+968', CurrencyCode.omr, 'Oman', 'عُمان', 'Omani',
        'عُماني', 'Asia/Muscat', Bcp47Tag.arEG),
    'JO': _CountryMeta('+962', CurrencyCode.jod, 'Jordan', 'الأردن',
        'Jordanian', 'أردني', 'Asia/Amman', Bcp47Tag.arEG),
    'LB': _CountryMeta('+961', CurrencyCode.usd, 'Lebanon', 'لبنان',
        'Lebanese', 'لبناني', 'Asia/Beirut', Bcp47Tag.arEG),
    'MA': _CountryMeta('+212', CurrencyCode.usd, 'Morocco', 'المغرب',
        'Moroccan', 'مغربي', 'Africa/Casablanca', Bcp47Tag.arEG),
    'US': _CountryMeta('+1', CurrencyCode.usd, 'United States',
        'الولايات المتحدة', 'American', 'أمريكي', 'America/New_York',
        Bcp47Tag.en),
    'GB': _CountryMeta('+44', CurrencyCode.gbp, 'United Kingdom',
        'المملكة المتحدة', 'British', 'بريطاني', 'Europe/London', Bcp47Tag.en),
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
  const _CountryMeta(
    this.dialCode,
    this.currency,
    this.nameEn,
    this.nameAr,
    this.demonymEn,
    this.demonymAr,
    this.timezone,
    this.locale,
  );
  final String dialCode;
  final CurrencyCode currency;
  final String nameEn;
  final String nameAr;
  final String demonymEn;
  final String demonymAr;
  final String timezone;
  final Bcp47Tag locale;
}
