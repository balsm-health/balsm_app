import 'value_object.dart';

/// ISO 639-1 language (the base subtag only — pair with a region via
/// [toTag] to get a BCP-47 tag string like `ar-EG`).
///
/// [nativeName] (the endonym) and [isRtl] are **facts** — a language's own
/// name and directionality don't change with the app's locale — so they stay
/// const. The language's name *in the current UI locale* is a translation and
/// lives in the core i69n bundle (`language.<code>.name`); resolve it via the
/// `LanguageCodeL10n` extension.
class LanguageCode extends ValueObject {
  const LanguageCode._(this.value, this.nativeName, this.isRtl, {this.isFullySupported = false});

  /// Look up a known language, or accept any well-formed 2-letter code.
  /// Throws [ArgumentError] on malformed input.
  factory LanguageCode.fromCode(String code) {
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

  /// True when the app ships a complete UI translation for this language;
  /// the rest of [supported] appears in the picker as "beta" and can't be
  /// selected yet.
  final bool isFullySupported;

  /// Combine with a region to form a BCP-47 tag string (`ar` + `EG` → `ar-EG`).
  String toTag([String? region]) => region == null || region.isEmpty ? value : '$value-${region.toUpperCase()}';

  static const ar = LanguageCode._('ar', 'العربية', true, isFullySupported: true);
  static const en = LanguageCode._('en', 'English', false, isFullySupported: true);
  static const fr = LanguageCode._('fr', 'Français', false);
  static const ur = LanguageCode._('ur', 'اردو', true);
  static const fa = LanguageCode._('fa', 'فارسی', true);
  static const tr = LanguageCode._('tr', 'Türkçe', false);

  /// Languages the app has UI support for (used by the language picker).
  static const supported = [ar, en, fr, ur, fa, tr];

  /// The fully-supported UI locales — the closed set the app renders in
  /// (absorbs the former `AppLocale` type). Holding one of these means the
  /// app can fully render in it; the rest of [supported] are picker-visible
  /// betas.
  static const uiSupported = [en, ar];

  /// Resolve an arbitrary BCP-47 tag to a fully-supported UI language, or
  /// null for anything unsupported. Base-subtag match: `ar`, `AR`, `ar-EG`,
  /// `ar_SA` all resolve to [ar].
  static LanguageCode? tryParseUi(String tag) {
    final base = tag.trim().toLowerCase().split(RegExp('[-_]')).first;
    for (final language in uiSupported) {
      if (language.value == base) return language;
    }
    return null;
  }

  static final Map<String, LanguageCode> _byCode = {
    for (final l in supported) l.value: l,
  };

  static const _rtlByDefault = {'ar', 'ur', 'fa', 'he', 'ps', 'sd'};

  static bool _isAlpha(String s) => s.codeUnits.every((u) => u >= 0x61 && u <= 0x7A);

  @override
  List<Object?> get props => [value];

  @override
  String toString() => value;
}
