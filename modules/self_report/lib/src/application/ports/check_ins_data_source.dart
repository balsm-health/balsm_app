import 'package:core/core.dart';

import '../../domain/aggregates/check_in.dart';
import '../../domain/value_objects/ids.dart';

/// Persistence port for self-report check-ins.
///
/// Pure contract — core's [ProfileDataSource] scope semantics (partitioned by
/// the person the check-in is about; null scope = the active profile). No
/// storage technology leaks here; the drift implementation lives in
/// `infrastructure/drift/` and is bound via `checkInsDataSourceProvider`.
///
/// Check-ins are immutable journal entries: [put] inserts a new one; there is
/// no update path. Reads return newest-first.
abstract class CheckInsDataSource extends ProfileDataSource<CheckInId, CheckIn>
    implements WatchableScopedDataSource<CheckInId, CheckIn, HealthProfileId> {}
