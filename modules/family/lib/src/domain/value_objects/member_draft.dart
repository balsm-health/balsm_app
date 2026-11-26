import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable;

import 'member_age.dart';

/// What the add / edit member form collects (design `MCAddMemberScreen`):
/// relation, name, date of birth and sex are required; blood type is
/// optional. [violations] reports every missing or invalid field at once.
///
/// Value equality over every field: a form holds it in a provider, and
/// Riverpod 3 drops an update that is == to the last one.
@immutable
class MemberDraft {
  const MemberDraft({
    required this.displayName,
    required this.relationship,
    required this.dateOfBirth,
    required this.sex,
    this.bloodType,
    this.groupId,
    this.newGroupName,
  });

  /// Same limit as the profile aggregate's display name.
  static const maxNameLength = 60;

  final String displayName;
  final Relationship? relationship;
  final DateTime? dateOfBirth;
  final Sex? sex;
  final BloodType? bloodType;

  /// An existing group to file the member under.
  final MemberGroupId? groupId;

  /// A group to create and file the member under; wins over [groupId] when
  /// it has text. Blank means "no new group", as in the design.
  final String? newGroupName;

  bool get createsGroup => (newGroupName?.trim() ?? '').isNotEmpty;

  /// Every rule this draft breaks as of [now] (empty = can be saved).
  List<MemberDraftViolation> violations(DateTime now) {
    final v = <MemberDraftViolation>[];
    final name = displayName.trim();
    if (name.isEmpty) v.add(MemberDraftViolation.nameRequired);
    if (name.length > maxNameLength) v.add(MemberDraftViolation.nameTooLong);
    if (relationship == null) v.add(MemberDraftViolation.relationshipRequired);
    final dob = dateOfBirth;
    if (dob == null) {
      v.add(MemberDraftViolation.birthDateRequired);
    } else if (DateTime(dob.year, dob.month, dob.day).isAfter(DateTime(now.year, now.month, now.day))) {
      v.add(MemberDraftViolation.birthDateInFuture);
    }
    if (sex == null) v.add(MemberDraftViolation.sexRequired);
    return v;
  }

  /// An adult's health information belongs to them: the form asks the
  /// account holder to confirm the member's consent before saving.
  bool needsConsentOn(DateTime now) {
    final dob = dateOfBirth;
    return dob != null && MemberAge.between(dob, now).isAdult;
  }

  @override
  bool operator ==(Object other) =>
      other is MemberDraft &&
      other.displayName == displayName &&
      other.relationship == relationship &&
      other.dateOfBirth == dateOfBirth &&
      other.sex == sex &&
      other.bloodType == bloodType &&
      other.groupId == groupId &&
      other.newGroupName == newGroupName;

  @override
  int get hashCode => Object.hash(displayName, relationship, dateOfBirth, sex, bloodType, groupId, newGroupName);
}

/// A broken [MemberDraft] rule; [name] is the machine-readable code.
enum MemberDraftViolation {
  nameRequired,
  nameTooLong,
  relationshipRequired,
  birthDateRequired,
  birthDateInFuture,
  sexRequired,
}
