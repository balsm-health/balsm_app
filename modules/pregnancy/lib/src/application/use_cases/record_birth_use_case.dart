import 'package:core/core.dart';

import '../../domain/aggregates/pregnancy.dart';
import '../../domain/value_objects/birth_details.dart';
import '../ports/pregnancies_data_source.dart';
import '../ports/pregnancy_babies_port.dart';
import 'settle_pregnancy.dart';

/// A baby has arrived (design `MCBirthScreen`, one baby at a time): the
/// baby's prenatal profile becomes the child's — the **same** profile id —
/// with the name, sex, date of birth and blood type given. Records about this
/// baby that were not ticked to move are detached from the child and stay on
/// the pregnancy; nothing is copied. The pregnancy closes with outcome birth
/// once no baby is still followed.
class RecordBirthUseCase {
  const RecordBirthUseCase({required PregnanciesDataSource pregnancies, required PregnancyBabiesPort babies})
      : _pregnancies = pregnancies,
        _babies = babies;

  final PregnanciesDataSource _pregnancies;
  final PregnancyBabiesPort _babies;

  /// Returns the pregnancy as it now stands. A [ValidationFailure] carries
  /// the broken [BirthViolation] codes.
  Future<AppResult<Pregnancy>> call(
    PregnancyId id,
    BirthDetails details, {
    required HealthProfileId motherId,
    required DateTime now,
  }) async {
    final v = details.violations(now);
    if (v.isNotEmpty) return AppResult.failure(ValidationFailure(v.map((e) => e.name).join(',')));
    final p = await activePregnancy(_pregnancies, id, motherId);
    if (p.isFailure) return p;
    final babies = await _babies.listBabies(id);
    if (!babies.any((b) => b.id == details.babyId && b.isActive)) return AppResult.failure(const NotFoundFailure());

    final born = await _babies.recordBirth(details, now: now);
    if (born.isFailure) return AppResult.failure(born.error);
    final items = await _pregnancies.findItems(id, scope: motherId);
    final left = [
      for (final i in items)
        if (i.isAbout(details.babyId) && !details.keepItemIds.contains(i.id)) i.id
    ];
    await _pregnancies.detachItems(details.babyId, left, scope: motherId);
    return AppResult.success(await settlePregnancy(p.value, pregnancies: _pregnancies, babies: _babies, now: now));
  }
}
