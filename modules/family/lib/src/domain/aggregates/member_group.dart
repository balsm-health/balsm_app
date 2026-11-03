import 'package:core/core.dart';

import '../value_objects/default_group.dart';

/// A group the account holder files member profiles under — one of the
/// [DefaultGroup]s or one they named themselves. Soft-deleted only; a member
/// whose group is gone is shown under [DefaultGroup.family].
class MemberGroup {
  const MemberGroup({
    required this.id,
    required this.userId,
    required this.sort,
    required this.createdAt,
    this.defaultGroup,
    this.name,
  });

  /// Longest name a patient may give a group.
  static const maxNameLength = 40;

  /// The default groups for [userId], in their display order.
  static List<MemberGroup> defaults(UserId userId, DateTime now) => [
        for (final (i, g) in DefaultGroup.values.indexed)
          MemberGroup(id: MemberGroupId.uuid(), userId: userId, sort: i, createdAt: now, defaultGroup: g),
      ];

  /// A group the patient named, placed after [afterSort]; or a
  /// [ValidationFailure] (`groupNameRequired` / `groupNameTooLong`).
  static AppResult<MemberGroup> custom({
    required UserId userId,
    required String name,
    required int afterSort,
    required DateTime now,
    MemberGroupId? id,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return AppResult.failure(const ValidationFailure('groupNameRequired'));
    if (trimmed.length > maxNameLength) return AppResult.failure(const ValidationFailure('groupNameTooLong'));
    return AppResult.success(MemberGroup(
      id: id ?? MemberGroupId.uuid(),
      userId: userId,
      sort: afterSort + 1,
      createdAt: now,
      name: trimmed,
    ));
  }

  final MemberGroupId id;
  final UserId userId;

  /// Set on a default group; its name comes from the app's strings.
  final DefaultGroup? defaultGroup;

  /// The patient's own name for a group they added. Null on a default group.
  final String? name;

  /// Display order, ascending.
  final int sort;

  final DateTime createdAt;

  bool get isDefault => defaultGroup != null;
}
