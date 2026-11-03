import 'package:core/core.dart';

import '../entities/pregnancy_baby.dart';
import '../value_objects/pregnancy_dates.dart';
import '../value_objects/pregnancy_enums.dart';

/// The next antenatal visit: a calendar day, an optional time of day
/// (`HH:mm`, as entered) and the clinic.
class NextVisit {
  const NextVisit({required this.date, this.time, this.clinic});

  final DateTime date;
  final String? time;
  final String? clinic;
}

/// A pregnancy tracked on the account holder's own (self) profile — Personal
/// Health, PHI, on-device only.
///
/// Build one with [start]; change it with [withNextVisit], [end] and
/// [settle], which keep its rules. The babies are their own
/// prenatal profiles (`PregnancyBaby`), not part of this aggregate.
class Pregnancy {
  const Pregnancy({
    required this.id,
    required this.motherId,
    required this.dueDate,
    required this.createdAt,
    this.obName,
    this.obPhone,
    this.nextVisit,
    this.status = PregnancyStatus.active,
    this.closedOn,
  });

  /// Longest obstetrician name / phone / clinic text kept.
  static const maxTextLength = 80;

  /// The furthest a due date can be: a last period beginning today.
  static const maxDaysAhead = PregnancyDates.termDays;

  /// The longest a due date may already have passed when tracking starts.
  static const maxDaysPast = 42;

  /// Most babies one pregnancy can start with (the design's stepper).
  static const maxBabies = 8;

  /// A new active pregnancy for [motherId], or a [ValidationFailure] naming
  /// every broken rule (codes from [PregnancyRuleViolation], comma-separated).
  static AppResult<Pregnancy> start({
    required PregnancyId id,
    required HealthProfileId motherId,
    required DateTime dueDate,
    required DateTime now,
    String? obName,
    String? obPhone,
  }) {
    final p = Pregnancy(
      id: id,
      motherId: motherId,
      dueDate: PregnancyDates.day(dueDate),
      createdAt: now,
      obName: _clean(obName),
      obPhone: _clean(obPhone),
    );
    final v = p.violations(now);
    final left = PregnancyDates.daysBetween(now, dueDate);
    if (left > maxDaysAhead) v.add(PregnancyRuleViolation.dueDateTooFar);
    if (left < -maxDaysPast) v.add(PregnancyRuleViolation.dueDatePassed);
    return v.isEmpty ? AppResult.success(p) : AppResult.failure(_failure(v));
  }

  final PregnancyId id;

  /// The mother's (self) profile — the partition this pregnancy lives in.
  final HealthProfileId motherId;

  /// Estimated due date (calendar day).
  final DateTime dueDate;
  final String? obName;
  final String? obPhone;
  final NextVisit? nextVisit;
  final PregnancyStatus status;

  /// Calendar day the pregnancy closed; set exactly when it is not active.
  final DateTime? closedOn;
  final DateTime createdAt;

  bool get isActive => status == PregnancyStatus.active;

  /// Week, day, trimester and days left on [today].
  PregnancyInfo infoOn(DateTime today) => PregnancyInfo.on(dueDate, today);

  /// Every rule this pregnancy breaks (empty = valid). Text limits only; the
  /// due-date window applies when tracking starts.
  List<PregnancyRuleViolation> violations(DateTime now) => [
        if ((obName?.length ?? 0) > maxTextLength) PregnancyRuleViolation.textTooLong,
        if ((obPhone?.length ?? 0) > maxTextLength) PregnancyRuleViolation.textTooLong,
        if ((nextVisit?.clinic?.length ?? 0) > maxTextLength) PregnancyRuleViolation.textTooLong,
        if (isActive == (closedOn != null)) PregnancyRuleViolation.closedOnMismatch,
      ];

  /// The next antenatal visit set (or cleared with null). Refused once closed.
  AppResult<Pregnancy> withNextVisit(NextVisit? visit, {required DateTime now}) {
    if (!isActive) return AppResult.failure(ValidationFailure(PregnancyRuleViolation.closed.name));
    final next = _copy(
      nextVisit: visit == null
          ? null
          : NextVisit(date: PregnancyDates.day(visit.date), time: _clean(visit.time), clinic: _clean(visit.clinic)),
    );
    final v = next.violations(now);
    return v.isEmpty ? AppResult.success(next) : AppResult.failure(_failure(v));
  }

  /// Ends tracking on [on] — a loss, or the mother stopping. Outcome
  /// [PregnancyStatus.ended]; every record is kept. The caller closes the
  /// babies still followed.
  AppResult<Pregnancy> end(DateTime on) {
    if (!isActive) return AppResult.failure(ValidationFailure(PregnancyRuleViolation.closed.name));
    return AppResult.success(_copy(status: PregnancyStatus.ended, closedOn: PregnancyDates.day(on)));
  }

  /// Design `mcSettle`: once none of [babies] is still followed, the
  /// pregnancy closes on [on] — outcome [PregnancyStatus.birth] when any was
  /// born, otherwise [PregnancyStatus.ended]. Unchanged (this same object)
  /// while a baby is still active, or when already closed.
  Pregnancy settle(List<PregnancyBaby> babies, DateTime on) {
    if (!isActive || babies.any((b) => b.isActive)) return this;
    return _copy(
      status: babies.any((b) => b.isBorn) ? PregnancyStatus.birth : PregnancyStatus.ended,
      closedOn: PregnancyDates.day(on),
    );
  }

  Pregnancy _copy({Object? nextVisit = _keep, PregnancyStatus? status, DateTime? closedOn}) => Pregnancy(
        id: id,
        motherId: motherId,
        dueDate: dueDate,
        createdAt: createdAt,
        obName: obName,
        obPhone: obPhone,
        nextVisit: identical(nextVisit, _keep) ? this.nextVisit : nextVisit as NextVisit?,
        status: status ?? this.status,
        closedOn: closedOn ?? this.closedOn,
      );

  static const _keep = Object();

  static String? _clean(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  static ValidationFailure _failure(List<PregnancyRuleViolation> v) =>
      ValidationFailure(v.map((e) => e.name).toSet().join(','));
}

/// A broken pregnancy rule; [name] is the machine-readable code carried by
/// the [ValidationFailure] message.
enum PregnancyRuleViolation {
  /// The due date is more than a full term ahead (a last period in the future).
  dueDateTooFar,

  /// The due date passed more than [Pregnancy.maxDaysPast] days ago.
  dueDatePassed,
  textTooLong,

  /// `closedOn` must be set exactly when the pregnancy is closed.
  closedOnMismatch,

  /// The pregnancy is closed and can no longer change.
  closed,

  /// An active pregnancy is already being tracked on this profile.
  alreadyTracking,

  /// A pregnancy starts with 1 to [Pregnancy.maxBabies] babies.
  babyCount,
}
