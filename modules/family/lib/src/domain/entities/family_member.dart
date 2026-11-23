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
  MemberAge? ageOn(DateTime now) =>
      switch (dateOfBirth) { final dateOfBirth? => MemberAge.between(dateOfBirth, now), _ => null };

  /// Under 18 on [now] — the tiles only a child gets (vaccinations, growth)
  /// key off this. Unknown age is not a child.
  bool isChildOn(DateTime now) {
    final age = ageOn(now);
    return age != null && !age.isAdult;
  }

  /// Ages between which pregnancy tracking is offered for a member.
  static const ({int max, int min}) pregnancyAgeYears = (min: 14, max: 55);

  /// Whether pregnancy can be tracked on this profile on [now]
  /// (mother-child.jsx `mcCanPreg`): a woman of childbearing age whose
  /// profile the account holder manages — an open dependent, female, aged
  /// [pregnancyAgeYears]. Unknown sex or age is not offered.
  bool canTrackPregnancyOn(DateTime now) {
    final age = ageOn(now);
    return kind == ProfileKind.dependent &&
        status == ProfileStatus.active &&
        sex == Sex.female &&
        age != null &&
        age.years >= pregnancyAgeYears.min &&
        age.years <= pregnancyAgeYears.max;
  }
}
