import '../../extensions/type_extensions.dart';
import 'unique_id.dart';

/// Typed id of a health profile — the on-device PHI partition for one
/// **person**. Today every account has exactly one (its self profile,
/// ensured at session start); the dependants feature (P00X) adds sibling
/// profiles owned by the same account.
///
/// Lives in core (not the profile module) because it is the *scope* type of
/// `ProfileDataSource` — medications, records, and any future PHI store
/// partition by it without depending on the profile module.
class HealthProfileId extends UniqueId {
  const HealthProfileId.value(super.value) : super.value();
  const HealthProfileId.empty() : super.empty();
  HealthProfileId.uuid() : super.uuid('hp-');

  static HealthProfileId? fromString(String? value) => value?.mapNotNull((v) => HealthProfileId.value(v));
}
