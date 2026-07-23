import 'package:core/core.dart';

import '../../domain/aggregates/medication.dart';
import '../../domain/entities/dose_event.dart';
import '../../domain/value_objects/ids.dart';

/// Persistence port for medications + their APPEND-ONLY dose history.
///
/// Pure contract — core's [ProfileDataSource] scope semantics (partitioned by
/// the person the medication belongs to; null scope = the active profile)
/// plus the dose-event operations. No storage technology leaks here: the
/// drift-backed implementation lives in `infrastructure/drift/` and is bound
/// via `medicationsDataSourceProvider`.
///
/// Contract deviations carried by every implementation, both deliberate:
/// - `delete`/`clear`/`clearAll` RETIRE (end-date) rather than erase: the
///   append-only dose history (FR-019) must outlive the medication row.
///   Physical PHI wipe is a database-level operation owned by the deletion
///   flow, not a row-level contract op.
abstract class MedicationsDataSource
    extends ProfileDataSource<MedicationId, Medication>
    implements
        WatchableScopedDataSource<MedicationId, Medication, HealthProfileId> {
  /// Appends a dose event. Never updates or deletes existing rows.
  Future<void> insertDoseEvent(DoseEvent e);

  /// Dose events for a medication, optionally bounded by [from]/[to]
  /// (inclusive of [from], exclusive of [to]) on the scheduled time.
  Future<List<DoseEvent>> getDoseEvents(
    MedicationId medicationId, {
    DateTime? from,
    DateTime? to,
  });

  /// Dose events recorded with the `missed` outcome scheduled before [cutoff].
  Future<List<DoseEvent>> getMissedEvents(DateTime cutoff);
}
