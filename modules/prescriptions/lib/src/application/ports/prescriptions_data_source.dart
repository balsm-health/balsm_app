import 'package:core/core.dart';

import '../../domain/aggregates/prescription.dart';
import '../../domain/value_objects/ids.dart';

/// Persistence port for prescriptions. PHI, on-device only.
///
/// Application and presentation code depends on this, never on
/// `DriftPrescriptionsDataSource` — the storage engine is an infrastructure
/// detail bound at the composition root by `prescriptionsDataSourceProvider`.
///
/// Scope semantics are core's [ProfileDataSource] ones: partitioned by the
/// PERSON the prescription is for (health profile), `scope == null`
/// resolving the ACTIVE profile (`currentProfileIdProvider`), so callers never
/// pass an id around and a child's prescriptions never mix with the parent's.
/// Every implementation must filter reads AND writes on that profile; the
/// owning account stays on the aggregate as `Prescription.userId`.
abstract class PrescriptionsDataSource extends ProfileDataSource<PrescriptionId, Prescription>
    implements WatchableScopedDataSource<PrescriptionId, Prescription, HealthProfileId> {}
