import 'bcp47_tag.dart';

class CountryCode {
  const CountryCode._(this.value);

  factory CountryCode(String code) {
    final upper = code.trim().toUpperCase();
    if (upper.length != 2) throw ArgumentError('Invalid country code: $code');
    return CountryCode._(upper);
  }

  final String value;

  static const _deniedDefault = {'CU', 'IR', 'KP', 'SY'};

  bool isDenied({Set<String>? deniedList}) =>
      (deniedList ?? _deniedDefault).contains(value);

  String get defaultTimezone => _timezones[value] ?? 'UTC';

  Bcp47Tag get defaultLocale => _locales[value] ?? Bcp47Tag.en;

  static const _timezones = {
    'EG': 'Africa/Cairo',
    'SA': 'Asia/Riyadh',
    'AE': 'Asia/Dubai',
    'US': 'America/New_York',
    'GB': 'Europe/London',
  };

  static const _locales = {
    'EG': Bcp47Tag.arEG,
    'SA': Bcp47Tag.arSA,
    'AE': Bcp47Tag.arAE,
  };

  @override
  String toString() => value;
  @override
  bool operator ==(Object other) => other is CountryCode && value == other.value;
  @override
  int get hashCode => value.hashCode;
}
