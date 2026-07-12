import '../domain/value_objects/entity_id.dart';
import 'data_source.dart';

/// Data partitioned by entity — a healthcare facility (clinic, hospital,
/// pharmacy). The user switches the active entity; null scope = the active
/// one (`currentEntityIdProvider`); explicit [EntityId] overrides (e.g.
/// pre-fetching the facility being switched to).
///
/// HOLDS ONLY facility-level, user-independent data: formulary caches,
/// doctors list, opening hours, per-facility config/flags. It may survive
/// logout (evicted by the cache implementation, not by sign-out).
///
/// MUST NOT hold PHI or anything derived from a user's interaction with the
/// facility — that is user-scoped ([UserDataSource]) so logout-wipe covers
/// it. If per-user-per-facility partitioning is ever needed, use a composite
/// scope (`({UserId user, EntityId entity})`) on [ScopedDataSource] instead
/// of weakening this rule.
abstract class EntityDataSource<K, V>
    extends ScopedDataSource<K, V, EntityId> {}
