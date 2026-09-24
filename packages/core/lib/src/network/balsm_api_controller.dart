import 'package:balsm_api/balsm_api.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/active_server.dart';
import '../dev/dev_host_locator.dart';
import '../config/flavor.dart';
import '../config/server_preset.dart';
import '../domain/events/app_event.dart';
import '../event_bus/event_bus.dart';
import 'auth_interceptor.dart';
import 'dev_host_interceptor.dart';

class ServerReconfigured extends AppEvent {
  final ServerPreset preset;
  const ServerReconfigured(this.preset);
  @override
  String get eventName => 'server_reconfigured';
  @override
  Map<String, dynamic> toJson() => {'preset': preset.apiBaseUrl};
}

/// Flutter-side owner of the pure [BalsmApiClient]: applies persisted server
/// presets on startup and handles dev-time server switching.
class BalsmApiController {
  BalsmApiController({
    required BalsmApiClient client,
    required ActiveServerStore store,
    required EventBus bus,
    DevHostLocator? devHost,
  })  : _client = client,
        _store = store,
        _bus = bus,
        _devHost = devHost ?? DevHostLocator();

  final BalsmApiClient _client;
  final ActiveServerStore _store;
  final EventBus _bus;

  /// Finds the machine serving a `localhost` preset. A no-op outside a debug
  /// build and for every URL that names a real host.
  final DevHostLocator _devHost;

  BalsmApiClient get client => _client;

  Future<void> init() async {
    // Prod cannot switch servers — never honour a leftover Local preset
    // from a previous Dev Config session (that is what pointed the hosted
    // web shell at http://localhost:5050).
    final saved = FlavorConfig.current.serverSwitchingEnabled ? await _store.read() : null;
    final preset = saved ?? _store.defaultPreset;
    _client.baseUrl = await _resolve(preset.apiBaseUrl);
  }

  /// A loopback URL, pointed at whatever is actually serving it.
  ///
  /// On a simulator or desktop that is loopback itself and the lookup costs one
  /// local request. On a device it is the machine on the desk, found by sweep.
  /// `DEV_HOST`, when a launch compiled one in, is offered as the first guess
  /// so the usual case never sweeps at all.
  Future<String> _resolve(String url) {
    // DEV_HOST is a guess to try first, never a rewrite: it was true when the
    // build launched, and the whole point of looking at runtime is that it
    // stops being true. Applying it blindly would hide a moved server behind
    // an address that no longer answers.
    final preferred =
        FlavorConfig.current.flavor == Flavor.prod || FlavorConfig.devHost.isEmpty ? null : FlavorConfig.devHost;
    return _devHost.resolve(url, preferred: preferred);
  }

  /// Looks the host up again and repoints the client.
  ///
  /// Called when a request cannot connect: the laptop moved network, the lease
  /// changed, the server restarted somewhere else. Returns the new base URL
  /// when it differs from the current one, so the caller can retry.
  Future<String?> rediscover() async {
    if (!FlavorConfig.current.serverSwitchingEnabled) return null;
    final current = Uri.tryParse(_client.baseUrl);
    if (current == null) return null;
    // Re-ask from the preset, not from the resolved URL: the resolved one
    // names a machine that has just stopped answering.
    final saved = await _store.read();
    final resolved = await _resolve((saved ?? _store.defaultPreset).apiBaseUrl);
    if (resolved == _client.baseUrl) return null;
    _client.baseUrl = resolved;
    return resolved;
  }

  Future<void> reconfigure(ServerPreset preset) async {
    // Repointed the same way a saved preset is on boot: picking "Local" in Dev
    // Config, or typing a localhost URL into a custom environment, means this
    // machine — which from a device on the desk is a LAN address, not its own
    // loopback. Stored as chosen, so the rewrite follows the machine rather
    // than being baked into secure storage.
    final resolved = ServerPreset(label: preset.label, apiBaseUrl: await _resolve(preset.apiBaseUrl));
    await _store.write(preset);
    _client.baseUrl = resolved.apiBaseUrl;
    _bus.publish(ServerReconfigured(resolved));
  }

  static BalsmApiController create({
    required FlutterSecureStorage storage,
    required EventBus bus,
  }) {
    final client = BalsmApiClient.create(
      baseUrl: FlavorConfig.current.defaultServer.apiBaseUrl,
    );
    // Attach the bearer token to authenticated requests + refresh-on-401.
    // Without this, no request carries a token and every authenticated
    // endpoint returns 401.
    client.dio.interceptors.add(AuthInterceptor(client: client, storage: storage, bus: bus));
    // Debug-only: full request/response console logger (tag `balsm.http`),
    // unredacted. Added LAST so the request log includes the bearer that the
    // auth interceptor just attached. Never runs in a release build.
    if (kDebugMode) client.dio.interceptors.add(const HttpLogInterceptor());
    final controller = BalsmApiController(
      client: client,
      store: ActiveServerStore(storage),
      bus: bus,
    );
    // Debug only, and only ever consulted when a request fails to connect: the
    // dev machine's address changes under a running app, and re-finding it
    // beats relaunching to pick up a new one.
    if (kDebugMode) {
      client.dio.interceptors.add(DevHostInterceptor(
        rediscover: controller.rediscover,
        retry: (options) => client.dio.fetch<dynamic>(options),
      ));
    }
    return controller;
  }
}
