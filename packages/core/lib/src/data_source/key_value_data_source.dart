import '../domain/value_objects/user_id.dart';
import 'storage_exceptions.dart';

// NOTE: deliberately NOT `DataSource<String, dynamic>` — a KV store is
// heterogeneous (bool flag, string pref, json object under sibling keys), so
// type safety must come from METHOD-level generics (`get<T>`), which a
// class-level `V` cannot express. `dynamic` would make every read a blind
// cast and defeat the fail-loud decode model ([StorageDecodeException]).
//
// Secrets (tokens, backup keys) are a different tier: keychain/keystore via
// `SecureStorageWrapper` — never modelled as a KV data source.

/// Unscoped (app/device-wide) key-value store: feature flags, app config,
/// onboarding state. NoSQL-backed (e.g. sembast) or a drift kv table.
///
/// Supported primitive types for [get]/[put]: `bool`, `int`, `double`,
/// `String`, `List<String>`, `Map<String, dynamic>` (raw json). Typed objects
/// go through [getObject]/[putObject] with explicit codecs.
///
/// A present-but-wrong-typed value throws [StorageDecodeException] (never a
/// silent null); absent keys return null.
abstract class KeyValueDataSource {
  Future<T?> get<T>(String key);
  Future<T?> getObject<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  );
  Stream<T?> watch<T>(String key);
  Future<bool> exists(String key);
  Future<void> put<T>(String key, T value);
  Future<void> putObject<T>(
    String key,
    T value,
    Map<String, dynamic> Function(T value) toJson,
  );
  Future<void> delete(String key);
  Future<void> clear();
}

/// Partitioned key-value store. Same scope semantics as `ScopedDataSource`:
/// `scope == null` resolves the ACTIVE partition from context; no active
/// context → mutations throw ([NoActiveUserException]), reads return null,
/// [clear] is an idempotent no-op.
abstract class ScopedKeyValueDataSource<S> {
  Future<T?> get<T>(String key, {S? scope});
  Future<T?> getObject<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson, {
    S? scope,
  });
  Stream<T?> watch<T>(String key, {S? scope});
  Future<bool> exists(String key, {S? scope});
  Future<void> put<T>(String key, T value, {S? scope});
  Future<void> putObject<T>(
    String key,
    T value,
    Map<String, dynamic> Function(T value) toJson, {
    S? scope,
  });
  Future<void> delete(String key, {S? scope});

  /// Clears one partition (`scope`, or the active one when null).
  Future<void> clear({S? scope});

  /// Clears EVERY partition.
  Future<void> clearAll();
}

/// App-wide settings/flags — survives login/logout.
abstract class GlobalKVDataSource extends KeyValueDataSource {}

/// The current user's settings/prefs/drafts — wiped by logout `clear()`.
/// USER SETTINGS LIVE HERE, not in the global store: partitioning by
/// [UserId] is what makes logout-wipe and multi-account correct.
abstract class UserKVDataSource extends ScopedKeyValueDataSource<UserId> {}
