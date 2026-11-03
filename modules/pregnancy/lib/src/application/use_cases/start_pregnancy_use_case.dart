import 'package:core/core.dart';

import '../../domain/aggregates/pregnancy.dart';
import '../ports/pregnancies_data_source.dart';
import '../ports/pregnancy_babies_port.dart';

/// Starts tracking a pregnancy on the mother's own profile (design
/// `MCPregStartScreen`) with [babyCount] babies, each its own prenatal
/// profile ("Baby", or "Baby A", "Baby B"…). Refused while another pregnancy
/// is being tracked on that profile.
class StartPregnancyUseCase {
  const StartPregnancyUseCase({required PregnanciesDataSource pregnancies, required PregnancyBabiesPort babies})
      : _pregnancies = pregnancies,
        _babies = babies;

  final PregnanciesDataSource _pregnancies;
  final PregnancyBabiesPort _babies;

  Future<AppResult<Pregnancy>> call({
    required HealthProfileId motherId,
    required DateTime dueDate,
    required int babyCount,
    required DateTime now,
    String? obName,
    String? obPhone,
  }) async {
    if (babyCount < 1 || babyCount > Pregnancy.maxBabies) {
      return AppResult.failure(ValidationFailure(PregnancyRuleViolation.babyCount.name));
    }
    if (await _pregnancies.findActive(scope: motherId) != null) {
      return AppResult.failure(ValidationFailure(PregnancyRuleViolation.alreadyTracking.name));
    }
    final started = Pregnancy.start(
      id: PregnancyId.uuid(),
      motherId: motherId,
      dueDate: dueDate,
      now: now,
      obName: obName,
      obPhone: obPhone,
    );
    if (started.isFailure) return started;
    final p = started.value;
    await _pregnancies.put(p.id, p, scope: motherId);
    for (var i = 1; i <= babyCount; i++) {
      final added = await _babies.addBaby(p.id, sequence: i, now: now);
      if (added.isFailure) return AppResult.failure(added.error);
    }
    return AppResult.success(p);
  }
}
