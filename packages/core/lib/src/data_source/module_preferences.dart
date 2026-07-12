import 'package:meta/meta.dart';

import 'key_value_data_source.dart';

/// Base for a module/package's preference group.
///
/// Groups all of one module's preferences under a single namespace on a
/// shared [KeyValueDataSource] — no raw keys or `SharedPreferences` at call
/// sites. Each module declares ONE subclass with typed accessors:
///
/// ```dart
/// class MedicationsPrefs extends ModulePreferences {
///   MedicationsPrefs(super.kv) : super(namespace: 'medications');
///
///   Future<bool> remindersEnabled() async =>
///       await read<bool>('remindersEnabled') ?? true;
///   Future<void> setRemindersEnabled(bool v) =>
///       write('remindersEnabled', v);
/// }
/// ```
///
/// Keys are stored as `<namespace>.<key>`, keeping modules collision-free on
/// the shared store. The backing store is injected (bound in the composition
/// root via `globalKVDataSourceProvider` or constructed directly) — consumers
/// never see the storage technology.
abstract class ModulePreferences {
  const ModulePreferences(this._kv, {required this.namespace});

  final KeyValueDataSource _kv;

  /// Key prefix — use the module name (`'medications'`, `'pa'`, …).
  final String namespace;

  String _key(String key) => '$namespace.$key';

  @protected
  Future<T?> read<T>(String key) => _kv.get<T>(_key(key));

  @protected
  Future<bool> contains(String key) => _kv.exists(_key(key));

  @protected
  Future<void> write<T>(String key, T value) => _kv.put<T>(_key(key), value);

  @protected
  Future<void> remove(String key) => _kv.delete(_key(key));
}
