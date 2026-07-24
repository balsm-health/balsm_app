import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aggregates/check_in.dart';
import '../../domain/events/check_in_saved.dart';
import '../ports/check_ins_data_source.dart';
import '../../infrastructure/drift/drift_check_ins_data_source.dart';

/// Persists a self-report check-in on-device and announces it.
///
/// Focused on the check-in itself: medication adherence and any photo are
/// handled by their owning modules at the call site (the flow calls
/// `recordDoseOutcomeUseCase` and the records vault directly), so this use
/// case never duplicates that data.
class SaveCheckInUseCase {
  SaveCheckInUseCase({required this.dao, required this.bus});

  final CheckInsDataSource dao;
  final EventBus bus;

  Future<void> call(CheckIn checkIn) async {
    await dao.put(checkIn.id, checkIn);
    bus.publish(CheckInSaved(
      checkInId: checkIn.id,
      occurredAt: DateTime.now(),
    ));
  }
}

final saveCheckInUseCaseProvider = Provider<SaveCheckInUseCase>(
  (ref) => SaveCheckInUseCase(
    dao: ref.watch(checkInsDataSourceProvider),
    bus: ref.watch(eventBusProvider),
  ),
);
