/// Week-by-week pregnancy guidance: general information from a partner
/// organisation, the same for every patient. Not PHI — it says nothing about
/// anyone's pregnancy — and it changes only when the content does.

/// One piece of guidance copy in every language the app ships.
class GuidanceText {
  const GuidanceText({required this.en, required this.ar});

  final String en;
  final String ar;

  /// The copy for [languageCode] (`ar`, `en`), English when that language is
  /// missing.
  String inLanguage(String languageCode) => languageCode == 'ar' && ar.isNotEmpty ? ar : en;
}

/// Guidance for one gestational week.
class GuidanceWeek {
  const GuidanceWeek({required this.week, required this.title, required this.body});

  final int week;
  final GuidanceText title;
  final GuidanceText body;
}

/// The whole guidance set, as last received.
class WeeklyGuidance {
  const WeeklyGuidance({
    required this.version,
    required this.source,
    required this.disclaimer,
    required this.multiplesNote,
    required this.weeks,
  });

  /// Content version; a new one replaces the copy held on the device.
  final String version;

  /// Who the content comes from ("Content from …").
  final GuidanceText source;

  /// "General information, not medical advice."
  final GuidanceText disclaimer;

  /// Shown with the guidance when the pregnancy carries more than one baby:
  /// the content describes a single pregnancy.
  final GuidanceText multiplesNote;

  /// Ascending by week.
  final List<GuidanceWeek> weeks;

  /// Guidance for [week], or null when the content has none for it (before
  /// week 4, past term).
  GuidanceWeek? forWeek(int week) {
    for (final w in weeks) {
      if (w.week == week) return w;
    }
    return null;
  }
}
