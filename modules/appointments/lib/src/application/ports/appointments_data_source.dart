import 'package:core/core.dart';

import '../../domain/aggregates/appointment.dart';
import '../../domain/value_objects/ids.dart';

/// Persistence port for appointments. PHI, on-device only.
///
/// Application and presentation code depends on this, never on
/// `DriftAppointmentsDataSource` — the storage engine is an infrastructure
/// detail bound at the composition root by `appointmentsDataSourceProvider`.
///
/// Scope semantics are core's [UserDataSource] ones: partitioned by account,
/// `scope == null` resolving the ACTIVE user, so callers never pass an id
/// around. Every implementation must filter reads AND writes on that user.
abstract class AppointmentsDataSource extends UserDataSource<AppointmentId, Appointment>
    implements WatchableScopedDataSource<AppointmentId, Appointment, UserId> {}
