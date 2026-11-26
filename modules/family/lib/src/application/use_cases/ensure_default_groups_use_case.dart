import 'package:core/core.dart';

import '../../domain/aggregates/member_group.dart';
import '../ports/member_groups_data_source.dart';

/// Creates the default groups ("My family", "Neighbours") for an account the
/// first time its groups are read. A no-op once any default group exists, so
/// it is safe to call on every read.
class EnsureDefaultGroupsUseCase {
  const EnsureDefaultGroupsUseCase(this._groups);

  final MemberGroupsDataSource _groups;

  Future<void> call(UserId userId, {required DateTime now}) async {
    final existing = await _groups.findAll(scope: userId);
    if (existing.any((g) => g.isDefault)) return;
    await _groups.putBulk({for (final g in MemberGroup.defaults(userId, now)) g.id: g}, scope: userId);
  }
}
