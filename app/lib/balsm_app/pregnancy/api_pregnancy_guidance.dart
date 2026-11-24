import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pregnancy/pregnancy.dart';

import '../app_state.dart';

/// Binds the pregnancy module's [PregnancyGuidanceSource] to
/// `GET /api/v1/content/pregnancy-weeks?lang=`, in the app's [language]: the
/// server sends that language only. The last good copy of each language and
/// its ETag stay in the app-wide key-value store, so guidance shows offline
/// once it has been fetched, switching language back needs no download, and
/// a revalidation that finds nothing new costs a body-less 304.
///
/// Not PHI: the content is general and identical for every patient, and the
/// request carries nothing about the patient beyond the session token every
/// call has. A device-only account has no session, so the request never
/// leaves the phone (the auth interceptor treats it as offline) and the card
/// stays hidden until the account goes online.
class ApiPregnancyGuidance implements PregnancyGuidanceSource {
  ApiPregnancyGuidance({required ContentApi api, required GlobalKVDataSource kv, required this.language})
      : _api = api,
        _kv = kv;

  /// Where [lang]'s copy is kept. Bump the version when the stored shape
  /// changes; an older copy is then ignored and fetched again.
  static String storageKey(String lang) => 'content.pregnancy_weeks.v3.$lang';

  final ContentApi _api;
  final GlobalKVDataSource _kv;

  /// `en` or `ar`: the language asked for and kept.
  final String language;

  @override
  Future<WeeklyGuidance?> cached() async => (await _read())?.$2;

  @override
  Future<WeeklyGuidance?> refresh() async {
    final kept = await _read();
    try {
      switch (await _api.pregnancyWeeks(lang: language, etag: kept?.$1)) {
        case NotModified():
          return kept?.$2;
        case Modified(:final value, :final etag):
          await _kv.put<Map<String, dynamic>>(storageKey(language), {'etag': etag, 'data': value.toJson()});
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
      final stored = await _kv.get<Map<String, dynamic>>(storageKey(language));
      final data = stored?['data'];
      if (data is! Map<String, dynamic>) return null;
      return (stored!['etag'] as String?, _toDomain(PregnancyWeeksResponse.fromJson(data)));
    } on Object {
      return null;
    }
  }

  static WeeklyGuidance _toDomain(PregnancyWeeksResponse r) => WeeklyGuidance(
        language: r.language,
        version: r.version,
        source: r.source,
        disclaimer: r.disclaimer,
        multiplesNote: r.multiplesNote,
        weeks: [for (final w in r.weeks) _week(w)]..sort((a, b) => a.week.compareTo(b.week)),
        labels: r.labels,
        sources: [
          for (final x in r.sources) GuidanceSource(id: x.id, title: x.title, publisher: x.publisher, url: x.url),
        ],
        dangerSignLabels: r.dangerSignLabels,
        testLabels: r.testLabels,
        topicLabels: r.topicLabels,
        illustrationCredits: {
          for (final e in r.illustrationCredits.entries)
            e.key: GuidanceCredit(author: e.value.author, license: e.value.license, text: e.value.text),
        },
      );

  static GuidanceWeek _week(PregnancyWeekDto w) {
    final size = w.fetalSize;
    final art = w.illustration;
    return GuidanceWeek(
      week: w.week,
      title: w.title,
      body: w.body,
      fetalSize: GuidanceFetalSize(lengthMm: size.lengthMm, weightG: size.weightG, comparison: size.comparison),
      testsDue: w.testsDue,
      dangerSigns: w.dangerSigns,
      topics: w.topics,
      illustration:
          art == null ? null : GuidanceIllustration(key: art.key, credit: art.credit, sourceUrl: art.sourceUrl),
      sources: w.sources,
    );
  }
}

/// The language guidance is asked for in: the app's own (`en`, `ar`).
final guidanceLanguageProvider = Provider<String>(
  (ref) => ref.watch(patientAppStateProvider.select((s) => s.lang.value)),
);

/// The composition-root binding: `pregnancyGuidanceSourceProvider.overrideWith(apiPregnancyGuidanceSource)`.
/// Follows the app's language: switching it rebuilds the source, and with it
/// the guidance, in the new language.
PregnancyGuidanceSource apiPregnancyGuidanceSource(Ref ref) => ApiPregnancyGuidance(
      api: ref.watch(contentApiProvider),
      kv: ref.watch(globalKVDataSourceProvider),
      language: ref.watch(guidanceLanguageProvider),
    );
