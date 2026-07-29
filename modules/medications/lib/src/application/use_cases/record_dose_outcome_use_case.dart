import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dose_event.dart';
import '../../domain/value_objects/ids.dart';
import '../../domain/events/dose_corrected.dart';
import '../../domain/events/dose_skipped.dart';
import '../../domain/events/dose_snoozed.dart';
import '../../domain/events/dose_taken.dart';
import '../ports/medications_data_source.dart';
import '../../infrastructure/drift/drift_medications_data_source.dart';

/// Records a dose outcome by appending a new (immutable) dose event and
/// dispatching the matching domain event.
///
/// History is APPEND-ONLY — a correction is a new event referencing its parent,
/// never an update of the original.
class RecordDoseOutcomeUseCase {
  RecordDoseOutcomeUseCase({required this.dao, required this.bus});

  final MedicationsDataSource dao;
  final EventBus bus;

  Future<DoseEvent> call({
    required MedicationId medicationId,
    required DateTime scheduledAt,
    required DoseOutcome outcome,
    DateTime? snoozeUntil,
    DoseEventId? parentEventId,
  }) async {
    if (outcome == DoseOutcome.correction && parentEventId == null) {
      throw ArgumentError('correction needs parent');
    }
    if (outcome == DoseOutcome.snoozed && snoozeUntil == null) {
      throw ArgumentError('snoozed needs snoozeUntil');
    }

    final now = DateTime.now();
    final event = DoseEvent(
      id: DoseEventId.uuid(),
      medicationId: medicationId,
      scheduledAt: scheduledAt,
      recordedAt: now,
      outcome: outcome,
      parentEventId: parentEventId,
      snoozeUntil: snoozeUntil,
    );

    await dao.insertDoseEvent(event);
    bus.publish(_eventFor(event));
    return event;
  }

  AppEvent _eventFor(DoseEvent e) {
    switch (e.outcome) {
      case DoseOutcome.taken:
        return DoseTaken(
          doseEventId: e.id,
          medicationId: e.medicationId,
          scheduledAt: e.scheduledAt,
          recordedAt: e.recordedAt,
        );
      case DoseOutcome.skipped:
        return DoseSkipped(
          doseEventId: e.id,
          medicationId: e.medicationId,
          scheduledAt: e.scheduledAt,
          recordedAt: e.recordedAt,
        );
      case DoseOutcome.snoozed:
        return DoseSnoozed(
          doseEventId: e.id,
          medicationId: e.medicationId,
          scheduledAt: e.scheduledAt,
          recordedAt: e.recordedAt,
          snoozeUntil: e.snoozeUntil!,
        );
      case DoseOutcome.correction:
        return DoseCorrected(
          doseEventId: e.id,
          medicationId: e.medicationId,
          parentEventId: e.parentEventId!,
          newOutcome: e.outcome,
          scheduledAt: e.scheduledAt,
          recordedAt: e.recordedAt,
        );
      case DoseOutcome.missed:
        // Missed outcomes are produced by the detector, not user actions.
        throw ArgumentError(
          'missed outcomes are recorded by MissedDoseDetector',
        );
    }
  }
}

final recordDoseOutcomeUseCaseProvider = Provider<RecordDoseOutcomeUseCase>((ref) {
  return RecordDoseOutcomeUseCase(
    dao: ref.watch(medicationsDataSourceProvider),
    bus: ref.watch(eventBusProvider),
  );
});
