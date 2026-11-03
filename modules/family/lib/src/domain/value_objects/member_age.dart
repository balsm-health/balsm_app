/// Completed years and months between a date of birth and a day (the
/// design's `mcAgeYM`). Calendar arithmetic only — time of day is ignored.
class MemberAge {
  const MemberAge(this.years, this.months);

  /// Age on [on] of someone born on [dateOfBirth]. A birth date after [on]
  /// reads as zero.
  factory MemberAge.between(DateTime dateOfBirth, DateTime on) {
    var total = (on.year - dateOfBirth.year) * 12 + (on.month - dateOfBirth.month);
    if (on.day < dateOfBirth.day) total--;
    if (total < 0) total = 0;
    return MemberAge(total ~/ 12, total % 12);
  }

  /// Age of majority: from here a member is an adult whose consent the
  /// account holder confirms before managing their profile.
  static const adultYears = 18;

  final int years;
  final int months;

  bool get isAdult => years >= adultYears;

  @override
  bool operator ==(Object other) => other is MemberAge && other.years == years && other.months == months;

  @override
  int get hashCode => Object.hash(years, months);

  @override
  String toString() => 'MemberAge($years y $months m)';
}
