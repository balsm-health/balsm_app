class Tag extends ValueObject{
  const Tag._(this.value);

  /// Creates a tag from a string. Throws [ArgumentError] if the string is
  /// empty or contains whitespace.
  factory Tag(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tag cannot be empty');
    }
    if (trimmed.contains(RegExp(r'\s'))) {
      throw ArgumentError('Tag cannot contain whitespace: "$value"');
    }
    return Tag._(trimmed);
  }

  final String key;
  final Map<LanguageCode, String> values = {};


  String? valueOf(LanguageCode locale, [LanguageCode? fallbackLocale]) => values[locale] ?? values[fallbackLocale ?? LanguageCode.ar] ?? key;

  String? valueWhere((LanguageCode locale,String? value) => values[locale] != null) => values.entries.firstWhereOrNull((e) => e.value != null)?.value ?? key;
}