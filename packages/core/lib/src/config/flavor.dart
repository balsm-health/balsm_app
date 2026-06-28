import 'server_preset.dart';

/// Environment axis (a.k.a. build env).
enum Flavor { dev, staging, prod }

/// Brand axis. `balsm` is the consumer app; `balsmPro` the professional build.
enum AppBrand { balsm, balsmPro }

/// Runtime build configuration, resolved from two independent axes — the
/// [brand] (Balsm / Balsm-Pro) and the [flavor] (dev / staging / prod) — so a
/// single entrypoint serves every combination via `--dart-define`s instead of
/// one `main_<x>.dart` per permutation.
class FlavorConfig {
  final AppBrand brand;
  final Flavor flavor;

  /// The API base URL the app boots against — the [servers] entry matching the
  /// current [flavor] (dev→Local, staging→Staging, prod→Production).
  final String apiBaseUrl;

  /// The switchable API servers, sourced from the shared `ENVS` define
  /// (`env/envs.json`). The dev server selector lets the user switch between
  /// them.
  final List<ServerPreset> servers;

  final String? sentryDsn;
  final String appName;
  final String appNameSuffix;
  final bool serverSelectorEnabled;

  const FlavorConfig({
    required this.brand,
    required this.flavor,
    required this.apiBaseUrl,
    required this.servers,
    this.sentryDsn,
    required this.appName,
    required this.appNameSuffix,
    required this.serverSelectorEnabled,
  });

  static FlavorConfig? _current;
  static FlavorConfig get current {
    assert(_current != null, 'FlavorConfig.init() must be called before accessing current');
    return _current!;
  }

  bool get isPro => brand == AppBrand.balsmPro;

  static AppBrand brandFromString(String? s) =>
      s == 'balsm_pro' || s == 'balsmPro' ? AppBrand.balsmPro : AppBrand.balsm;
  static Flavor flavorFromString(String? s) => switch (s) {
        'prod' => Flavor.prod,
        'staging' || 'stg' => Flavor.staging,
        _ => Flavor.dev,
      };

  /// Parse the `ENVS` define into the switchable server list.
  ///
  /// `ENVS` lives in the shared `env/envs.json` as a plain JSON array, e.g.
  /// `[{ "name": "Local", "url": "http://localhost:5000" }]`. Because
  /// `--dart-define-from-file` stringifies non-primitive values with Dart's
  /// `toString()` (not JSON), the value reaches us looking like
  /// `[{name: Local, url: http://localhost:5000}, ...]` — unquoted, comma-space
  /// separated. We pull each `{...}` object out and split its `key: value`
  /// pairs. This relies on names/urls containing no `, ` or `: ` (true for
  /// urls, which use `://` / `:port` without spaces). Falls back to a single
  /// `Local` preset when the define is empty or unparseable.
  static List<ServerPreset> _parseServers(String raw) {
    final servers = <ServerPreset>[];
    for (final obj in RegExp(r'\{([^}]*)\}').allMatches(raw)) {
      final fields = <String, String>{};
      for (final pair in obj.group(1)!.split(', ')) {
        final sep = pair.indexOf(': ');
        if (sep < 0) continue;
        fields[pair.substring(0, sep).trim()] = pair.substring(sep + 2).trim();
      }
      final url = fields['url'];
      if (url == null || url.isEmpty) continue;
      servers.add(ServerPreset(label: fields['name'] ?? url, apiBaseUrl: url));
    }
    if (servers.isEmpty) {
      servers.add(const ServerPreset(label: 'Local', apiBaseUrl: 'http://localhost:5000'));
    }
    return servers;
  }

  /// The server the given [flavor] boots against: the [servers] entry whose
  /// label matches the flavor (dev→Local, staging→Staging, prod→Production),
  /// falling back to the first entry.
  static ServerPreset _defaultServerFor(Flavor flavor, List<ServerPreset> servers) {
    final want = switch (flavor) {
      Flavor.dev => 'local',
      Flavor.staging => 'staging',
      Flavor.prod => 'production',
    };
    for (final s in servers) {
      if (s.label.toLowerCase() == want) return s;
    }
    return servers.first;
  }

  /// Resolve from `--dart-define`s (`APP`, `FLAVOR`/`ENV`, `ENVS`,
  /// `SENTRY_DSN`). This is the single source of truth — call once at startup.
  static void initFromEnvironment() {
    const app = String.fromEnvironment('APP', defaultValue: 'balsm');
    const flavorStr = String.fromEnvironment(
      'FLAVOR',
      defaultValue: String.fromEnvironment('ENV', defaultValue: 'dev'),
    );
    init(brand: brandFromString(app), flavor: flavorFromString(flavorStr));
  }

  /// Explicit init (used by [initFromEnvironment] and tests).
  static void init({required AppBrand brand, required Flavor flavor}) {
    const serversRaw = String.fromEnvironment('ENVS', defaultValue: '');
    const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
    final servers = _parseServers(serversRaw);
    final base = brand == AppBrand.balsmPro ? 'Balsm Pro' : 'Balsm';
    final envSuffix = switch (flavor) { Flavor.dev => ' Dev', Flavor.staging => ' Staging', Flavor.prod => '' };
    _current = FlavorConfig(
      brand: brand,
      flavor: flavor,
      apiBaseUrl: _defaultServerFor(flavor, servers).apiBaseUrl,
      servers: servers,
      sentryDsn: sentryDsn.isEmpty ? null : sentryDsn,
      appName: '$base$envSuffix',
      appNameSuffix: envSuffix,
      serverSelectorEnabled: flavor == Flavor.dev,
    );
  }
}
