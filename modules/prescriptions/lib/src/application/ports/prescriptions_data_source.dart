import 'package:core/core.dart';

import '../../domain/aggregates/prescription.dart';
import '../../domain/value_objects/ids.dart';

/// Persistence port for prescriptions. PHI, on-device only.
///
/// Application and presentation code depends on this, never on
/// `DriftPrescriptionsDataSource` — the storage engine is an infrastructure
/// detail bound at the composition root by `prescriptionsDataSourceProvider`.
///
/// Scope semantics are core's [UserDataSource] ones: partitioned by account,
/// `scope == null` resolving the ACTIVE user, so callers never pass an id
/// around. Every implementation must filter reads AND writes on that user.
abstract class PrescriptionsDataSource extends UserDataSource<PrescriptionId, Prescription>
    implements WatchableScopedDataSource<PrescriptionId, Prescription, UserId> {}
