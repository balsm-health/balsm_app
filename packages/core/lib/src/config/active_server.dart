import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'flavor.dart';
import 'server_preset.dart';

class ActiveServerStore {
  final FlutterSecureStorage _storage;
  static const _key = 'balsm.active_server_preset';
  const ActiveServerStore(this._storage);

  Future<ServerPreset?> read() async {
    final json = await _storage.read(key: _key);
    if (json == null) return null;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      // A loopback URL saved on a previous run is repointed too: the phone
      // kept "Local — http://localhost:5050" from a simulator session, and
      // without this the saved choice quietly outranks the launch's DEV_HOST.
      return ServerPreset(
        label: m['label'] as String,
        apiBaseUrl: FlavorConfig.current.withDevHost(m['apiBaseUrl'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(ServerPreset p) async =>
      _storage.write(key: _key, value: jsonEncode({'label': p.label, 'apiBaseUrl': p.apiBaseUrl}));

  Future<void> clear() async => _storage.delete(key: _key);

  /// Boot default when nothing was saved: the first configured server.
  ServerPreset get defaultPreset => FlavorConfig.current.defaultServer;
}
