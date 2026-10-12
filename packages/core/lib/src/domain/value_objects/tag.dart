import 'package:core/core.dart';
import 'package:collection/collection.dart';

class Tag extends ValueObject {
  const Tag(this.key, {this.values = const {}});

  final String key;
  final Map<LanguageCode, String> values;

  String? valueOf(LanguageCode locale, [LanguageCode? fallbackLocale]) =>
      values[locale] ?? values[fallbackLocale ?? LanguageCode.ar] ?? key;

  String? firstWhere(bool Function(LanguageCode locale, String? value) test) =>
      values.entries.firstWhereOrNull((e) => test(e.key, e.value))?.value;

  @override
  List<Object?> get props => [key, values];
}
