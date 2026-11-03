import 'package:core/core.dart';

import '../../domain/aggregates/pregnancy.dart';
import '../../domain/entities/pregnancy_item.dart';
import '../../domain/value_objects/ids.dart';
import '../../domain/value_objects/pregnancy_enums.dart';
import '../ports/pregnancies_data_source.dart';
import '../ports/pregnancy_babies_port.dart';
import 'settle_pregnancy.dart';

/// What the mother records on an active pregnancy: an item about herself or
/// some of the babies still followed (design `MCPregAddScreen`), and the next
/// antenatal visit.
class PregnancyRecordsUseCase {
  const PregnancyRecordsUseCase({required PregnanciesDataSource pregnancies, required PregnancyBabiesPort babies})
      : _pregnancies = pregnancies,
        _babies = babies;

  final PregnanciesDataSource _pregnancies;
  final PregnancyBabiesPort _babies;

  /// Stores a new item. A [ValidationFailure] carries the broken
  /// [PregnancyItemViolation] codes; a baby that is not still followed is a
  /// [NotFoundFailure].
  Future<AppResult<PregnancyItem>> addItem({
    required PregnancyId pregnancyId,
    required HealthProfileId motherId,
    required ItemAbout about,
    required List<HealthProfileId> babyIds,
    required ItemKind kind,
    required DateTime recordedOn,
    required DateTime now,
    String? title,
    int? fetalHeartRateBpm,
    int? estimatedFetalWeightG,
    String? otherLabel,
    String? otherValue,
    String? attachmentRef,
  }) async {
    final built = PregnancyItem.create(
      id: PregnancyItemId.uuid(),
      pregnancyId: pregnancyId,
      about: about,
      babyIds: babyIds,
      kind: kind,
      recordedOn: recordedOn,
      now: now,
      title: title,
      fetalHeartRateBpm: fetalHeartRateBpm,
      estimatedFetalWeightG: estimatedFetalWeightG,
      otherLabel: otherLabel,
      otherValue: otherValue,
      attachmentRef: attachmentRef,
    );
    if (built.isFailure) return built;
    final p = await activePregnancy(_pregnancies, pregnancyId, motherId);
    if (p.isFailure) return AppResult.failure(p.error);
    final active = {
      for (final b in await _babies.listBabies(pregnancyId))
        if (b.isActive) b.id
    };
    if (!built.value.babyIds.every(active.contains)) return AppResult.failure(const NotFoundFailure());
    try {
      await _pregnancies.addItem(built.value, scope: motherId);
    } on StorageWriteException catch (e) {
      return AppResult.failure(StorageFailure(e.message));
    }
    return built;
  }

  /// Sets (or clears, with null) the next antenatal visit.
  Future<AppResult<Pregnancy>> setNextVisit(
    PregnancyId id,
    NextVisit? visit, {
    required HealthProfileId motherId,
    required DateTime now,
  }) async {
    final p = await activePregnancy(_pregnancies, id, motherId);
    if (p.isFailure) return p;
    final changed = p.value.withNextVisit(visit, now: now);
    if (changed.isFailure) return changed;
    await _pregnancies.put(id, changed.value, scope: motherId);
    return changed;
  }
}
