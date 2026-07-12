import 'package:meta/meta.dart';

import 'key_value_data_source.dart';
import 'storage_exceptions.dart';

/// One migration step: upgrades a preference group from version N-1 to N.
/// MUST be idempotent and tolerate missing keys — on a fresh install (or a
/// pre-versioning store) every step runs against whatever is present.
typedef PrefsMigrationStep = Future<void> Function(PrefsMigrator m);

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

  // ── Migrations ──────────────────────────────────────────────────────────

  /// Bump when the group's key layout changes; register the matching step in
  /// [migrations]. Version is stored under `<namespace>._v`.
  int get schemaVersion => 1;

  /// Target-version → step. Step `N` upgrades the group from `N-1` to `N`.
  ///
  /// ```dart
  /// @override
  /// int get schemaVersion => 2;
  ///
  /// @override
  /// Map<int, PrefsMigrationStep> get migrations => {
  ///       // v2: 'gdrive' value renamed, 'lang' key became 'locale'.
  ///       2: (m) async {
  ///         await m.transform<String>(
  ///             'storage', (v) => v == 'gdrive' ? 'google_drive' : v);
  ///         await m.rename('lang', 'locale');
  ///       },
  ///     };
  /// ```
  Map<int, PrefsMigrationStep> get migrations => const {};

  static const _versionKey = '_v';

  /// Runs pending migration steps, then stamps [schemaVersion]. Call once at
  /// bootstrap, before the group's first real read.
  ///
  /// - No stored version → treated as 0: every step runs (steps are
  ///   idempotent no-ops on a fresh store), then the version is stamped.
  /// - Stored version newer than [schemaVersion] → [StorageDecodeException]
  ///   (downgrade; refusing loudly beats corrupting newer-format data).
  /// - A failing step aborts WITHOUT stamping — the group retries next
  ///   launch instead of silently skipping.
  Future<void> migrate() async {
    final stored = await read<int>(_versionKey) ?? 0;
    if (stored == schemaVersion) return;
    if (stored > schemaVersion) {
      throw StorageDecodeException(
        '$namespace prefs: stored schema v$stored is newer than '
        'supported v$schemaVersion (downgrade not supported)',
      );
    }
    final migrator = PrefsMigrator._(this);
    for (var v = stored + 1; v <= schemaVersion; v++) {
      await migrations[v]?.call(migrator);
    }
    await write(_versionKey, schemaVersion);
  }
}

/// Key-level operations handed to migration steps — namespaced like the
/// owning group, plus move/transform conveniences.
class PrefsMigrator {
  PrefsMigrator._(this._group);

  final ModulePreferences _group;

  Future<T?> read<T>(String key) => _group.read<T>(key);
  Future<bool> contains(String key) => _group.contains(key);
  Future<void> write<T>(String key, T value) => _group.write<T>(key, value);
  Future<void> remove(String key) => _group.remove(key);

  /// Moves a value to a new key (no-op when [from] is absent).
  Future<void> rename(String from, String to) async {
    if (!await contains(from)) return;
    final value = await _group._kv.get<Object>(_group._key(from));
    await _group._kv.put(_group._key(to), value);
    await remove(from);
  }

  /// Rewrites a value in place (no-op when [key] is absent).
  Future<void> transform<T>(String key, T Function(T value) apply) async {
    final value = await read<T>(key);
    if (value == null) return;
    await write<T>(key, apply(value));
  }
}
