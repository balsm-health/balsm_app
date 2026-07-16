/// A UI locale the app renders in. The app supports Arabic and English only,
/// so [ar] and [en] are the *only* instances that exist — the type is a
/// closed set. Holding an [AppLocale] therefore means "supported"; there is no
/// separate validity flag.
///
/// Untrusted input (a stored/server tag) enters through [tryParse], which
/// returns null for anything unsupported. It matches on the base language
/// subtag, so a legacy regional tag like `ar-EG` resolves to [ar].
class AppLocale {
  const AppLocale._(this.value, this.isRtl=false);

  final String value;
  final bool isRtl;

  static const ar = AppLocale._('ar',true);
  static const en = AppLocale._('en');

  /// Locales the app has UI support for (used by the language picker).
  static const supported = [en, ar];

  /// Resolve an arbitrary BCP-47 tag to a supported locale, or null.
  /// Base-subtag match: `ar`, `AR`, `ar-EG`, `ar_SA` all resolve to [ar].
  static AppLocale? tryParse(String tag) {
    final base = tag.trim().toLowerCase().split(RegExp('[-_]')).first;
    for (final locale in supported) {
      if (locale.value == base) return locale;
    }
    return null;
  }


  @override
  String toString() => value;
  @override
  bool operator ==(Object other) => other is AppLocale && value == other.value;
  @override
  int get hashCode => value.hashCode;
}
