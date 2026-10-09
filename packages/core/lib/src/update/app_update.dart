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
/// Every brand has its own file — `…/version/balsm.json`,
/// `…/version/balsm_pro.json` — so a release, or a forced update, for one
/// brand can never reach the other's installs.
///
/// Always our own domain: the URL is baked into every shipped build, so it
/// must stay re-pointable. The Worker behind it (`deploy/web/worker.js`)
/// serves the copy on GitHub and falls back to the one bundled with the web
/// app — see `docs/app-update.md`.
String appVersionUrl(AppBrand brand) =>
    _kVersionUrlOverride.isNotEmpty ? _kVersionUrlOverride : 'https://app.balsm.health/version/${brand.name}.json';

/// The release-notes page the Worker builds from a brand's manifest — the
/// sheet's "Full release notes" link. A manifest may name another with a
/// top-level `"more"`.
const kReleaseNotesUrl = 'https://app.balsm.health/whats-new';

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

/// One line of a release's notes — `update.jsx`'s icon / title / description
/// row. [body] may carry inline HTML (bold, links); it is rendered through the
/// same allow-list as a free-form note.
@immutable
class ReleaseNoteItem {
  const ReleaseNoteItem({required this.title, this.icon = '', this.body = ''});

  /// A Lucide icon name (`bell-ring`). Unknown names fall back to a sparkle.
  final String icon;
  final String title;
  final String body;
}

/// What changed in one release, in one language. The manifest writes it either
/// as a list of [items] (the designed rows) or as free-form [html]; a release
/// may use either.
@immutable
class ReleaseNote {
  const ReleaseNote({required this.version, this.date, this.items = const [], this.html});
  final String version;

  /// Release day, when the manifest gives one.
  final DateTime? date;
  final List<ReleaseNoteItem> items;
  final String? html;

  bool get isEmpty => items.isEmpty && (html == null || html!.trim().isEmpty);
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
///     "1.4.0": { "force": false, "platforms": ["ios", "android"], "date": "2026-10-09",
///                "notes": { "en": [ { "icon": "bell-ring", "title": "…", "body": "…" } ],
///                           "ar": "<ul><li>…</li></ul>" } }
///   }
/// }
/// ```
///
/// An update is **required** when any newer release for this platform is
/// forced — so a forced release cannot be skipped by a later optional one —
/// or when [installed] is below `min`. Otherwise a newer release is optional.
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
        newer.add((version: e.key, force: v['force'] == true, note: _noteFor(e.key, v, lang)));
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
    final notesBase = more is String && more.startsWith('https://') ? more : kReleaseNotesUrl;
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

String? _platformValue(Object? map, String platform) {
  if (map is! Map<String, dynamic>) return null;
  final v = map[platform];
  return v is String && v.isNotEmpty ? v : null;
}

/// One release's notes in [lang], else English, else whatever language is
/// there. A language's value is a list of rows or an HTML string.
ReleaseNote _noteFor(String version, Map<String, dynamic> release, String lang) {
  final rawDate = release['date'];
  final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
  final notes = release['notes'];
  if (notes is Map<String, dynamic>) {
    for (final candidate in [notes[lang], notes['en'], ...notes.values]) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return ReleaseNote(version: version, date: date, html: candidate);
      }
      if (candidate is List) {
        final items = <ReleaseNoteItem>[
          for (final it in candidate)
            if (it is Map<String, dynamic> && it['title'] is String && (it['title'] as String).trim().isNotEmpty)
              ReleaseNoteItem(
                title: (it['title'] as String).trim(),
                icon: it['icon'] is String ? it['icon'] as String : '',
                body: it['body'] is String ? it['body'] as String : '',
              ),
        ];
        if (items.isNotEmpty) return ReleaseNote(version: version, date: date, items: items);
      }
    }
  }
  return ReleaseNote(version: version, date: date);
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
