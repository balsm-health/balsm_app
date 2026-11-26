import 'package:core/core.dart';

import '../value_objects/pregnancy_enums.dart';

/// A baby of a pregnancy, as the pregnancy screens see it: a read model of
/// the baby's own health profile (kind prenatal until birth, then dependent),
/// which the profile module owns. Built by the app shell's adapter behind
/// `PregnancyBabiesPort`.
///
/// There is no sex here on purpose: none is recorded before birth.
/// PHI (name, date of birth): on-device only, never logged.
class PregnancyBaby {
  const PregnancyBaby({
    required this.id,
    required this.pregnancyId,
    required this.sequence,
    required this.status,
    this.name,
    this.dateOfBirth,
    this.tone,
  });

  /// The baby's health profile — the same id before and after birth.
  final HealthProfileId id;
  final PregnancyId pregnancyId;

  /// Order among the pregnancy's babies, from 1 ("Baby A").
  final int sequence;

  final BabyStatus status;

  /// The name the mother chose, if any (optional before birth).
  final String? name;

  /// Set once born.
  final DateTime? dateOfBirth;

  /// Avatar colour key once born (presentation-only).
  final String? tone;

  bool get isActive => status == BabyStatus.active;
  bool get isBorn => status == BabyStatus.born;

  /// The name, when it has any text.
  String? get givenName {
    final n = name?.trim() ?? '';
    return n.isEmpty ? null : n;
  }
}

/// How a baby is called on screen (design `mcBabyLabel`): the name the
/// mother gave, otherwise "Baby" when the pregnancy has a single baby, or
/// "Baby A", "Baby B"… by position. The app renders it in the patient's
/// language.
sealed class BabyLabel {
  const BabyLabel();

  /// [baby]'s label among all of its pregnancy's [babies] — every baby
  /// counts, born or no longer followed ones too, so a label never shifts.
  factory BabyLabel.of(PregnancyBaby baby, List<PregnancyBaby> babies) {
    final name = baby.givenName;
    if (name != null) return NamedBaby(name);
    if (babies.length <= 1) return const OnlyBaby();
    final ordered = [...babies]..sort((a, b) => a.sequence.compareTo(b.sequence));
    final index = ordered.indexWhere((b) => b.id == baby.id);
    return LetteredBaby(index < 0 ? babies.length : index);
  }
}

/// The mother's own name for the baby.
class NamedBaby extends BabyLabel {
  const NamedBaby(this.name);
  final String name;
}

/// "Baby" — the pregnancy's only baby.
class OnlyBaby extends BabyLabel {
  const OnlyBaby();
}

/// "Baby A" (index 0), "Baby B" (1)…
class LetteredBaby extends BabyLabel {
  const LetteredBaby(this.index);
  final int index;
}
