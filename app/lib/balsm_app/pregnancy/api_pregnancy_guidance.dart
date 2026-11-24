import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pregnancy/pregnancy.dart';

/// Binds the pregnancy module's [PregnancyGuidanceSource] to
/// `GET /api/v1/content/pregnancy-weeks`, keeping the last good copy and its
/// ETag in the app-wide key-value store so guidance shows offline once it has
/// been fetched, and a revalidation that finds nothing new costs a body-less
/// 304.
///
/// Not PHI: the content is general and identical for every patient, and the
/// request carries nothing about the patient beyond the session token every
/// call has. A device-only account has no session, so the request never
/// leaves the phone (the auth interceptor treats it as offline) and the card
/// stays hidden until the account goes online.
class ApiPregnancyGuidance implements PregnancyGuidanceSource {
  ApiPregnancyGuidance({required ContentApi api, required GlobalKVDataSource kv})
      : _api = api,
        _kv = kv;

  /// Bump the suffix when the stored shape changes; an older copy is then
  /// ignored and fetched again.
  static const storageKey = 'content.pregnancy_weeks.v1';

  final ContentApi _api;
  final GlobalKVDataSource _kv;

  @override
  Future<WeeklyGuidance?> cached() async => (await _read())?.$2;

  @override
  Future<WeeklyGuidance?> refresh() async {
    final kept = await _read();
    try {
      switch (await _api.pregnancyWeeks(etag: kept?.$1)) {
        case NotModified():
          return kept?.$2;
        case Modified(:final value, :final etag):
          await _kv.put<Map<String, dynamic>>(storageKey, {'etag': etag, 'data': value.toJson()});
          return _toDomain(value);
      }
    } on ApiException {
      return kept?.$2;
    } on FormatException {
      return kept?.$2;
    }
  }

  /// The stored ETag and copy, or null when there is none or it can't be read
  /// (an unreadable copy is as good as none — the next fetch replaces it).
  Future<(String?, WeeklyGuidance)?> _read() async {
    try {
      final stored = await _kv.get<Map<String, dynamic>>(storageKey);
      final data = stored?['data'];
      if (data is! Map<String, dynamic>) return null;
      return (stored!['etag'] as String?, _toDomain(PregnancyWeeksResponse.fromJson(data)));
    } on Object {
      return null;
    }
  }

  static GuidanceText _text(LocalizedTextDto t) => GuidanceText(en: t.en, ar: t.ar);

  static WeeklyGuidance _toDomain(PregnancyWeeksResponse r) => WeeklyGuidance(
        version: r.version,
        source: _text(r.source),
        disclaimer: _text(r.disclaimer),
        multiplesNote: _text(r.multiplesNote),
        weeks: [for (final w in r.weeks) _week(w)]..sort((a, b) => a.week.compareTo(b.week)),
        sources: [
          for (final x in r.sources) GuidanceSource(id: x.id, title: x.title, publisher: x.publisher, url: x.url),
        ],
        dangerSignLabels: {for (final e in r.dangerSignLabels.entries) e.key: _text(e.value)},
        testLabels: {for (final e in r.testLabels.entries) e.key: _text(e.value)},
        labels: {for (final e in r.labels.entries) e.key: _text(e.value)},
        topicLabels: {for (final e in r.topicLabels.entries) e.key: _text(e.value)},
        illustrationCredits: {
          for (final e in r.illustrationCredits.entries)
            e.key: GuidanceCredit(author: e.value.author, license: e.value.license, text: _text(e.value.text)),
        },
      );

  static GuidanceWeek _week(PregnancyWeekDto w) {
    final size = w.fetalSize;
    final art = w.illustration;
    return GuidanceWeek(
      week: w.week,
      title: _text(w.title),
      body: _text(w.body),
      fetalSize: GuidanceFetalSize(
        lengthMm: size.lengthMm,
        weightG: size.weightG,
        comparison: size.comparison == null ? null : _text(size.comparison!),
      ),
      testsDue: w.testsDue,
      dangerSigns: w.dangerSigns,
      topics: w.topics,
      illustration:
          art == null ? null : GuidanceIllustration(key: art.key, credit: art.credit, sourceUrl: art.sourceUrl),
      sources: w.sources,
    );
  }
}

/// The composition-root binding: `pregnancyGuidanceSourceProvider.overrideWith(apiPregnancyGuidanceSource)`.
PregnancyGuidanceSource apiPregnancyGuidanceSource(Ref ref) => ApiPregnancyGuidance(
      api: ref.watch(contentApiProvider),
      kv: ref.watch(globalKVDataSourceProvider),
    );
