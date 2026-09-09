import 'storage_exceptions.dart';

/// Base marker for all local data sources.
///
/// `K` is the record's typed id (a `UniqueId` subclass owned by the defining
/// module — e.g. `MedicationId`); `V` is the stored value type. There is no
/// shared "RecordId": every record type declares its own id class.
abstract class DataSourceBase<K, V> {}

/// Unscoped (partition-free) CRUD data source.
///
/// Deliberately policy-free: persistence policies (backup participation,
/// expiry) are NOT part of the generic contract — an implementation that
/// needs them owns them (e.g. a cache-tier source may add a policy'd `put`
/// via a capability interface later). Error semantics are fail-loud — see
/// [StorageException].
abstract class DataSource<K, V> extends DataSourceBase<K, V> {
  Future<V?> find(K key);
  Future<List<V>> findAll();
  Future<List<V>> findMany(Iterable<K> keys);
  Future<bool> exists(K key);
  Future<void> put(K key, V value);
  Future<void> putBulk(Map<K, V> values);
  Future<void> delete(K key);
  Future<void> deleteMany(Iterable<K> keys);
  Future<void> clear();
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
  Future<void> put(K key, V value, {S? scope});
  Future<void> putBulk(Map<K, V> values, {S? scope});
  Future<void> delete(K key, {S? scope});
  Future<void> deleteMany(Iterable<K> keys, {S? scope});

  /// Clears one partition (`scope`, or the active one when null).
  Future<void> clear({S? scope});

  /// Clears EVERY partition — e.g. wiping all entity caches on account
  /// deletion.
  Future<void> clearAll();
}

/// Reactive-read capability for scoped sources. Same null-scope semantics as
/// [ScopedDataSource]: `scope == null` watches the ACTIVE partition.
abstract class WatchableScopedDataSource<K, V, S> {
  Stream<V?> watch(K key, {S? scope});
  Stream<List<V>> watchAll({S? scope});
}
