import 'package:core/core.dart';

import '../../domain/aggregates/growth_entry.dart';
import '../../domain/value_objects/growth_entry_id.dart';

/// Persistence port for the growth log.
///
/// Scoped by the PERSON measured (`ProfileDataSource`, partition = health
/// profile): with no scope every read and write follows core's active
/// profile. Reads leave soft-deleted entries out and list the newest
/// measurement first. [delete] is soft; [clear] removes a profile's rows
/// outright (account wipe). The drift implementation lives in
/// `infrastructure/drift/`.
abstract interface class GrowthLogDataSource
    implements
        ProfileDataSource<GrowthEntryId, GrowthEntry>,
        WatchableScopedDataSource<GrowthEntryId, GrowthEntry, HealthProfileId> {}
