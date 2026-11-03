import '../../extensions/type_extensions.dart';
import 'unique_id.dart';

/// Typed id of a health profile — the on-device PHI partition for one
/// **person**. Every account has one self profile (ensured at session
/// start) and may own member profiles (dependent / prenatal) beside it.
///
/// Lives in core (not the profile module) because it is the *scope* type of
/// `ProfileDataSource` — medications, records, and any future PHI store
/// partition by it without depending on the profile module.
class HealthProfileId extends UniqueId {
  const HealthProfileId.value(super.value) : super.value();
  const HealthProfileId.empty() : super.empty();
  HealthProfileId.uuid() : super.uuidv7('hp');

  static HealthProfileId? fromString(String? value) => value?.mapNotNull((v) => HealthProfileId.value(v));
}
