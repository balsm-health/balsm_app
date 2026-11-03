import 'package:core/core.dart';

import '../value_objects/ids.dart';
import '../value_objects/pregnancy_dates.dart';
import '../value_objects/pregnancy_enums.dart';

/// Something recorded during a pregnancy (design `MCPregAddScreen`): about
/// the mother herself or about one or more babies; a scan, measurements, or a
/// test/document. Values are kept exactly as entered — Balsm doesn't
/// interpret them. PHI, on-device only; soft-deleted only.
class PregnancyItem {
  const PregnancyItem({
    required this.id,
    required this.pregnancyId,
    required this.about,
    required this.babyIds,
    required this.kind,
    required this.recordedOn,
    required this.createdAt,
    this.title,
    this.fetalHeartRateBpm,
    this.estimatedFetalWeightG,
    this.otherLabel,
    this.otherValue,
    this.attachmentRef,
  });

  static const maxTitleLength = 120;
  static const maxOtherLength = 60;

  /// Input bounds for the two numbers (typing slips, not clinical ranges).
  static const maxHeartRateBpm = 300;
  static const maxWeightG = 10000;

  /// A new item, or a [ValidationFailure] naming every broken rule (codes
  /// from [PregnancyItemViolation], comma-separated). Fields that do not
  /// belong to [kind] are dropped: measurements only on a measure, a file
  /// only on a scan or document.
  static AppResult<PregnancyItem> create({
    required PregnancyItemId id,
    required PregnancyId pregnancyId,
    required ItemAbout about,
    required List<HealthProfileId> babyIds,
    required ItemKind kind,
    required DateTime recordedOn,
    required DateTime now,
    String? title,
    int? fetalHeartRateBpm,
    int? estimatedFetalWeightG,
    String? otherLabel,
    String? otherValue,
    String? attachmentRef,
  }) {
    final measure = kind == ItemKind.measure;
    final item = PregnancyItem(
      id: id,
      pregnancyId: pregnancyId,
      about: about,
      babyIds: about == ItemAbout.me ? const [] : babyIds.toSet().toList(),
      kind: kind,
      recordedOn: PregnancyDates.day(recordedOn),
      createdAt: now,
      title: _clean(title),
      fetalHeartRateBpm: measure ? fetalHeartRateBpm : null,
      estimatedFetalWeightG: measure ? estimatedFetalWeightG : null,
      otherLabel: measure ? _clean(otherLabel) : null,
      otherValue: measure ? _clean(otherValue) : null,
      attachmentRef: measure ? null : _clean(attachmentRef),
    );
    final v = <PregnancyItemViolation>[
      if (about == ItemAbout.me && babyIds.isNotEmpty) PregnancyItemViolation.babiesOnMe,
      if (about == ItemAbout.baby && item.babyIds.isEmpty) PregnancyItemViolation.babyRequired,
      if (measure && (about != ItemAbout.baby || item.babyIds.length != 1)) PregnancyItemViolation.measureOneBaby,
      if (measure && !item.hasMeasurement) PregnancyItemViolation.measurementRequired,
      if (measure && (item.otherLabel == null) != (item.otherValue == null)) PregnancyItemViolation.otherIncomplete,
      if (!measure && item.title == null && item.attachmentRef == null) PregnancyItemViolation.titleOrFileRequired,
      if ((item.title?.length ?? 0) > maxTitleLength) PregnancyItemViolation.textTooLong,
      if ((item.otherLabel?.length ?? 0) > maxOtherLength || (item.otherValue?.length ?? 0) > maxOtherLength)
        PregnancyItemViolation.textTooLong,
      if (_outOfRange(item.fetalHeartRateBpm, maxHeartRateBpm)) PregnancyItemViolation.heartRateOutOfRange,
      if (_outOfRange(item.estimatedFetalWeightG, maxWeightG)) PregnancyItemViolation.weightOutOfRange,
      if (item.recordedOn.isAfter(PregnancyDates.day(now))) PregnancyItemViolation.dateInFuture,
    ];
    if (v.isNotEmpty) return AppResult.failure(ValidationFailure(v.map((e) => e.name).toSet().join(',')));
    return AppResult.success(item);
  }

  final PregnancyItemId id;
  final PregnancyId pregnancyId;
  final ItemAbout about;

  /// The babies (their profile ids) the item is about; empty when about me.
  /// More than one = a shared report.
  final List<HealthProfileId> babyIds;
  final ItemKind kind;

  /// Calendar day of the scan, visit or test.
  final DateTime recordedOn;
  final DateTime createdAt;
  final String? title;
  final int? fetalHeartRateBpm;
  final int? estimatedFetalWeightG;

  /// A further measurement, label and value as written ("Femur length", "44 mm").
  final String? otherLabel;
  final String? otherValue;

  /// Vault locator of the attached file (bytes live encrypted in the user
  /// file store, never in the database).
  final String? attachmentRef;

  bool get hasMeasurement =>
      fetalHeartRateBpm != null || estimatedFetalWeightG != null || (otherLabel != null && otherValue != null);

  /// About [babyId] (alone or shared).
  bool isAbout(HealthProfileId babyId) => about == ItemAbout.baby && babyIds.contains(babyId);

  bool get isShared => babyIds.length > 1;

  static bool _outOfRange(int? v, int max) => v != null && (v < 1 || v > max);

  static String? _clean(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
}

/// A broken [PregnancyItem] rule; [name] is the machine-readable code.
enum PregnancyItemViolation {
  babyRequired,
  babiesOnMe,

  /// Measurements are recorded for one baby at a time.
  measureOneBaby,
  measurementRequired,
  otherIncomplete,
  titleOrFileRequired,
  textTooLong,
  heartRateOutOfRange,
  weightOutOfRange,
  dateInFuture,
}
