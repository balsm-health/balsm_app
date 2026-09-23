import 'package:core/core.dart';

import '../../domain/aggregates/health_profile.dart';
import '../../domain/value_objects/ids.dart';

/// The health profile's child collections, each as its own scoped source.
///
/// They used to be written through `addAllergy`/`removeAllergy`/… on
/// [HealthProfilesDataSource] and read back hydrated into the aggregate. Both
/// halves are gone: each collection is its own key/value pair, so it gets the
/// generic contract — `put` (insert or update), `delete`, `findAll`,
/// `watchAll` — exactly as care providers and medications do.
///
/// Scope is the health profile, matching the `health_profile_id` column: this
/// is PHI about the SUBJECT, not the account that recorded it.
///
/// Splitting them costs the medical-profile screen three watches instead of
/// one join, and buys independent reads, independent invalidation, and no
/// last-write-wins deletion — putting an allergy can no longer disturb a
/// condition.
abstract class AllergiesDataSource extends ProfileDataSource<AllergyId, Allergy>
    implements WatchableScopedDataSource<AllergyId, Allergy, HealthProfileId> {}

abstract class ChronicConditionsDataSource extends ProfileDataSource<ChronicConditionId, ChronicCondition>
    implements WatchableScopedDataSource<ChronicConditionId, ChronicCondition, HealthProfileId> {}

abstract class EmergencyContactsDataSource extends ProfileDataSource<EmergencyContactId, EmergencyContact>
    implements WatchableScopedDataSource<EmergencyContactId, EmergencyContact, HealthProfileId> {}
