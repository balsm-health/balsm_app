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

  /// Joins items of a run-in list: the Arabic comma in RTL languages, `, ` otherwise.
  String get listSeparator => isRtl ? '، ' : ', ';

  /// True when the app ships a complete UI translation for this language.
  /// Every language in [supported] does today; a language added before its
  /// translation is finished would be false and show in the picker as "beta",
  /// unselectable.
  final bool isFullySupported;

  /// Combine with a region to form a BCP-47 tag string (`ar` + `EG` → `ar-EG`).
  String toTag([String? region]) => region == null || region.isEmpty ? value : '$value-${region.toUpperCase()}';

  static const ar = LanguageCode._('ar', 'العربية', true, isFullySupported: true);
  static const en = LanguageCode._('en', 'English', false, isFullySupported: true);

  /// The languages the app offers: Arabic and English, nothing else. This is
  /// what the language picker lists. The store builds are trimmed to the same
  /// two (Android `localeFilters`, the iOS "Strip unsupported languages" build
  /// phase), so adding one here means adding it there as well.
  static const List<LanguageCode> supported = [ar, en];

  /// The fully-supported UI locales — the closed set the app renders in
  /// (absorbs the former `AppLocale` type). Holding one of these means the
  /// app can fully render in it.
  static const List<LanguageCode> uiSupported = [en, ar];

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

  /// What the app shows when neither a saved choice nor the device offers a
  /// language it can render. Arabic: the app's patients read it first, so an
  /// unknown language should land on it rather than on English.
  static const LanguageCode defaultUi = ar;

  /// Picks the UI language at launch.
  ///
  /// 1. A saved choice wins, when it is one the app can render.
  /// 2. Otherwise the first of [deviceTags] it can render. These are the
  ///    device's languages, most preferred first, as BCP-47 tags (`ar-EG`).
  /// 3. Otherwise [defaultUi].
  ///
  /// The one place the language fallback lives: callers must not add their own.
  static LanguageCode resolveUi({String? saved, Iterable<String> deviceTags = const []}) {
    if (saved != null) {
      final choice = tryParseUi(saved);
      if (choice != null) return choice;
    }
    for (final tag in deviceTags) {
      final device = tryParseUi(tag);
      if (device != null) return device;
    }
    return defaultUi;
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
