import 'package:core/core.dart';

import '../value_objects/member_age.dart';
import '../value_objects/member_tone.dart';

/// A member profile as the family screens see it: who they are, not their
/// health data. Read model of the Personal Health profile the profile module
/// owns; built by the app shell's adapter behind `FamilyMembersPort`.
///
/// PHI (name, date of birth, sex): on-device only, never logged.
class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.kind,
    required this.displayName,
    this.dateOfBirth,
    this.sex,
    this.relationship,
    this.groupId,
    this.tone,
    this.bloodType,
    this.status = ProfileStatus.active,
  });

  final HealthProfileId id;

  /// [ProfileKind.dependent] for someone the account holder manages;
  /// [ProfileKind.prenatal] for a baby before birth (the pregnancy screens).
  final ProfileKind kind;

  final String displayName;
  final DateTime? dateOfBirth;
  final Sex? sex;
  final Relationship? relationship;
  final MemberGroupId? groupId;
  final MemberTone? tone;

  /// Blood type from the member's health profile, for the member home head
  /// and the emergency card tile.
  final BloodType? bloodType;

  final ProfileStatus status;

  /// The first word of the name — the design's `short`.
  String get shortName {
    final trimmed = displayName.trim();
    final space = trimmed.indexOf(' ');
    return space < 0 ? trimmed : trimmed.substring(0, space);
  }

  /// Age on [now]; null without a date of birth.
  MemberAge? ageOn(DateTime now) => dateOfBirth == null ? null : MemberAge.between(dateOfBirth!, now);

  /// Under 18 on [now] — the tiles only a child gets (vaccinations, growth)
  /// key off this. Unknown age is not a child.
  bool isChildOn(DateTime now) {
    final age = ageOn(now);
    return age != null && !age.isAdult;
  }
}
