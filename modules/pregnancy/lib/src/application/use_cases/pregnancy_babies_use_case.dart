import 'package:core/core.dart';

import '../../domain/aggregates/pregnancy.dart';
import '../../domain/entities/pregnancy_baby.dart';
import '../ports/pregnancies_data_source.dart';
import '../ports/pregnancy_babies_port.dart';
import 'settle_pregnancy.dart';

/// The babies of an active pregnancy (design `MCPregScreen`): add one — for
/// example when a later scan shows twins — or stop following one. Stopping
/// the last baby still followed closes the pregnancy (`mcSettle`).
class PregnancyBabiesUseCase {
  const PregnancyBabiesUseCase({required PregnanciesDataSource pregnancies, required PregnancyBabiesPort babies})
      : _pregnancies = pregnancies,
        _babies = babies;

  final PregnanciesDataSource _pregnancies;
  final PregnancyBabiesPort _babies;

  /// A new baby after the last one of pregnancy [id].
  Future<AppResult<PregnancyBaby>> add(PregnancyId id,
      {required HealthProfileId motherId, required DateTime now}) async {
    final p = await activePregnancy(_pregnancies, id, motherId);
    if (p.isFailure) return AppResult.failure(p.error);
    final existing = await _babies.listBabies(id);
    final last = existing.fold<int>(0, (m, b) => b.sequence > m ? b.sequence : m);
    return _babies.addBaby(id, sequence: last + 1, now: now);
  }

  /// Stops following [babyId] of pregnancy [id]: that profile closes, its
  /// records stay. Returns the pregnancy as it now stands — closed when that
  /// was the last baby still followed.
  Future<AppResult<Pregnancy>> stopFollowing(
    PregnancyId id,
    HealthProfileId babyId, {
    required HealthProfileId motherId,
    required DateTime now,
  }) async {
    final p = await activePregnancy(_pregnancies, id, motherId);
    if (p.isFailure) return p;
    final babies = await _babies.listBabies(id);
    if (!babies.any((b) => b.id == babyId && b.isActive)) return AppResult.failure(const NotFoundFailure());
    final closed = await _babies.closeBaby(babyId, now: now);
    if (closed.isFailure) return AppResult.failure(closed.error);
    return AppResult.success(await settlePregnancy(p.value, pregnancies: _pregnancies, babies: _babies, now: now));
  }
}
