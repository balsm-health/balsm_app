import 'package:core/core.dart';

import '../../domain/aggregates/pregnancy.dart';
import '../ports/pregnancies_data_source.dart';
import '../ports/pregnancy_babies_port.dart';

/// Re-reads [p]'s babies and stores the pregnancy closed when none is still
/// followed (`Pregnancy.settle`). Returns the pregnancy as it now stands.
/// Shared by the use cases that change a baby's status.
Future<Pregnancy> settlePregnancy(
  Pregnancy p, {
  required PregnanciesDataSource pregnancies,
  required PregnancyBabiesPort babies,
  required DateTime now,
}) async {
  final settled = p.settle(await babies.listBabies(p.id), now);
  if (!identical(settled, p)) await pregnancies.put(settled.id, settled, scope: settled.motherId);
  return settled;
}

/// The active pregnancy [id] of [motherId], or a failure to return as is.
Future<AppResult<Pregnancy>> activePregnancy(
  PregnanciesDataSource pregnancies,
  PregnancyId id,
  HealthProfileId motherId,
) async {
  final p = await pregnancies.find(id, scope: motherId);
  if (p == null) return AppResult.failure(const NotFoundFailure());
  if (!p.isActive) return AppResult.failure(ValidationFailure(PregnancyRuleViolation.closed.name));
  return AppResult.success(p);
}
