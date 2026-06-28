import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final translationCatalogProvider = Provider<TranslationCatalog>(
  (_) => TranslationCatalog(),
);

class TranslationCatalog {
  final Map<String, Map<String, String>> _bundles = {};

  Future<void> load(List<String> locales) async {
    for (final locale in locales) {
      try {
        final json = await rootBundle.loadString(
          'packages/core/assets/i18n/$locale.json',
        );
        _bundles[locale] = Map<String, String>.from(jsonDecode(json) as Map);
      } catch (_) {}
    }
  }

  String translate(String key, {String locale = 'en'}) {
    return _bundles[locale]?[key] ??
        _bundles['en']?[key] ??
        key;
  }

  bool hasTranslation(String key, String locale) =>
      _bundles[locale]?.containsKey(key) ?? false;
}
