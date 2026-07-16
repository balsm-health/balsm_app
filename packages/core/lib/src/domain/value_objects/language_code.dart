import 'bcp47_tag.dart';
import 'value_object.dart';

/// ISO 639-1 language (the base subtag only — pair with a region via
/// [toTag] to get a [Bcp47Tag] like `ar-EG`).
///
/// [nativeName] (the endonym) and [isRtl] are **facts** — a language's own
/// name and directionality don't change with the app's locale — so they stay
/// const. The language's name *in the current UI locale* is a translation and
/// lives in the core i69n bundle (`language.<code>.name`); resolve it via the
/// `LanguageCodeL10n` extension.
class LanguageCode extends ValueObject {
  const LanguageCode._(this.value, this.nativeName, this.isRtl);

  /// Look up a known language, or accept any well-formed 2-letter code.
  /// Throws [ArgumentError] on malformed input.
  factory LanguageCode(String code) {
    final lower = code.trim().toLowerCase();
    final known = _byCode[lower];
    if (known != null) return known;
    if (lower.length != 2 || !_isAlpha(lower)) {
      throw ArgumentError('Invalid ISO 639-1 language code: $code');
    }
    return LanguageCode._(lower, lower, _rtlByDefault.contains(lower));
  }

  /// The 2-letter ISO 639-1 code, e.g. `ar`.
  final String value;

  /// Endonym — the language's name in itself, e.g. `العربية`. A fixed fact.
  final String nativeName;

  final bool isRtl;

  /// Combine with a region to form a BCP-47 tag (`ar` + `EG` → `ar-EG`).
  Bcp47Tag toTag([String? region]) => Bcp47Tag(
        region == null || region.isEmpty
            ? value
            : '$value-${region.toUpperCase()}',
      );

  static const ar = LanguageCode._('ar', 'العربية', true);
  static const en = LanguageCode._('en', 'English', false);
  static const fr = LanguageCode._('fr', 'Français', false);
  static const ur = LanguageCode._('ur', 'اردو', true);
  static const fa = LanguageCode._('fa', 'فارسی', true);
  static const tr = LanguageCode._('tr', 'Türkçe', false);

  /// Languages the app has UI support for (used by the language picker).
  static const supported = [ar, en, fr, ur, fa, tr];

  static final Map<String, LanguageCode> _byCode = {
    for (final l in supported) l.value: l,
  };

  static const _rtlByDefault = {'ar', 'ur', 'fa', 'he', 'ps', 'sd'};

  static bool _isAlpha(String s) =>
      s.codeUnits.every((u) => u >= 0x61 && u <= 0x7A);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}
