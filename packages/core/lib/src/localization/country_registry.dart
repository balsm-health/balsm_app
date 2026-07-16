import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/value_objects/app_locale.dart';

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
  final List<AppLocale> firstClassTags;
  final String supervisoryAuthority;
  final bool gregorianOnly;
}

class CountryRegistry {
  static const _data = <String, CountryMeta>{
    'EG': CountryMeta(
      isoCode: 'EG',
      defaultTimezone: 'Africa/Cairo',
      firstClassTags: [AppLocale.ar, AppLocale.en],
      supervisoryAuthority: 'Egypt PDPC',
    ),
    'SA': CountryMeta(
      isoCode: 'SA',
      defaultTimezone: 'Asia/Riyadh',
      firstClassTags: [AppLocale.ar, AppLocale.en],
      supervisoryAuthority: 'Saudi SDAIA',
    ),
    'AE': CountryMeta(
      isoCode: 'AE',
      defaultTimezone: 'Asia/Dubai',
      firstClassTags: [AppLocale.ar, AppLocale.en],
      supervisoryAuthority: 'UAE Data Office',
    ),
  };

  CountryMeta? lookup(String isoCode) => _data[isoCode.toUpperCase()];

  String supervisoryAuthority(String isoCode) =>
      _data[isoCode.toUpperCase()]?.supervisoryAuthority ?? 'Local Data Protection Authority';
}
