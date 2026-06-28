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
      return ServerPreset(label: m['label'] as String, apiBaseUrl: m['apiBaseUrl'] as String);
    } catch (_) { return null; }
  }

  Future<void> write(ServerPreset p) async =>
      _storage.write(key: _key, value: jsonEncode({'label': p.label, 'apiBaseUrl': p.apiBaseUrl}));

  Future<void> clear() async => _storage.delete(key: _key);

  ServerPreset get defaultPreset =>
      ServerPreset(label: 'Default', apiBaseUrl: FlavorConfig.current.apiBaseUrl);
}
