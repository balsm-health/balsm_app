import 'package:balsm_api/balsm_api.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/active_server.dart';
import '../config/flavor.dart';
import '../config/server_preset.dart';
import '../domain/events/app_event.dart';
import '../event_bus/event_bus.dart';
import 'auth_interceptor.dart';

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
  })  : _client = client,
        _store = store,
        _bus = bus;

  final BalsmApiClient _client;
  final ActiveServerStore _store;
  final EventBus _bus;

  BalsmApiClient get client => _client;

  Future<void> init() async {
    final preset = await _store.read() ?? _store.defaultPreset;
    _client.baseUrl = preset.apiBaseUrl;
  }

  Future<void> reconfigure(ServerPreset preset) async {
    await _store.write(preset);
    _client.baseUrl = preset.apiBaseUrl;
    _bus.publish(ServerReconfigured(preset));
  }

  static BalsmApiController create({
    required FlutterSecureStorage storage,
    required EventBus bus,
  }) {
    final client = BalsmApiClient.create(
      baseUrl: FlavorConfig.current.defaultServer.apiBaseUrl,
      logRequests: kDebugMode,
    );
    // Attach the bearer token to authenticated requests + refresh-on-401.
    // Without this, no request carries a token and every authenticated
    // endpoint returns 401.
    client.dio.interceptors.add(AuthInterceptor(client: client, storage: storage, bus: bus));
    return BalsmApiController(
      client: client,
      store: ActiveServerStore(storage),
      bus: bus,
    );
  }
}
