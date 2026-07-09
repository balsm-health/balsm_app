import 'storage_exceptions.dart';

/// Base marker for all local data sources.
///
/// `K` is the record's typed id (a `UniqueId` subclass owned by the defining
/// module — e.g. `MedicationId`); `V` is the stored value type. There is no
/// shared "RecordId": every record type declares its own id class.
abstract class DataSourceBase<K, V> {}

/// Unscoped (partition-free) CRUD data source.
///
/// `put` accepts per-record persistence options:
/// - `durable`: record participates in encrypted backup/export
///   (`SnapshotService`); non-durable records are pure local cache, dropped on
///   device loss.
/// - `ttl`: record expires after this duration; expired records read as
///   `null` and are removed by [purgeExpired].
///
/// Error semantics are fail-loud — see [StorageException].
abstract class DataSource<K, V> extends DataSourceBase<K, V> {
  Future<V?> find(K key);
  Future<List<V>> findAll();
  Future<List<V>> findMany(Iterable<K> keys);
  Future<bool> exists(K key);
  Future<void> put(K key, V value, {bool durable = false, Duration? ttl});
  Future<void> putBulk(Map<K, V> values, {bool durable = false, Duration? ttl});
  Future<void> delete(K key);
  Future<void> deleteMany(Iterable<K> keys);
  Future<void> clear();
  Future<void> purgeExpired();
}

/// Partitioned CRUD data source. `S` is the scope (partition) type — e.g.
/// `UserId` for per-user data, `EntityId` for per-facility data, or a record
/// type like `({UserId user, EntityId entity})` for composite scopes later.
///
/// Scope resolution — every op takes an optional `scope`:
/// - `scope == null` → resolve the ACTIVE scope from context (the
///   `currentUserIdProvider` / `currentEntityIdProvider` ports). If no active
///   scope exists, mutations throw [NoActiveUserException] /
///   [NoActiveEntityException]; reads return `null`; [clear] is a no-op
///   (idempotent logout cleanup — it may run twice).
/// - `scope != null` → explicit override, e.g. pre-fetching data for an
///   entity the user is switching to.
abstract class ScopedDataSource<K, V, S> extends DataSourceBase<K, V> {
  Future<V?> find(K key, {S? scope});
  Future<List<V>> findAll({S? scope});
  Future<List<V>> findMany(Iterable<K> keys, {S? scope});
  Future<bool> exists(K key, {S? scope});
  Future<void> put(K key, V value,
      {S? scope, bool durable = false, Duration? ttl});
  Future<void> putBulk(Map<K, V> values,
      {S? scope, bool durable = false, Duration? ttl});
  Future<void> delete(K key, {S? scope});
  Future<void> deleteMany(Iterable<K> keys, {S? scope});

  /// Clears one partition (`scope`, or the active one when null).
  Future<void> clear({S? scope});

  /// Clears EVERY partition — e.g. wiping all entity caches on account
  /// deletion.
  Future<void> clearAll();

  Future<void> purgeExpired();
}

/// Reactive-read capability for unscoped sources. Implementations emit the
/// current value on every write/delete, and `null` on expiry of a watched key.
abstract class WatchableDataSource<K, V> {
  Stream<V?> watch(K key);
  Stream<List<V>> watchAll();
}

/// Reactive-read capability for scoped sources. Same null-scope semantics as
/// [ScopedDataSource]: `scope == null` watches the ACTIVE partition.
abstract class WatchableScopedDataSource<K, V, S> {
  Stream<V?> watch(K key, {S? scope});
  Stream<List<V>> watchAll({S? scope});
}
