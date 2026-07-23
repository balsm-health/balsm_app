import '../domain/value_objects/health_profile_id.dart';
import 'data_source.dart';

/// Data partitioned by health profile — the **person** the PHI is about
/// (subject), not the account that recorded it (actor). Null scope = the
/// active profile (`currentProfileIdProvider` — the signed-in user's self
/// profile until the dependants feature adds a switcher); explicit
/// [HealthProfileId] overrides.
///
/// This is the PHI-subject sibling of [UserDataSource]: medications, dose
/// history, and health records belong to the person they describe, so a
/// dependant's data stays isolated from the guardian's own even though both
/// partitions live on the guardian's device. In v1 every on-device profile
/// belongs to the signed-in account, so logout-wipe covers all partitions
/// via `clearAll`.
///
/// NOT for facility data — that is [EntityDataSource], which must never
/// hold PHI.
abstract class ProfileDataSource<K, V>
    extends ScopedDataSource<K, V, HealthProfileId> {}
