import 'package:core/core.dart';

import '../value_objects/growth_entry_id.dart';

/// One weight and/or height measurement of a person on a day — the growth
/// log the design keeps for a child (`MCGrowthScreen`: a manual list, no
/// charts). Partitioned by the person's health profile; the partition is the
/// data source's scope, not a field.
///
/// Rules ([violationsOf]): a day that is not after today, and at least one
/// of weight or height, each within [weightRangeKg] / [heightRangeCm].
///
/// PHI: on-device only, never logged.
class GrowthEntry {
  /// Rehydrates a stored entry. New entries go through [record], which
  /// enforces the rules.
  const GrowthEntry({
    required this.id,
    required this.measuredOn,
    required this.createdAt,
    this.weightKg,
    this.heightCm,
  });

  /// Plausible bounds for anyone from a premature newborn to an adult; they
  /// catch a slipped decimal point, they are not clinical limits.
  static const weightRangeKg = (min: 0.2, max: 300.0);
  static const heightRangeCm = (min: 20.0, max: 250.0);

  final GrowthEntryId id;

  /// The day it was measured (a calendar day, UTC midnight).
  final DateTime measuredOn;

  final double? weightKg;
  final double? heightCm;
  final DateTime createdAt;

  /// Every rule the given values break as of [now] (empty = can be saved).
  static List<GrowthViolation> violationsOf({
    required DateTime? measuredOn,
    required double? weightKg,
    required double? heightCm,
    required DateTime now,
  }) {
    final v = <GrowthViolation>[];
    if (measuredOn == null) {
      v.add(GrowthViolation.measuredOnRequired);
    } else if (_day(measuredOn).isAfter(_day(now))) {
      v.add(GrowthViolation.measuredInFuture);
    }
    if (weightKg == null && heightCm == null) v.add(GrowthViolation.measurementRequired);
    if (weightKg != null && (weightKg < weightRangeKg.min || weightKg > weightRangeKg.max)) {
      v.add(GrowthViolation.weightOutOfRange);
    }
    if (heightCm != null && (heightCm < heightRangeCm.min || heightCm > heightRangeCm.max)) {
      v.add(GrowthViolation.heightOutOfRange);
    }
    return v;
  }

  /// A new entry from the growth form; or a [ValidationFailure] whose message
  /// lists every broken rule's code, comma-separated.
  static AppResult<GrowthEntry> record({
    required DateTime? measuredOn,
    required double? weightKg,
    required double? heightCm,
    required DateTime now,
    GrowthEntryId? id,
  }) {
    final broken = violationsOf(measuredOn: measuredOn, weightKg: weightKg, heightCm: heightCm, now: now);
    if (broken.isNotEmpty) return AppResult.failure(ValidationFailure(broken.map((b) => b.name).join(',')));
    return AppResult.success(GrowthEntry(
      id: id ?? GrowthEntryId.uuid(),
      measuredOn: _day(measuredOn!),
      weightKg: weightKg,
      heightCm: heightCm,
      createdAt: now.toUtc(),
    ));
  }

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
}

/// A broken [GrowthEntry] rule; [name] is the machine-readable code.
enum GrowthViolation {
  measuredOnRequired,
  measuredInFuture,
  measurementRequired,
  weightOutOfRange,
  heightOutOfRange,
}
