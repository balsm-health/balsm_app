import 'package:collection/collection.dart' show IterableExtension, MapEquality, SetEquality;
import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:medications/medications.dart';
import 'package:self_report/self_report.dart';

import 'metric_drafts.dart';

/// What the full check-in holds while the patient steps through it: each
/// metric step's capture, the steps marked "I didn't measure this today", and
/// the medication marks. PHI — never log these values.
///
/// The rules (a skipped step discards what was typed, what counts as input,
/// how the steps merge into one check-in) are pure transitions here, so they
/// are unit-tested without the wizard.
@immutable
class CheckInDraft {
  CheckInDraft({
    Map<String, MetricLogCapture> captures = const {},
    Map<String, bool> valid = const {},
    Set<String> skipped = const {},
    Map<String, DoseOutcome> medMarks = const {},
  })  : captures = Map.unmodifiable(captures),
        valid = Map.unmodifiable(valid),
        skipped = Set.unmodifiable(skipped),
        medMarks = Map.unmodifiable(medMarks);

  /// Each metric step's capture, by step id, in the order first reported.
  final Map<String, MetricLogCapture> captures;

  /// Whether each step's capture is complete, by step id.
  final Map<String, bool> valid;

  /// Steps marked "I didn't measure this today" (`SkipRow`).
  final Set<String> skipped;

  /// Medication marks by medication id; an unmarked medication is absent.
  final Map<String, DoseOutcome> medMarks;

  CheckInDraft _copy({
    Map<String, MetricLogCapture>? captures,
    Map<String, bool>? valid,
    Set<String>? skipped,
    Map<String, DoseOutcome>? medMarks,
  }) =>
      CheckInDraft(
        captures: captures ?? this.captures,
        valid: valid ?? this.valid,
        skipped: skipped ?? this.skipped,
        medMarks: medMarks ?? this.medMarks,
      );

  /// Step [id] reported [c]. A skipped step keeps nothing.
  CheckInDraft capture(String id, MetricLogCapture c, {required bool valid}) =>
      skipped.contains(id) ? this : _copy(captures: {...captures, id: c}, valid: {...this.valid, id: valid});

  /// Skipping discards anything already typed: a skipped reading must not
  /// reach the check-in or the summary.
  CheckInDraft toggleSkip(String id) {
    if (skipped.contains(id)) return _copy(skipped: skipped.difference({id}));
    return _copy(
      skipped: {...skipped, id},
      captures: Map.of(captures)..remove(id),
      valid: Map.of(valid)..remove(id),
    );
  }

  /// Taken, or back to unmarked when it already was.
  CheckInDraft toggleTaken(String medId) => medMarks[medId] == DoseOutcome.taken
      ? _copy(medMarks: Map.of(medMarks)..remove(medId))
      : _copy(medMarks: {...medMarks, medId: DoseOutcome.taken});

  CheckInDraft markSkipped(String medId) => _copy(medMarks: {...medMarks, medId: DoseOutcome.skipped});

  /// Whether Next is open on step [stepId]: the meds step and a skipped step
  /// never block it.
  bool canAdvance(String stepId) => stepId == kMedsCheckInStepId || skipped.contains(stepId) || valid[stepId] == true;

  /// Anything entered that leaving would throw away.
  bool get hasInput => captures.isNotEmpty || medMarks.isNotEmpty;

  /// Every step's vitals in one, later steps winning a field both carry.
  Vitals mergedVitals(List<String> steps) {
    var out = Vitals.empty;
    for (final id in steps) {
      final v = captures[id]?.vitals;
      if (v == null || v.isEmpty) continue;
      out = Vitals(
        systolic: v.systolic ?? out.systolic,
        diastolic: v.diastolic ?? out.diastolic,
        heartRate: v.heartRate ?? out.heartRate,
        temperature: v.temperature ?? out.temperature,
        weightKg: v.weightKg ?? out.weightKg,
        spo2: v.spo2 ?? out.spo2,
        glucoseFasting: v.glucoseFasting ?? out.glucoseFasting,
        glucosePostMeal: v.glucosePostMeal ?? out.glucosePostMeal,
        glucoseRandom: v.glucoseRandom ?? out.glucoseRandom,
      );
    }
    return out;
  }

  /// The first photo any step attached.
  List<int>? get photo => captures.values.map((c) => c.photoBytes).whereType<List<int>>().firstOrNull;

  /// The steps merged into one check-in: the first mood, the worst pain, every
  /// site, symptom and detail, the notes one per line, the first step's time.
  CheckIn toCheckIn({
    required CheckInId id,
    required HealthProfileId profile,
    required List<String> steps,
    required DateTime now,
    String? photoRecordId,
  }) {
    Mood? mood;
    var painLevel = PainLevel.none;
    final painSites = <PainSite>{};
    final symptoms = <SymptomId>{};
    final symptomDetails = <SymptomId, SymptomDetail>{};
    final notes = <String>[];
    for (final stepId in steps) {
      if (stepId == kMedsCheckInStepId) continue;
      final c = captures[stepId];
      if (c == null) continue;
      mood ??= c.mood;
      if (c.painLevel.value > painLevel.value) painLevel = c.painLevel;
      painSites.addAll(c.painSites);
      symptoms.addAll(c.symptoms);
      symptomDetails.addAll(c.symptomDetails);
      final n = c.note?.trim();
      if (n != null && n.isNotEmpty) notes.add(n);
    }
    return CheckIn(
      id: id,
      healthProfileId: profile,
      recordedAt: captures.values.map((c) => c.when).whereType<DateTime>().firstOrNull ?? now,
      mood: mood,
      painLevel: painLevel,
      painSites: painSites,
      symptoms: symptoms,
      symptomDetails: symptomDetails,
      vitals: mergedVitals(steps),
      note: notes.isEmpty ? null : notes.join('\n'),
      photoRecordId: photoRecordId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CheckInDraft &&
      const MapEquality<String, MetricLogCapture>().equals(other.captures, captures) &&
      const MapEquality<String, bool>().equals(other.valid, valid) &&
      const SetEquality<String>().equals(other.skipped, skipped) &&
      const MapEquality<String, DoseOutcome>().equals(other.medMarks, medMarks);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(captures.entries.map((e) => Object.hash(e.key, e.value))),
        Object.hashAllUnordered(valid.entries.map((e) => Object.hash(e.key, e.value))),
        Object.hashAllUnordered(skipped),
        Object.hashAllUnordered(medMarks.entries.map((e) => Object.hash(e.key, e.value))),
      );
}

class CheckInDraftNotifier extends Notifier<CheckInDraft> {
  CheckInDraftNotifier(this.form);

  /// A token the check-in's State creates once, so two check-ins never share.
  final Object form;

  @override
  CheckInDraft build() => CheckInDraft();

  void capture(String id, MetricLogCapture c, {required bool valid}) => state = state.capture(id, c, valid: valid);
  void toggleSkip(String id) => state = state.toggleSkip(id);
  void toggleTaken(String medId) => state = state.toggleTaken(medId);
  void markSkipped(String medId) => state = state.markSkipped(medId);
}

/// Auto-disposing: the draft leaves memory with the check-in.
final NotifierProviderFamily<CheckInDraftNotifier, CheckInDraft, Object> checkInDraftProvider =
    NotifierProvider.autoDispose.family<CheckInDraftNotifier, CheckInDraft, Object>(CheckInDraftNotifier.new);
