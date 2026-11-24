/// Patient-facing reference content from `GET /api/v1/content/*`. General
/// information, identical for every caller — never patient data. Wire format
/// is snake_case.
library;

String _text(Object? json) => json is String ? json : '';

List<String> _keys(Object? json) => json is List
    ? [
        for (final k in json)
          if (k is String) k,
      ]
    : const [];

Map<String, String> _labels(Object? json) => json is Map<String, dynamic>
    ? {
        for (final e in json.entries)
          if (e.value case final String text) e.key: text,
      }
    : const {};

/// A published source the guidance cites.
class ContentSourceDto {
  const ContentSourceDto({
    required this.id,
    required this.title,
    required this.publisher,
    required this.url,
    required this.accessed,
  });

  factory ContentSourceDto.fromJson(Map<String, dynamic> json) => ContentSourceDto(
        id: _text(json['id']),
        title: _text(json['title']),
        publisher: _text(json['publisher']),
        url: _text(json['url']),
        accessed: _text(json['accessed']),
      );

  final String id;
  final String title;
  final String publisher;
  final String url;

  /// Day the source was read, `YYYY-MM-DD`.
  final String accessed;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'publisher': publisher, 'url': url, 'accessed': accessed};
}

/// The baby's typical size in a week. Each figure is null where the sources
/// give none.
class FetalSizeDto {
  const FetalSizeDto({this.lengthMm, this.weightG, this.comparison});

  factory FetalSizeDto.fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    return FetalSizeDto(
      lengthMm: (map['length_mm'] as num?)?.toInt(),
      weightG: (map['weight_g'] as num?)?.toInt(),
      comparison: map['comparison'] as String?,
    );
  }

  final int? lengthMm;
  final int? weightG;

  /// An everyday object of about that size, e.g. "a plum".
  final String? comparison;

  Map<String, dynamic> toJson() => {'length_mm': lengthMm, 'weight_g': weightG, 'comparison': comparison};
}

/// A week's artwork: [key] names the image, [credit] who made it.
class IllustrationDto {
  const IllustrationDto({required this.key, required this.credit, required this.sourceUrl});

  /// Null when [json] is not an artwork object.
  static IllustrationDto? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final key = json['key'];
    if (key is! String || key.isEmpty) return null;
    return IllustrationDto(key: key, credit: _text(json['credit']), sourceUrl: _text(json['source_url']));
  }

  /// e.g. `pregnancy/week-12`.
  final String key;

  /// Key of [PregnancyWeeksResponse.illustrationCredits].
  final String credit;

  /// Where the artwork was published.
  final String sourceUrl;

  Map<String, dynamic> toJson() => {'key': key, 'credit': credit, 'source_url': sourceUrl};
}

/// Who made a set of illustrations, and under which licence they are shown.
class IllustrationCreditDto {
  const IllustrationCreditDto({
    required this.author,
    required this.license,
    required this.licenseUrl,
    required this.authorUrl,
    required this.text,
  });

  factory IllustrationCreditDto.fromJson(Map<String, dynamic> json) => IllustrationCreditDto(
        author: _text(json['author']),
        license: _text(json['license']),
        licenseUrl: _text(json['license_url']),
        authorUrl: _text(json['author_url']),
        text: _text(json['text']),
      );

  final String author;
  final String license;
  final String licenseUrl;
  final String authorUrl;

  /// Credit line shown under the artwork.
  final String text;

  Map<String, dynamic> toJson() => {
        'author': author,
        'license': license,
        'license_url': licenseUrl,
        'author_url': authorUrl,
        'text': text,
      };
}

/// Guidance for one week of pregnancy, in the document's language.
class PregnancyWeekDto {
  const PregnancyWeekDto({
    required this.week,
    required this.title,
    required this.body,
    this.fetalSize = const FetalSizeDto(),
    this.testsDue = const [],
    this.dangerSigns = const [],
    this.topics = const [],
    this.illustration,
    this.sources = const [],
  });

  factory PregnancyWeekDto.fromJson(Map<String, dynamic> json) => PregnancyWeekDto(
        week: (json['week'] as num).toInt(),
        title: _text(json['title']),
        body: _text(json['body']),
        fetalSize: FetalSizeDto.fromJson(json['fetal_size']),
        testsDue: _keys(json['tests_due']),
        dangerSigns: _keys(json['danger_signs']),
        topics: _keys(json['topics']),
        illustration: IllustrationDto.fromJson(json['illustration']),
        sources: _keys(json['sources']),
      );

  final int week;
  final String title;
  final String body;
  final FetalSizeDto fetalSize;

  /// Keys of [PregnancyWeeksResponse.testLabels] usually due this week.
  final List<String> testsDue;

  /// Keys of [PregnancyWeeksResponse.dangerSignLabels] the body warns about.
  final List<String> dangerSigns;

  /// Keys of [PregnancyWeeksResponse.topicLabels].
  final List<String> topics;

  /// The week's artwork, or null when it has none.
  final IllustrationDto? illustration;

  /// Ids of [PregnancyWeeksResponse.sources] behind this week's copy.
  final List<String> sources;

  Map<String, dynamic> toJson() => {
        'week': week,
        'title': title,
        'body': body,
        'fetal_size': fetalSize.toJson(),
        'tests_due': testsDue,
        'danger_signs': dangerSigns,
        'topics': topics,
        'illustration': illustration?.toJson(),
        'sources': sources,
      };
}

/// `GET /api/v1/content/pregnancy-weeks?lang=` — week-by-week pregnancy
/// guidance, every text in one language ([language]).
///
/// [toJson] round-trips [PregnancyWeeksResponse.fromJson] so a caller can keep
/// the last good copy on the device.
class PregnancyWeeksResponse {
  const PregnancyWeeksResponse({
    required this.language,
    required this.version,
    required this.source,
    required this.disclaimer,
    required this.multiplesNote,
    required this.weeks,
    this.labels = const {},
    this.sources = const [],
    this.dangerSignLabels = const {},
    this.testLabels = const {},
    this.topicLabels = const {},
    this.illustrationCredits = const {},
  });

  /// Throws [FormatException] when there is no version or no weeks — content
  /// that cannot be shown at all. A week without a number is skipped.
  factory PregnancyWeeksResponse.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final raw = json['weeks'];
    if (version is! String || version.isEmpty || raw is! List) {
      throw const FormatException('pregnancy-weeks: missing version or weeks');
    }
    final weeks = [
      for (final w in raw)
        if (w is Map<String, dynamic> && w['week'] is num) PregnancyWeekDto.fromJson(w),
    ];
    if (weeks.isEmpty) throw const FormatException('pregnancy-weeks: no weeks');
    return PregnancyWeeksResponse(
      language: _text(json['language']),
      version: version,
      source: _text(json['source']),
      disclaimer: _text(json['disclaimer']),
      multiplesNote: _text(json['multiples_note']),
      weeks: weeks,
      labels: _labels(json['labels']),
      sources: [
        for (final x in json['sources'] is List ? json['sources'] as List : const [])
          if (x is Map<String, dynamic>) ContentSourceDto.fromJson(x),
      ],
      dangerSignLabels: _labels(json['danger_sign_labels']),
      testLabels: _labels(json['test_labels']),
      topicLabels: _labels(json['topic_labels']),
      illustrationCredits: {
        if (json['illustration_credits'] case final Map<String, dynamic> credits)
          for (final e in credits.entries)
            if (e.value case final Map<String, dynamic> credit) e.key: IllustrationCreditDto.fromJson(credit),
      },
    );
  }

  /// `en` or `ar`: the language every text here is in.
  final String language;
  final String version;

  /// Where the content comes from, shown after [disclaimer].
  final String source;
  final String disclaimer;
  final String multiplesNote;
  final List<PregnancyWeekDto> weeks;

  /// The guide's own wording (section headings, size phrases, units, the
  /// sources link) keyed by name, with `{n}`-style placeholders.
  final Map<String, String> labels;

  /// Every source the weeks cite.
  final List<ContentSourceDto> sources;

  /// Wording for each [PregnancyWeekDto.dangerSigns] key.
  final Map<String, String> dangerSignLabels;

  /// Wording for each [PregnancyWeekDto.testsDue] key.
  final Map<String, String> testLabels;

  /// Wording for each [PregnancyWeekDto.topics] key.
  final Map<String, String> topicLabels;

  /// Credit for each [IllustrationDto.credit] key.
  final Map<String, IllustrationCreditDto> illustrationCredits;

  Map<String, dynamic> toJson() => {
        'language': language,
        'version': version,
        'source': source,
        'disclaimer': disclaimer,
        'multiples_note': multiplesNote,
        'weeks': [for (final w in weeks) w.toJson()],
        'labels': labels,
        'sources': [for (final x in sources) x.toJson()],
        'danger_sign_labels': dangerSignLabels,
        'test_labels': testLabels,
        'topic_labels': topicLabels,
        'illustration_credits': {for (final e in illustrationCredits.entries) e.key: e.value.toJson()},
      };
}

/// The answer to a conditional GET sent with the caller's last ETag.
sealed class Revalidated<T> {
  const Revalidated();
}

/// The server sent a new body; keep [etag] for the next request.
final class Modified<T> extends Revalidated<T> {
  const Modified(this.value, {this.etag});
  final T value;
  final String? etag;
}

/// `304` — the caller's copy is current.
final class NotModified<T> extends Revalidated<T> {
  const NotModified();
}
