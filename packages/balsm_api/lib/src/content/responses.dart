/// Patient-facing reference content from `GET /api/v1/content/*`. General
/// information, identical for every caller — never patient data. Wire format
/// is snake_case.
library;

/// One piece of copy in every language the app ships. A language the server
/// leaves out arrives as `''` so the caller can fall back.
class LocalizedTextDto {
  const LocalizedTextDto({required this.en, required this.ar});

  final String en;
  final String ar;

  factory LocalizedTextDto.fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    return LocalizedTextDto(en: map['en'] as String? ?? '', ar: map['ar'] as String? ?? '');
  }

  Map<String, dynamic> toJson() => {'en': en, 'ar': ar};
}

/// Guidance for one week of pregnancy.
class PregnancyWeekDto {
  const PregnancyWeekDto({required this.week, required this.title, required this.body});

  final int week;
  final LocalizedTextDto title;
  final LocalizedTextDto body;

  factory PregnancyWeekDto.fromJson(Map<String, dynamic> json) => PregnancyWeekDto(
        week: (json['week'] as num).toInt(),
        title: LocalizedTextDto.fromJson(json['title']),
        body: LocalizedTextDto.fromJson(json['body']),
      );

  Map<String, dynamic> toJson() => {'week': week, 'title': title.toJson(), 'body': body.toJson()};
}

/// `GET /api/v1/content/pregnancy-weeks` — week-by-week pregnancy guidance.
///
/// [toJson] round-trips [PregnancyWeeksResponse.fromJson] so a caller can keep
/// the last good copy on the device.
class PregnancyWeeksResponse {
  const PregnancyWeeksResponse({
    required this.version,
    required this.source,
    required this.disclaimer,
    required this.multiplesNote,
    required this.weeks,
  });

  final String version;
  final LocalizedTextDto source;
  final LocalizedTextDto disclaimer;
  final LocalizedTextDto multiplesNote;
  final List<PregnancyWeekDto> weeks;

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
      version: version,
      source: LocalizedTextDto.fromJson(json['source']),
      disclaimer: LocalizedTextDto.fromJson(json['disclaimer']),
      multiplesNote: LocalizedTextDto.fromJson(json['multiples_note']),
      weeks: weeks,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'source': source.toJson(),
        'disclaimer': disclaimer.toJson(),
        'multiples_note': multiplesNote.toJson(),
        'weeks': [for (final w in weeks) w.toJson()],
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
