import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/value_objects/language_code.dart';

final countryRegistryProvider = Provider<CountryRegistry>((_) => CountryRegistry());

class CountryMeta {
  const CountryMeta({
    required this.isoCode,
    required this.defaultTimezone,
    required this.firstClassTags,
    required this.supervisoryAuthority,
    this.gregorianOnly = true,
  });
  final String isoCode;
  final String defaultTimezone;
  final List<LanguageCode> firstClassTags;
  final String supervisoryAuthority;
  final bool gregorianOnly;
}

class CountryRegistry {
  static const _data = <String, CountryMeta>{
    'EG': CountryMeta(
      isoCode: 'EG',
      defaultTimezone: 'Africa/Cairo',
      firstClassTags: [LanguageCode.ar, LanguageCode.en],
      supervisoryAuthority: 'Egypt PDPC',
    ),
    'SA': CountryMeta(
      isoCode: 'SA',
      defaultTimezone: 'Asia/Riyadh',
      firstClassTags: [LanguageCode.ar, LanguageCode.en],
      supervisoryAuthority: 'Saudi SDAIA',
    ),
    'AE': CountryMeta(
      isoCode: 'AE',
      defaultTimezone: 'Asia/Dubai',
      firstClassTags: [LanguageCode.ar, LanguageCode.en],
      supervisoryAuthority: 'UAE Data Office',
    ),
  };

  /// The first-class jurisdictions (account countries), in reference order.
  /// Distinct from `CountryCode.known` — that is the wider structural set
  /// (dial codes, travel mode); THIS list gates where an account may reside.
  List<CountryMeta> get all => _data.values.toList(growable: false);

  CountryMeta? lookup(String isoCode) => _data[isoCode.toUpperCase()];

  String supervisoryAuthority(String isoCode) =>
      _data[isoCode.toUpperCase()]?.supervisoryAuthority ?? 'Local Data Protection Authority';
}
