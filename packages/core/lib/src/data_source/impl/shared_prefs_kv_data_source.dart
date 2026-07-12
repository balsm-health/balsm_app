import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../key_value_data_source.dart';
import '../storage_exceptions.dart';

/// [GlobalKVDataSource] backed by `shared_preferences`.
///
/// STORAGE IS PLAINTEXT (NSUserDefaults / SharedPreferences XML). Suitable
/// for non-sensitive app state only — flags, UI prefs, onboarding markers.
/// NEVER store PHI (drift/SQLCipher tier) or secrets (SecureStorageWrapper).
///
/// Type mapping: `bool`/`int`/`double`/`String`/`List<String>` are stored
/// natively; `Map<String, dynamic>` (and [putObject]) as a JSON string.
/// A present-but-differently-typed value throws [StorageDecodeException] —
/// never a silent null (fail-loud).
///
/// Construction: inject the awaited instance so the class stays sync and
/// test-friendly (`SharedPreferences.setMockInitialValues({})` in tests):
///
/// ```dart
/// final prefs = await SharedPreferences.getInstance(); // bootstrap()
/// container = ProviderContainer(overrides: [
///   globalKVDataSourceProvider
///       .overrideWithValue(SharedPrefsKVDataSource(prefs)),
/// ]);
/// ```
class SharedPrefsKVDataSource extends GlobalKVDataSource {
  SharedPrefsKVDataSource(this._prefs);

  final SharedPreferences _prefs;

  /// Per-key change fan-out for [watch] (shared_preferences has no native
  /// change stream). Controllers are created lazily and live as long as the
  /// data source; emissions happen on every [put]/[delete]/[clear].
  final _watchers = <String, StreamController<Object?>>{};

  @override
  Future<T?> get<T>(String key) async {
    final raw = _prefs.get(key);
    if (raw == null) return null;
    return _decode<T>(key, raw);
  }

  @override
  Future<T?> getObject<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final map = await get<Map<String, dynamic>>(key);
    if (map == null) return null;
    try {
      return fromJson(map);
    } catch (e) {
      throw StorageDecodeException('key "$key": fromJson failed', e);
    }
  }

  @override
  Stream<T?> watch<T>(String key) {
    final controller = _watchers.putIfAbsent(
      key,
      () => StreamController<Object?>.broadcast(),
    );
    // Seed subscribers with the current value, then live changes.
    // Stream.multi (not async*): an async* generator parked in `await for`
    // on a quiet broadcast stream hangs its listener's cancel() until the
    // next event; Stream.multi tears down immediately.
    return Stream<T?>.multi((emitter) async {
      emitter.add(await get<T>(key));
      emitter.addStream(
        controller.stream.map(
          (raw) => raw == null ? null : _decode<T>(key, raw),
        ),
      );
    });
  }

  @override
  Future<bool> exists(String key) async => _prefs.containsKey(key);

  @override
  Future<void> put<T>(String key, T value) async {
    final ok = await switch (value) {
      final bool v => _prefs.setBool(key, v),
      final int v => _prefs.setInt(key, v),
      final double v => _prefs.setDouble(key, v),
      final String v => _prefs.setString(key, v),
      final List<String> v => _prefs.setStringList(key, v),
      final Map<String, dynamic> v => _prefs.setString(key, jsonEncode(v)),
      _ => throw StorageWriteException(
          'key "$key": unsupported type ${value.runtimeType} — '
          'use putObject with an explicit codec',
        ),
    };
    if (!ok) throw StorageWriteException('key "$key": platform write failed');
    _notify(key, _prefs.get(key));
  }

  @override
  Future<void> putObject<T>(
    String key,
    T value,
    Map<String, dynamic> Function(T value) toJson,
  ) async {
    final Map<String, dynamic> map;
    try {
      map = toJson(value);
    } catch (e) {
      throw StorageWriteException('key "$key": toJson failed', e);
    }
    await put<Map<String, dynamic>>(key, map);
  }

  @override
  Future<void> delete(String key) async {
    if (!await _prefs.remove(key)) {
      throw StorageWriteException('key "$key": platform remove failed');
    }
    _notify(key, null);
  }

  @override
  Future<void> clear() async {
    if (!await _prefs.clear()) {
      throw StorageWriteException('clear: platform clear failed');
    }
    for (final entry in _watchers.entries) {
      entry.value.add(null);
    }
  }

  void _notify(String key, Object? raw) => _watchers[key]?.add(raw);

  // Generic type literals can't appear as `==` operands directly
  // (`T == List<String>` mis-parses); compare through a helper.
  static Type _type<X>() => X;

  T _decode<T>(String key, Object raw) {
    // JSON-object path: stored as a String, requested as a Map.
    if (T == _type<Map<String, dynamic>>()) {
      if (raw is! String) {
        throw StorageDecodeException(
          'key "$key": expected json String, found ${raw.runtimeType}',
        );
      }
      try {
        return (jsonDecode(raw) as Map<String, dynamic>) as T;
      } catch (e) {
        throw StorageDecodeException('key "$key": invalid json', e);
      }
    }
    // shared_preferences returns List<Object?> for string lists on some
    // platforms — normalize before the type check.
    if (T == _type<List<String>>() && raw is List) {
      try {
        // Eager copy — a lazy .cast() would defer the type error past this
        // try/catch to the first element access.
        return List<String>.from(raw) as T;
      } catch (e) {
        throw StorageDecodeException('key "$key": non-string list entry', e);
      }
    }
    if (raw is! T) {
      throw StorageDecodeException(
        'key "$key": expected $T, found ${raw.runtimeType}',
      );
    }
    return raw as T;
  }
}
