import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/flavor.dart';
import '../data_source/key_value_data_source.dart';
import '../data_source/module_preferences.dart';

/// Overrides the manifest URL for a build (`--dart-define=APP_VERSION_URL=…`),
/// for a brand hosted somewhere else or a test manifest.
const _kVersionUrlOverride = String.fromEnvironment('APP_VERSION_URL');

/// Where a brand's app reads its release manifest.
///
/// Every brand has its own file on its own host —
/// `app.balsm.health/version/balsm.json`,
/// `pro.balsm.health/version/balsm_pro.json` — so a release, or a forced
/// update, for one brand can never reach the other's installs.
///
/// Always our own domain: the URL is baked into every shipped build, so it
/// must stay re-pointable. The Worker behind it (`deploy/web/worker.js`)
/// serves the copy on GitHub and falls back to the one bundled with the web
/// app — see `docs/app-update.md`.
String appVersionUrl(AppBrand brand) =>
    _kVersionUrlOverride.isNotEmpty ? _kVersionUrlOverride : '${brand.webOrigin}/version/${brand.name}.json';

/// The release-notes page the Worker builds from a brand's manifest, on that
/// brand's own host — the sheet's "Full release notes" link. A manifest may
/// name another with a top-level `"more"`.
String releaseNotesUrl(AppBrand brand) => '${brand.webOrigin}/whats-new';

/// Where "Update" goes when the manifest names no store link.
const kAppDownloadUrl = 'https://balsm.health/download';

enum UpdateStatus {
  /// Up to date, or nothing is known (offline, no manifest, unreadable).
  none,

  /// A newer version exists; this one may still be used.
  available,

  /// This build must be replaced: a newer release is marked forced, or the
  /// build is below the platform's minimum.
  required,
}

/// One line of a release's notes: a title and an optional sentence under it.
/// Plain text — the manifest carries no markup.
@immutable
class ReleaseNoteItem {
  const ReleaseNoteItem({required this.title, this.body = ''});
  final String title;
  final String body;
}

/// What changed in one release, in one language.
@immutable
class ReleaseNote {
  const ReleaseNote({required this.version, this.date, this.hasTime = false, this.items = const []});
  final String version;

  /// When the release went out, if the manifest says. A calendar day
  /// (`2026-10-09`), or — when [hasTime] — an exact instant in UTC
  /// (`2026-10-09T14:30:00Z`), to be shown in the reader's own time zone.
  final DateTime? date;

  /// Whether [date] carries a time of day, not just a day.
  final bool hasTime;
  final List<ReleaseNoteItem> items;

  bool get isEmpty => items.isEmpty;
}

@immutable
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.status,
    this.installed = '',
    this.latest = '',
    this.url = kAppDownloadUrl,
    this.notes = const [],
    this.notesUrl,
  });

  static const none = AppUpdateInfo(status: UpdateStatus.none);

  final UpdateStatus status;

  /// The version running now, for the "Current → New" row.
  final String installed;

  /// The newest version offered to this platform, as written (`1.4.0`).
  final String latest;

  /// Store or download page for this platform.
  final String url;

  /// Notes for every release newer than the installed one, newest first —
  /// someone three versions behind sees all three.
  final List<ReleaseNote> notes;

  /// The full release notes as a web page, already narrowed to this build:
  /// its brand, platform, language and installed version. Null when there is
  /// nothing to link to.
  final String? notesUrl;
}

/// Compares dotted versions numerically (`1.10.0` is newer than `1.9.3`). A
/// build suffix (`+7`) or pre-release tag (`-beta`) is ignored; missing parts
/// count as zero. Returns null when [v] is not a version at all.
List<int>? parseVersion(String v) {
  final core = v.trim().split(RegExp(r'[+\-]')).first;
  if (core.isEmpty) return null;
  final parts = <int>[];
  for (final p in core.split('.')) {
    final n = int.tryParse(p);
    if (n == null || n < 0) return null;
    parts.add(n);
  }
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts;
}

/// Negative when [a] is older than [b]; null when either is unreadable.
int? compareVersions(String a, String b) {
  final x = parseVersion(a), y = parseVersion(b);
  if (x == null || y == null) return null;
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

/// Decides what [installed] owes the manifest on one [platform]
/// (`ios` / `android` / `macos`), with release notes in [lang].
///
/// The manifest lists releases; each names its platforms, whether it is
/// forced, and its notes:
///
/// ```json
/// {
///   "stores": { "ios": "https://apps.apple.com/…" },
///   "min":    { "ios": "1.2.0" },
///   "versions": {
///     "1.4.0": { "force": false, "platforms": ["ios", "android"], "date": "2026-10-09T14:30:00Z",
///                "notes": { "en": [ { "title": "…", "body": "…" }, "A line with no body" ],
///                           "ar": [ { "title": "…" } ] } }
///   }
/// }
/// ```
///
/// `force` is `true` (every platform the release is on) or a list of the
/// platforms it is forced on — `"force": ["ios"]` — for when one store has
/// the build and the other is still in review.
///
/// An update is **required** when any newer release for this platform is
/// forced on it — so a forced release cannot be skipped by a later optional
/// one — or when [installed] is below `min`. Otherwise a newer release is
/// optional.
///
/// Fails open on purpose: a manifest that is missing, malformed, or silent
/// about this platform yields [AppUpdateInfo.none], and so does a build the
/// manifest does not list. A typo in a JSON file, or a dev build, must never
/// lock someone out of the app.
AppUpdateInfo evaluateUpdate({
  required String installed,
  required String? manifest,
  required String platform,
  String lang = 'en',
  AppBrand brand = AppBrand.balsm,
}) {
  if (manifest == null || manifest.isEmpty || parseVersion(installed) == null) return AppUpdateInfo.none;
  try {
    final root = jsonDecode(manifest);
    if (root is! Map<String, dynamic>) return AppUpdateInfo.none;

    // Releases for this platform that are newer than the installed build.
    final newer = <({String version, bool force, ReleaseNote note})>[];
    final versions = root['versions'];
    if (versions is Map<String, dynamic>) {
      for (final e in versions.entries) {
        final v = e.value;
        if (v is! Map<String, dynamic>) continue;
        final cmp = compareVersions(installed, e.key);
        if (cmp == null || cmp >= 0) continue;
        final platforms = v['platforms'];
        // No list means every platform.
        if (platforms is List && platforms.isNotEmpty && !platforms.contains(platform)) continue;
        newer.add((version: e.key, force: _isForced(v['force'], platform), note: _noteFor(e.key, v, lang)));
      }
    }
    newer.sort((a, b) => compareVersions(b.version, a.version)!);

    final min = _platformValue(root['min'], platform);
    final belowMin = min == null ? null : compareVersions(installed, min);
    final isBelowMin = belowMin != null && belowMin < 0;

    if (newer.isEmpty && !isBelowMin) return AppUpdateInfo.none;

    final rawUrl = _platformValue(root['stores'], platform) ?? '';
    final shown = installed.trim().split(RegExp(r'[+\-]')).first;
    final more = root['more'];
    final notesBase = more is String && more.startsWith('https://') ? more : releaseNotesUrl(brand);
    return AppUpdateInfo(
      status: isBelowMin || newer.any((r) => r.force) ? UpdateStatus.required : UpdateStatus.available,
      installed: shown,
      latest: newer.isEmpty ? min! : newer.first.version,
      url: rawUrl.startsWith('https://') ? rawUrl : kAppDownloadUrl,
      notes: [
        for (final r in newer)
          if (!r.note.isEmpty) r.note,
      ],
      notesUrl: Uri.parse(notesBase).replace(queryParameters: {
        ...Uri.parse(notesBase).queryParameters,
        'brand': brand.name,
        'from': shown,
        'platform': platform,
        'lang': lang,
      }).toString(),
    );
  } catch (_) {
    return AppUpdateInfo.none;
  }
}

/// Whether a release's `force` covers [platform]: `true` forces it wherever
/// the release exists; a list forces it only on the platforms it names.
/// Anything else — absent, `false`, a typo — forces nothing.
bool _isForced(Object? force, String platform) => force == true || (force is List && force.contains(platform));

String? _platformValue(Object? map, String platform) {
  if (map is! Map<String, dynamic>) return null;
  final v = map[platform];
  return v is String && v.isNotEmpty ? v : null;
}

/// One release's notes in [lang], else English, else whatever language is
/// there. A language's value is a list; each entry is `{title, body}` or just
/// a string (a title on its own). Anything else is skipped.
ReleaseNote _noteFor(String version, Map<String, dynamic> release, String lang) {
  final when = parseReleaseDate(release['date']);
  final date = when?.date;
  final hasTime = when?.hasTime ?? false;
  final notes = release['notes'];
  if (notes is Map<String, dynamic>) {
    for (final candidate in [notes[lang], notes['en'], ...notes.values]) {
      if (candidate is! List) continue;
      final items = <ReleaseNoteItem>[];
      for (final it in candidate) {
        if (it is String && it.trim().isNotEmpty) {
          items.add(ReleaseNoteItem(title: it.trim()));
        } else if (it is Map<String, dynamic>) {
          final title = it['title'];
          final body = it['body'];
          if (title is String && title.trim().isNotEmpty) {
            items.add(ReleaseNoteItem(title: title.trim(), body: body is String ? body.trim() : ''));
          }
        }
      }
      if (items.isNotEmpty) return ReleaseNote(version: version, date: date, hasTime: hasTime, items: items);
    }
  }
  return ReleaseNote(version: version, date: date, hasTime: hasTime);
}

/// Reads a release's `date`: a day (`2026-10-09`) or a date and time
/// (`2026-10-09T14:30:00Z`, `2026-10-09T17:30:00+03:00`).
///
/// A time is an instant, so it is normalised to UTC. One written without a
/// zone is taken as UTC too — the manifest is read all over the world, and
/// "local time" would mean a different moment on every phone.
({DateTime date, bool hasTime})? parseReleaseDate(Object? raw) {
  if (raw is! String) return null;
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) return null;
  if (!RegExp(r'\d[T ]\d{1,2}:\d{2}').hasMatch(raw)) {
    return (date: DateTime(parsed.year, parsed.month, parsed.day), hasTime: false);
  }
  final utc = parsed.isUtc
      ? parsed
      : DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second);
  return (date: utc, hasTime: true);
}

/// A release's date as the sheet prints it: `09/10/2026`, or with its time in
/// the reader's own zone, `09/10/2026 17:30`. Empty when there is no date.
String formatReleaseDate(ReleaseNote note) {
  final d = note.date;
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  final at = note.hasTime ? d.toLocal() : d;
  final day = '${two(at.day)}/${two(at.month)}/${at.year}';
  return note.hasTime ? '$day ${two(at.hour)}:${two(at.minute)}' : day;
}

/// The manifest key for the running platform, or null where there is nothing
/// to update (web is always the deployed build).
String? updatePlatformKey() {
  if (kIsWeb) return null;
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  if (Platform.isMacOS) return 'macos';
  return null;
}

/// What the update check keeps on the device (`update.*`). Each brand is its
/// own installed app with its own storage, so the keys need no brand in them.
class AppUpdatePrefs extends ModulePreferences {
  const AppUpdatePrefs(KeyValueDataSource kv) : super(kv, namespace: 'update');

  /// Last manifest fetched (raw JSON). Kept so a forced update still holds
  /// with no connection.
  Future<String?> manifest() => read<String>('manifest');
  Future<void> setManifest(String v) => write('manifest', v);

  /// The version the user chose to skip.
  Future<String?> skipped() => read<String>('skipped');
  Future<void> setSkipped(String v) => write('skipped', v);
}

/// Fetches a brand's manifest and remembers the last good copy.
///
/// The cache is what keeps a forced update forced while offline: without it,
/// turning on airplane mode would lift the block.
class AppUpdateChecker {
  AppUpdateChecker({required AppUpdatePrefs prefs, required AppBrand brand, Dio? dio, String? url})
      : _prefs = prefs,
        _brand = brand,
        _url = url ?? appVersionUrl(brand),
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              responseType: ResponseType.plain,
            ));

  final AppUpdatePrefs _prefs;
  final AppBrand _brand;
  final Dio _dio;
  final String _url;

  /// What the last fetched manifest says, without touching the network.
  Future<AppUpdateInfo> cached({required String lang}) async {
    final ctx = await _context();
    if (ctx == null) return AppUpdateInfo.none;
    return evaluateUpdate(
        installed: ctx.installed, manifest: await _prefs.manifest(), platform: ctx.platform, lang: lang, brand: _brand);
  }

  /// Fetches the manifest; on any failure answers from the cache.
  Future<AppUpdateInfo> check({required String lang}) async {
    final ctx = await _context();
    if (ctx == null) return AppUpdateInfo.none;
    String? manifest;
    try {
      final res = await _dio.get<String>(_url);
      final body = res.data;
      // Only a body that parses as an object replaces the cache — a captive
      // portal's HTML must not erase a known forced update.
      if (body != null && jsonDecode(body) is Map<String, dynamic>) {
        manifest = body;
        await _prefs.setManifest(body);
      }
    } catch (_) {
      // Offline or unreachable — fall through to the cache.
    }
    manifest ??= await _prefs.manifest();
    return evaluateUpdate(
        installed: ctx.installed, manifest: manifest, platform: ctx.platform, lang: lang, brand: _brand);
  }

  Future<({String installed, String platform})?> _context() async {
    final platform = updatePlatformKey();
    if (platform == null) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      return (installed: info.version, platform: platform);
    } catch (_) {
      // No platform channel (tests) — nothing to compare against.
      return null;
    }
  }
}
