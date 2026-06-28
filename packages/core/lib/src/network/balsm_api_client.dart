import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/active_server.dart';
import '../config/flavor.dart';
import '../config/server_preset.dart';
import '../domain/events/app_event.dart';
import '../event_bus/event_bus.dart';
import 'phi_leak_interceptor.dart';

class ServerReconfigured extends AppEvent {
  final ServerPreset preset;
  const ServerReconfigured(this.preset);
  @override String get eventName => 'server_reconfigured';
  @override Map<String, dynamic> toJson() => {'preset': preset.apiBaseUrl};
}

class BalsmApiClient {
  final Dio _dio;
  final ActiveServerStore _store;
  final EventBus _bus;

  BalsmApiClient({
    required Dio dio,
    required ActiveServerStore store,
    required EventBus bus,
  })  : _dio = dio,
        _store = store,
        _bus = bus;

  Dio get dio => _dio;

  Future<void> init() async {
    final preset = await _store.read() ?? _store.defaultPreset;
    _dio.options.baseUrl = preset.apiBaseUrl;
  }

  Future<void> reconfigure(ServerPreset preset) async {
    await _store.write(preset);
    _dio.options.baseUrl = preset.apiBaseUrl;
    _bus.publish(ServerReconfigured(preset));
  }

  static BalsmApiClient create({
    required FlutterSecureStorage storage,
    required EventBus bus,
  }) {
    final store = ActiveServerStore(storage);
    final dio = Dio(BaseOptions(
      baseUrl: FlavorConfig.current.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(PhiLeakInterceptor());
    return BalsmApiClient(dio: dio, store: store, bus: bus);
  }
}
