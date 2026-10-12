import '../../extensions/type_extensions.dart';
import 'unique_id.dart';

/// Typed user identity — the scope key for user-partitioned storage.
/// Server-authoritative ids come via [UserId.value]; locally-minted ids
/// (offline sign-up) via [UserId.uuid] carry the `local-` provenance prefix.
class UserId extends UniqueId {
  const UserId.value(super.value) : super.value();
  const UserId.empty() : super.empty();
  UserId.uuid() : super.uuidv7('usr');

  static UserId? fromString(String? value) => value?.mapNotNull((v) => UserId.value(v));
}
