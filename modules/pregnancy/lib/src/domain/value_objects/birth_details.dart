import 'package:core/core.dart';

import 'ids.dart';
import 'pregnancy_dates.dart';

/// What the birth form collects for one baby (design `MCBirthScreen`):
/// name, sex and date of birth are required, blood type optional. Sex is
/// first asked here. [keepItemIds] are the records about this baby that move
/// to the child's profile; the others are detached from the child and stay on
/// the pregnancy.
class BirthDetails {
  const BirthDetails({
    required this.babyId,
    required this.name,
    required this.sex,
    required this.dateOfBirth,
    this.bloodType,
    this.keepItemIds = const {},
  });

  static const maxNameLength = 60;

  final HealthProfileId babyId;
  final String name;
  final Sex? sex;
  final DateTime? dateOfBirth;
  final BloodType? bloodType;
  final Set<PregnancyItemId> keepItemIds;

  /// The child's relationship to the mother: a child, named son or daughter
  /// by [sex] — the same mapping as the family screens.
  Relationship get relationship => Relationship.child;

  /// Every rule this form breaks on [now] (empty = can be saved).
  List<BirthViolation> violations(DateTime now) {
    final n = name.trim();
    final dob = dateOfBirth;
    return [
      if (n.isEmpty) BirthViolation.nameRequired,
      if (n.length > maxNameLength) BirthViolation.nameTooLong,
      if (sex == null) BirthViolation.sexRequired,
      if (dob == null) BirthViolation.birthDateRequired,
      if (dob != null && PregnancyDates.day(dob).isAfter(PregnancyDates.day(now))) BirthViolation.birthDateInFuture,
    ];
  }
}

/// A broken [BirthDetails] rule; [name] is the machine-readable code.
enum BirthViolation { nameRequired, nameTooLong, sexRequired, birthDateRequired, birthDateInFuture }
