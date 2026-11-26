import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:material_ui/material_ui.dart' show DateUtils;
import 'package:medications/medications.dart';

import '../i18n/strings.i69n.dart';

/// One medication as typed into a form (prescriptions.jsx `MedRow` +
/// `AddMedSheet`'s "When do you take it?").
///
/// Shared by Add medication and Add prescription, so a med typed into either
/// lands in the Meds tab's daily list the same way. An immutable value: the
/// text fields' controllers live in `MedPlanCard`'s State and every edit makes
/// a new draft, so the save, the Save button and the tests read the same
/// state. On-device PHI only.
@immutable
class MedPlanDraft {
  MedPlanDraft({
    this.name = '',
    this.dose = '',
    this.notes = '',
    this.freqType = 'once',
    this.freqN = '2',
    this.freqUnit = 'hours',
    this.freqOther = '',
    this.durType = 'ongoing',
    this.durN = '',
    this.durUnit = 'days',
    this.durOther = '',
    this.evening = false,
    List<String>? times,
  })  : times = List.unmodifiable(times ?? suggestedTimes(2)),
        _from = null,
        _seededSchedule = null,
        _seededDuration = null;

  MedPlanDraft._({
    required this.name,
    required this.dose,
    required this.notes,
    required this.freqType,
    required this.freqN,
    required this.freqUnit,
    required this.freqOther,
    required this.durType,
    required this.durN,
    required this.durUnit,
    required this.durOther,
    required this.evening,
    required List<String> times,
    required Medication? from,
    required String? seededSchedule,
    required String? seededDuration,
  })  : times = List.unmodifiable(times),
        _from = from,
        _seededSchedule = seededSchedule,
        _seededDuration = seededDuration;

  /// A draft filled from [med], for Edit medication (prescriptions.jsx
  /// `AddMedSheet` with `initial`). [toMedication] then saves under the same
  /// id and keeps the start date, and a schedule or duration the patient left
  /// untouched is kept exactly as stored — even one the form cannot express.
  factory MedPlanDraft.fromMedication(Medication med) {
    final cfg = med.scheduleConfig;
    final first = cfg.times.firstOrNull ?? morningTime;
    final (freqType, freqN, freqUnit, freqOther, times) = switch (med.scheduleType) {
      _ when cfg.frequencyNote != null => ('other', '2', 'hours', cfg.frequencyNote ?? '', [first]),
      ScheduleType.once => ('once', '2', 'hours', '', [first]),
      ScheduleType.everyHours => ('every_x', '${cfg.interval ?? 1}', 'hours', '', [first]),
      ScheduleType.everyDays => ('every_x', '${cfg.interval ?? 1}', 'days', '', [first]),
      ScheduleType.daily || ScheduleType.weekly || ScheduleType.custom => (
          'per_day',
          '${cfg.times.length.clamp(1, 12)}',
          'hours',
          '',
          cfg.times.length > 1 ? [...cfg.times] : [first],
        ),
    };
    final end = med.endDate;
    final (durType, durN, durOther) = switch (cfg.durationKind) {
      DurationKind.period when end != null => (
          'period',
          '${DateUtils.dateOnly(end).difference(DateUtils.dateOnly(med.startDate)).inDays}',
          '',
        ),
      DurationKind.untilEmpty => ('until_empty', '', ''),
      DurationKind.other => ('other', '', cfg.durationNote ?? ''),
      _ => ('ongoing', '', ''),
    };
    final filled = MedPlanDraft(
      name: med.name,
      dose: med.doseAmount ?? '',
      notes: med.notes ?? '',
      freqType: freqType,
      freqN: freqN,
      freqUnit: freqUnit,
      freqOther: freqOther,
      durType: durType,
      durN: durN,
      durOther: durOther,
      evening: (int.tryParse(first.split(':').first) ?? 8) >= 12,
      times: times,
    );
    return filled._copy(from: med, seededSchedule: filled._scheduleKey, seededDuration: filled._durationKey);
  }

  final String name;
  final String dose;
  final String notes;

  /// `once` · `per_day` · `every_x` · `other` — the design's frequency ids.
  final String freqType;

  /// The count typed next to "per day" / "every".
  final String freqN;

  /// `hours` · `days`, for `every_x`.
  final String freqUnit;
  final String freqOther;

  /// `period` · `until_empty` · `ongoing` · `other`.
  final String durType;
  final String durN;

  /// `days` · `weeks` · `months`, for `period`.
  final String durUnit;
  final String durOther;

  /// Morning or evening, for a single daily dose. Mapped to [morningTime] /
  /// [eveningTime].
  final bool evening;

  /// Dose times for 2+ per day, or the first dose of "every X hours". Kept in
  /// step with the count by [synced]. Unmodifiable.
  final List<String> times;

  /// The medication being edited; null when adding.
  final Medication? _from;
  final String? _seededSchedule;
  final String? _seededDuration;

  static const morningTime = '08:00';
  static const eveningTime = '20:00';

  String get _scheduleKey => [freqType, freqN, freqUnit, freqOther, evening, ...times].join('|');
  String get _durationKey => [durType, durN, durUnit, durOther].join('|');

  MedPlanDraft _copy({
    String? name,
    String? dose,
    String? notes,
    String? freqType,
    String? freqN,
    String? freqUnit,
    String? freqOther,
    String? durType,
    String? durN,
    String? durUnit,
    String? durOther,
    bool? evening,
    List<String>? times,
    Medication? from,
    String? seededSchedule,
    String? seededDuration,
  }) =>
      MedPlanDraft._(
        name: name ?? this.name,
        dose: dose ?? this.dose,
        notes: notes ?? this.notes,
        freqType: freqType ?? this.freqType,
        freqN: freqN ?? this.freqN,
        freqUnit: freqUnit ?? this.freqUnit,
        freqOther: freqOther ?? this.freqOther,
        durType: durType ?? this.durType,
        durN: durN ?? this.durN,
        durUnit: durUnit ?? this.durUnit,
        durOther: durOther ?? this.durOther,
        evening: evening ?? this.evening,
        times: times ?? this.times,
        from: from ?? _from,
        seededSchedule: seededSchedule ?? _seededSchedule,
        seededDuration: seededDuration ?? _seededDuration,
      );

  /// This draft with the given fields changed. A frequency change is followed
  /// by [synced], so the dose times follow the new count.
  MedPlanDraft copyWith({
    String? name,
    String? dose,
    String? notes,
    String? freqType,
    String? freqN,
    String? freqUnit,
    String? freqOther,
    String? durType,
    String? durN,
    String? durUnit,
    String? durOther,
    bool? evening,
    List<String>? times,
  }) =>
      _copy(
        name: name,
        dose: dose,
        notes: notes,
        freqType: freqType,
        freqN: freqN,
        freqUnit: freqUnit,
        freqOther: freqOther,
        durType: durType,
        durN: durN,
        durUnit: durUnit,
        durOther: durOther,
        evening: evening,
        times: times,
      );

  /// Dose [index] moved to [time] (`HH:mm`).
  MedPlanDraft withTime(int index, String time) => _copy(times: [...times]..[index] = time);

  bool get isNamed => name.trim().isNotEmpty;

  int get _n => (int.tryParse(freqN) ?? 1).clamp(1, 99);

  int get perDay => _n.clamp(1, 12);

  /// Which timing control the form shows for the current frequency.
  MedTiming get timing => switch (freqType) {
        'per_day' when perDay > 1 => MedTiming.times,
        'every_x' when freqUnit == 'hours' => MedTiming.firstDose,
        _ => MedTiming.halfOfDay,
      };

  /// Re-suggests [times] when the dose count changes. A count the patient has
  /// already tuned by hand is left alone.
  MedPlanDraft synced() => switch (timing) {
        MedTiming.times when times.length != perDay => _copy(times: suggestedTimes(perDay)),
        MedTiming.firstDose when times.length != 1 => _copy(times: [times.firstOrNull ?? morningTime]),
        _ => this,
      };

  String get _halfOfDay => evening ? eveningTime : morningTime;

  /// The scheduled medication. It starts at midnight today, so a dose due
  /// earlier today is listed as Due rather than silently skipped.
  Medication toMedication(UserId userId, {DateTime? now}) {
    final from = _from;
    final today = from?.startDate ?? DateUtils.dateOnly(now ?? DateTime.now());
    final text = freqOther.trim();
    final (type, times, interval) = switch (freqType) {
      'once' => (ScheduleType.once, [_halfOfDay], null),
      'per_day' when perDay > 1 => (ScheduleType.daily, [...this.times], null),
      'every_x' when freqUnit == 'hours' => (ScheduleType.everyHours, [this.times.first], _n),
      'every_x' when _n > 1 => (ScheduleType.everyDays, [_halfOfDay], _n),
      _ => (ScheduleType.daily, [_halfOfDay], null),
    };
    final count = int.tryParse(durN) ?? 0;
    final period = durType == 'period' && count > 0;
    final durText = durOther.trim();
    // The stored medication whose schedule / duration the patient left as it
    // was; null when adding, or once they changed it.
    final keptSchedule = from != null && _scheduleKey == _seededSchedule ? from : null;
    final keptDuration = from != null && _durationKey == _seededDuration ? from : null;
    return Medication(
      id: from?.id ?? MedicationId.uuid(),
      userId: from?.userId ?? userId,
      name: name.trim(),
      doseAmount: dose.trim().isEmpty ? null : dose.trim(),
      scheduleType: keptSchedule?.scheduleType ?? type,
      scheduleConfig: ScheduleConfig(
        times: keptSchedule?.scheduleConfig.times ?? times,
        days: keptSchedule?.scheduleConfig.days,
        interval: keptSchedule == null ? interval : keptSchedule.scheduleConfig.interval,
        frequencyNote: keptSchedule == null
            ? (freqType == 'other' && text.isNotEmpty ? text : null)
            : keptSchedule.scheduleConfig.frequencyNote,
        durationKind: keptDuration?.scheduleConfig.durationKind ??
            switch (durType) {
              'period' when period => DurationKind.period,
              'until_empty' => DurationKind.untilEmpty,
              'other' => DurationKind.other,
              _ => DurationKind.ongoing,
            },
        durationNote: keptDuration == null
            ? (durType == 'other' && durText.isNotEmpty ? durText : null)
            : keptDuration.scheduleConfig.durationNote,
      ),
      startDate: today,
      endDate: keptDuration == null
          ? (period ? periodEnd(today, count, PeriodUnit.values.byName(durUnit)) : null)
          : keptDuration.endDate,
      isControlled: from?.isControlled ?? false,
      notes: notes.trim().isEmpty ? null : notes.trim(),
    );
  }

  /// "500 mg · 2×/day · 7 days" — the one-line summary a prescription keeps.
  String summary(MedsStrings m) {
    final freq = switch (freqType) {
      'once' => m.freq_once,
      'per_day' => m.freq_n_per_day('$perDay'),
      'every_x' => '${m.freq_every} $_n ${freqUnit == 'days' ? m.unit_days : m.unit_hours}',
      _ => freqOther.trim().isEmpty ? m.freq_other : freqOther.trim(),
    };
    final dur = switch (durType) {
      'until_empty' => m.dur_until_empty,
      'other' => durOther.trim().isEmpty ? null : durOther.trim(),
      'period' when durN.isNotEmpty =>
        '$durN ${switch (durUnit) { 'weeks' => m.unit_weeks, 'months' => m.unit_months, _ => m.unit_days }}',
      _ => null,
    };
    return [dose.trim(), freq, dur].where((p) => p != null && p.isNotEmpty).join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      other is MedPlanDraft &&
      other.name == name &&
      other.dose == dose &&
      other.notes == notes &&
      other.freqType == freqType &&
      other.freqN == freqN &&
      other.freqUnit == freqUnit &&
      other.freqOther == freqOther &&
      other.durType == durType &&
      other.durN == durN &&
      other.durUnit == durUnit &&
      other.durOther == durOther &&
      other.evening == evening &&
      listEquals(other.times, times) &&
      identical(other._from, _from) &&
      other._seededSchedule == _seededSchedule &&
      other._seededDuration == _seededDuration;

  @override
  int get hashCode => Object.hash(
        name,
        dose,
        notes,
        freqType,
        freqN,
        freqUnit,
        freqOther,
        durType,
        durN,
        durUnit,
        durOther,
        evening,
        Object.hashAll(times),
        _from,
        _seededSchedule,
        _seededDuration,
      );
}

enum MedTiming { halfOfDay, times, firstDose }

/// One Add/Edit medication form: `form` is a token the form's State creates
/// once, so two forms open at once never share a draft; `initial` is the
/// medication an edit opens on (null when adding).
typedef MedPlanKey = ({Object form, Medication? initial});

/// The Add/Edit medication draft. Auto-disposed: the PHI it holds leaves
/// memory when the sheet closes.
class MedPlanNotifier extends Notifier<MedPlanDraft> {
  MedPlanNotifier(this.args);
  final MedPlanKey args;

  @override
  MedPlanDraft build() => switch (args.initial) {
        final initial? => MedPlanDraft.fromMedication(initial),
        _ => MedPlanDraft(),
      };

  void update(MedPlanDraft next) {
    if (next != state) state = next;
  }
}

final NotifierProviderFamily<MedPlanNotifier, MedPlanDraft, MedPlanKey> medPlanDraftProvider =
    NotifierProvider.autoDispose.family<MedPlanNotifier, MedPlanDraft, MedPlanKey>(MedPlanNotifier.new);
