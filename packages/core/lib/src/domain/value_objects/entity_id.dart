import '../../extensions/type_extensions.dart';
import 'unique_id.dart';

/// Typed entity identity — an entity is a healthcare facility (clinic,
/// hospital, pharmacy). Scope key for entity-partitioned storage; the active
/// entity is exposed by `currentEntityIdProvider` and switched by the user.
class EntityId extends UniqueId {
  const EntityId.value(super.value) : super.value();
  const EntityId.empty() : super.empty();
  EntityId.uuid() : super.uuidv7('entity');

  static EntityId? fromString(String? value) => value?.mapNotNull((v) => EntityId.value(v));
}
