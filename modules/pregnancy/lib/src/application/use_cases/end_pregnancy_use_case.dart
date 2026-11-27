import 'package:core/core.dart';

import '../../domain/aggregates/pregnancy.dart';
import '../ports/pregnancies_data_source.dart';
import '../ports/pregnancy_babies_port.dart';
import 'settle_pregnancy.dart';

/// Ends tracking a pregnancy (design end sheet — a loss, or the mother
/// stopping): the pregnancy closes as ended and every baby still followed is
/// closed. Every record is kept on the device.
class EndPregnancyUseCase {
  const EndPregnancyUseCase({required PregnanciesDataSource pregnancies, required PregnancyBabiesPort babies})
      : _pregnancies = pregnancies,
        _babies = babies;

  final PregnanciesDataSource _pregnancies;
  final PregnancyBabiesPort _babies;

  Future<AppResult<Pregnancy>> call(PregnancyId id, {required HealthProfileId motherId, required DateTime now}) async {
    final p = await activePregnancy(_pregnancies, id, motherId);
    if (p.isFailure) return p;
    final ended = p.value.end(now);
    if (ended.isFailure) return ended;
    for (final b in await _babies.listBabies(id)) {
      if (!b.isActive) continue;
      final closed = await _babies.closeBaby(b.id, now: now);
      if (closed.isFailure) return AppResult.failure(closed.error);
    }
    await _pregnancies.put(id, ended.value, scope: motherId);
    return ended;
  }
}
