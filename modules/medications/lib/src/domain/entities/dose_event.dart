import '../value_objects/ids.dart';

/// Outcome recorded for a single scheduled dose.
///
/// [correction] amends a previously recorded outcome and must reference the
/// original event via [DoseEvent.parentEventId] (history stays append-only).
enum DoseOutcome { taken, skipped, snoozed, missed, correction }

/// A single immutable record in a medication's APPEND-ONLY dose history.
///
/// Dose events are never updated or deleted. To change an outcome, append a new
/// [DoseOutcome.correction] event that points at the original via
/// [parentEventId].
class DoseEvent {
  const DoseEvent({
    required this.id,
    required this.medicationId,
    required this.scheduledAt,
    required this.recordedAt,
    required this.outcome,
    this.parentEventId,
    this.snoozeUntil,
  });

  final DoseEventId id;
  final MedicationId medicationId;

  /// When this dose was scheduled to be taken.
  final DateTime scheduledAt;

  /// When the outcome was recorded by the user / system.
  final DateTime recordedAt;

  final DoseOutcome outcome;

  /// For [DoseOutcome.correction], the id of the event being corrected.
  final DoseEventId? parentEventId;

  /// For [DoseOutcome.snoozed], when the reminder should fire again.
  final DateTime? snoozeUntil;
}
