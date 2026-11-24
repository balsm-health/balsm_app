/// Week-by-week pregnancy guidance: general information, the same for every
/// patient, in one language — every text here is in [WeeklyGuidance.language]. Not PHI — it says nothing about
/// anyone's pregnancy — and it changes only when the content does.
library;

/// The baby's typical size in a week; each figure is null where the sources
/// give none.
class GuidanceFetalSize {
  const GuidanceFetalSize({this.lengthMm, this.weightG, this.comparison});

  /// Head to bottom, millimetres.
  final int? lengthMm;
  final int? weightG;

  /// An everyday object of about that size ("a plum").
  final String? comparison;

  bool get isEmpty => lengthMm == null && weightG == null && comparison == null;
}

/// A week's artwork: [key] names the image, [credit] who made it.
class GuidanceIllustration {
  const GuidanceIllustration({
    required this.key,
    required this.credit,
    required this.sourceUrl,
  });

  final String key;

  /// Key of [WeeklyGuidance.illustrationCredits].
  final String credit;

  /// Where the artwork was published.
  final String sourceUrl;
}

/// Who made a set of illustrations, and the line that credits them.
class GuidanceCredit {
  const GuidanceCredit({
    required this.author,
    required this.license,
    required this.text,
  });

  final String author;
  final String license;

  /// "Illustration: …, CC BY-ND 4.0".
  final String text;
}

/// A published source the guidance is drawn from.
class GuidanceSource {
  const GuidanceSource({
    required this.id,
    required this.title,
    required this.publisher,
    required this.url,
  });

  final String id;
  final String title;
  final String publisher;
  final String url;
}

/// A common pregnancy symptom: its name, what helps, and — where the
/// sources name it — when to call the doctor.
class GuidanceSymptom {
  const GuidanceSymptom({required this.label, required this.selfCare, this.callDoctorIf});

  final String label;
  final String selfCare;
  final String? callDoctorIf;
}

/// Guidance for one gestational week. The keys in [testsDue],
/// [dangerSigns] and [sources] point into [WeeklyGuidance]'s tables.
class GuidanceWeek {
  const GuidanceWeek({
    required this.week,
    required this.title,
    required this.summary,
    this.symptoms = const [],
    this.feelings = '',
    this.tips = const [],
    this.babyFact = '',
    this.fetalSize = const GuidanceFetalSize(),
    this.testsDue = const [],
    this.dangerSigns = const [],
    this.topics = const [],
    this.illustration,
    this.sources = const [],
  });

  final int week;
  final String title;

  /// The mother's week in two or three lines.
  final String summary;

  /// Keys of [WeeklyGuidance.symptomGuide] common this week.
  final List<String> symptoms;

  /// How she may feel this week.
  final String feelings;
  final List<String> tips;

  /// How the baby is developing.
  final String babyFact;
  final GuidanceFetalSize fetalSize;
  final List<String> testsDue;
  final List<String> dangerSigns;

  /// Subject tags (`nutrition`, `visits`, …); the app names them itself.
  final List<String> topics;

  /// The week's artwork, or null when it has none.
  final GuidanceIllustration? illustration;
  final List<String> sources;
}

/// The whole guidance set, as last received.
class WeeklyGuidance {
  const WeeklyGuidance({
    required this.language,
    required this.version,
    required this.source,
    required this.disclaimer,
    required this.multiplesNote,
    required this.weeks,
    this.sources = const [],
    this.symptomGuide = const {},
    this.dangerSignLabels = const {},
    this.testLabels = const {},
    this.illustrationCredits = const {},
    this.labels = const {},
    this.topicLabels = const {},
  });

  /// `en` or `ar`: the language every text here is in.
  final String language;

  /// Content version; a new one replaces the copy held on the device.
  final String version;

  /// True for the stand-in copy the server ships until partner content
  /// arrives (versions named `placeholder-…`). Its titles read "Week N
  /// guidance title" and its source "[Partner organization]": never shown.
  bool get isPlaceholder => version.startsWith('placeholder');

  /// Where the content comes from ("Based on WHO and Egypt MOHP guidance"),
  /// shown after [disclaimer].
  final String source;

  /// "General information, not medical advice."
  final String disclaimer;

  /// Shown with the guidance when the pregnancy carries more than one baby:
  /// the content describes a single pregnancy.
  final String multiplesNote;

  /// Ascending by week.
  final List<GuidanceWeek> weeks;

  /// Every source the weeks cite.
  final List<GuidanceSource> sources;

  /// Each [GuidanceWeek.symptoms] key's name, self-care and when to call
  /// the doctor.
  final Map<String, GuidanceSymptom> symptomGuide;

  /// Wording for each [GuidanceWeek.dangerSigns] key.
  final Map<String, String> dangerSignLabels;

  /// Wording for each [GuidanceWeek.testsDue] key.
  final Map<String, String> testLabels;

  /// Credit for each [GuidanceIllustration.credit] key.
  final Map<String, GuidanceCredit> illustrationCredits;

  /// The guide's own wording, keyed by name ("tests_due", "sources_more",
  /// …), with `{n}`-style placeholders; see [label].
  final Map<String, String> labels;

  /// Wording for each [GuidanceWeek.topics] key.
  final Map<String, String> topicLabels;

  /// Label [key] with each `{name}` in it replaced by
  /// [args]' value, or null when the content has no such label.
  String? label(String key, [Map<String, Object> args = const {}]) {
    var text = labels[key];
    if (text == null) return null;
    for (final a in args.entries) {
      text = text!.replaceAll('{${a.key}}', '${a.value}');
    }
    return text;
  }

  /// [week]'s sources, in the order it cites them; ids the document does not
  /// define are left out.
  List<GuidanceSource> sourcesOf(GuidanceWeek week) => [
        for (final id in week.sources)
          for (final s in sources)
            if (s.id == id) s,
      ];

  /// Guidance for [week], or null when the content has none for it (before
  /// week 4, past term).
  GuidanceWeek? forWeek(int week) {
    for (final w in weeks) {
      if (w.week == week) return w;
    }
    return null;
  }
}
