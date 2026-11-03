import '../../extensions/type_extensions.dart';
import 'unique_id.dart';

/// Typed id of a family group (`member_group`) a member profile is filed
/// under — "My family", "Neighbours", or one the patient added.
///
/// Lives in core (like [HealthProfileId]) because two modules name it: the
/// profile aggregate stores it on a member (`health_profile.group_id`) and the
/// family module owns the groups themselves.
class MemberGroupId extends UniqueId {
  const MemberGroupId.value(super.value) : super.value();
  const MemberGroupId.empty() : super.empty();
  MemberGroupId.uuid() : super.uuidv7('grp');

  static MemberGroupId? fromString(String? value) => value?.mapNotNull((v) => MemberGroupId.value(v));
}
