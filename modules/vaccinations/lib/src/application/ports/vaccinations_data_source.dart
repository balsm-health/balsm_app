import 'package:core/core.dart';

import '../../domain/aggregates/vaccination_record.dart';
import '../../domain/value_objects/ids.dart';

/// Persistence port for the vaccination log.
///
/// Scoped by the PERSON the doses were given to (`ProfileDataSource`,
/// partition = health profile): with no scope every read and write follows
/// core's active profile. Reads leave soft-deleted records out and list the
/// newest dose first. [delete] is soft; [clear] removes a profile's rows
/// outright (account wipe). The drift implementation lives in
/// `infrastructure/drift/`.
abstract interface class VaccinationsDataSource
    implements
        ProfileDataSource<VaccinationRecordId, VaccinationRecord>,
        WatchableScopedDataSource<VaccinationRecordId, VaccinationRecord, HealthProfileId> {}
