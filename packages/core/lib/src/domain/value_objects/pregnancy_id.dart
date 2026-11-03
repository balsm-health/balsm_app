import '../../extensions/type_extensions.dart';
import 'unique_id.dart';

/// Typed id of a pregnancy (`pregnancy`) — the mother's tracker that a
/// prenatal (baby) profile points back to through `health_profile.pregnancy_id`.
///
/// Lives in core (like [MemberGroupId]) because two modules name it: the
/// profile aggregate stores it on a baby's profile and the pregnancy module
/// owns the pregnancy itself.
class PregnancyId extends UniqueId {
  const PregnancyId.value(super.value) : super.value();
  const PregnancyId.empty() : super.empty();
  PregnancyId.uuid() : super.uuidv7('preg');

  static PregnancyId? fromString(String? value) => value?.mapNotNull((v) => PregnancyId.value(v));
}
