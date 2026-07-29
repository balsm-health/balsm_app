import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dose_event.dart';
import '../../infrastructure/drift/missed_dose_detector.dart';

/// Thin application wrapper around [MissedDoseDetector] for foreground hooks.
class NotifyMissedDosesUseCase {
  NotifyMissedDosesUseCase({required this.detector});

  final MissedDoseDetector detector;

  /// Runs missed-dose detection for [userId]; returns newly recorded misses.
  Future<List<DoseEvent>> call(UserId userId) => detector.detectMissed(userId);
}

final notifyMissedDosesUseCaseProvider = Provider<NotifyMissedDosesUseCase>((ref) {
  return NotifyMissedDosesUseCase(
    detector: ref.watch(missedDoseDetectorProvider),
  );
});
