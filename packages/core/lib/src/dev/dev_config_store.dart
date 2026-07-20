import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A user-defined backend saved from the Dev Config Environment tab.
class SavedEnv {
  const SavedEnv({required this.id, required this.name, required this.url});
  final String id;
  final String name;
  final String url;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url};
  factory SavedEnv.fromJson(Map<String, dynamic> j) =>
      SavedEnv(id: j['id'] as String, name: j['name'] as String, url: j['url'] as String);
}

/// Feature-flag descriptor for the Environment tab (mirrors devconfig.jsx
/// `DC_FLAGS`). Persist-only for now — toggles are stored, effects are wired
/// per-flag over time.
class DevFlag {
  const DevFlag(this.id, this.label, this.desc);
  final String id;
  final String label;
  final String desc;
}

const kDevFlags = <DevFlag>[
  DevFlag('offline', 'Force offline mode', 'Simulate no network connectivity'),
  DevFlag('slow_net', 'Throttle to 3G', 'Limit API throughput to 400 kbps'),
  DevFlag('mock_api', 'Mock API responses', 'Serve fixture data instead of live'),
  DevFlag('rtl_dbg', 'RTL debug overlay', 'Highlight directionality issues'),
];

/// Persists Dev Config state: saved custom environments and feature flags in
/// [SharedPreferences]; the log-encryption key in the OS keychain (never prefs
/// — it is a secret). Dev-tooling only.
class DevConfigStore extends ChangeNotifier {
  DevConfigStore({FlutterSecureStorage? secureStorage})
      : _secure = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  static const _kSavedEnvs = 'balsm_dev_saved_envs';
  static const _kFlagPrefix = 'balsm_flag_';
  static const _kEncKey = 'balsm.dev_log_key';

  List<SavedEnv> _savedEnvs = [];
  final Map<String, bool> _flags = {for (final f in kDevFlags) f.id: false};
  String _encKey = '';

  List<SavedEnv> get savedEnvs => List.unmodifiable(_savedEnvs);
  bool flag(String id) => _flags[id] ?? false;
  String get encKey => _encKey;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_kSavedEnvs);
    if (raw != null) {
      try {
        _savedEnvs = (jsonDecode(raw) as List)
            .map((e) => SavedEnv.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _savedEnvs = [];
      }
    }

    for (final f in kDevFlags) {
      _flags[f.id] = prefs.getBool('$_kFlagPrefix${f.id}') ?? false;
    }

    _encKey = await _secure.read(key: _kEncKey) ?? '';
    if (_encKey.isEmpty) {
      _encKey = _generateKey();
      await _secure.write(key: _kEncKey, value: _encKey);
    }

    notifyListeners();
  }

  Future<SavedEnv> addSavedEnv(String name, String url) async {
    final env = SavedEnv(
        id: 'saved_${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        url: url.trim());
    _savedEnvs = [..._savedEnvs, env];
    await _persistEnvs();
    return env;
  }

  Future<void> updateSavedEnv(String id, String name, String url) async {
    _savedEnvs = _savedEnvs
        .map((e) => e.id == id ? SavedEnv(id: id, name: name.trim(), url: url.trim()) : e)
        .toList();
    await _persistEnvs();
  }

  Future<void> deleteSavedEnv(String id) async {
    _savedEnvs = _savedEnvs.where((e) => e.id != id).toList();
    await _persistEnvs();
  }

  Future<void> setFlag(String id, bool value) async {
    _flags[id] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kFlagPrefix$id', value);
    notifyListeners();
  }

  Future<void> _persistEnvs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kSavedEnvs, jsonEncode(_savedEnvs.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  static String _generateKey() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(20, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
