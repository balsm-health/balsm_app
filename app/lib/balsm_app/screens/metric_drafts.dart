import 'package:collection/collection.dart' show MapEquality, SetEquality;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:self_report/self_report.dart';

import '../widgets/photo_attach.dart';

/// What the vitals entry forms hold while a patient types — blood pressure,
/// glucose, weight, SpO₂ and pulse, plus the date and photo every form shares.
///
/// The rules for what a keypad press does live here as pure state transitions
/// (so they are unit-tested without a widget); each form watches one
/// auto-disposing provider, and the draft is gone when the form closes.

/// What a metric template currently holds. PHI — never log these values.
///
/// Equal only when every field is: Riverpod 3 filters provider updates with
/// `==`, so a capture that left out the time or the symptom details would hide
/// those edits from whoever watches it.
@immutable
class MetricLogCapture {
  const MetricLogCapture({
    this.summary = '',
    this.note,
    this.mood,
    this.painLevel = PainLevel.none,
    this.painSites = const {},
    this.symptoms = const {},
    this.symptomDetails = const {},
    this.vitals = Vitals.empty,
    this.when,
    this.photoBytes,
  });

  final String summary;
  final String? note;
  final Mood? mood;
  final PainLevel painLevel;
  final Set<PainSite> painSites;
  final Set<SymptomId> symptoms;

  /// Per-symptom observations (`quicklog.jsx` QuickSymptomDetail). Sparse.
  final Map<SymptomId, SymptomDetail> symptomDetails;

  final Vitals vitals;
  final DateTime? when;

  /// Local preview bytes for a note photo. Never log these.
  final List<int>? photoBytes;

  @override
  bool operator ==(Object other) =>
      other is MetricLogCapture &&
      other.summary == summary &&
      other.note == note &&
      other.mood == mood &&
      other.painLevel == painLevel &&
      other.vitals == vitals &&
      other.when == when &&
      // The photo by identity: a form keeps the one picked object until a new
      // pick replaces it, and comparing megabytes on every keypress buys nothing.
      identical(other.photoBytes, photoBytes) &&
      const SetEquality<PainSite>().equals(other.painSites, painSites) &&
      const SetEquality<SymptomId>().equals(other.symptoms, symptoms) &&
      const MapEquality<SymptomId, SymptomDetail>().equals(other.symptomDetails, symptomDetails);

  @override
  int get hashCode => Object.hash(
        summary,
        note,
        mood,
        painLevel,
        vitals,
        when,
        identityHashCode(photoBytes),
        Object.hashAllUnordered(painSites),
        Object.hashAllUnordered(symptoms),
        Object.hashAllUnordered(symptomDetails.entries.map((e) => Object.hash(e.key, e.value))),
      );
}

/// One form instance: `form` is a token the form's State creates once, so two
/// forms open at once never share a draft; `initial` is the stored reading an
/// edit opens on (null for a new entry).
typedef DraftKey = ({Object form, Vitals? initial});

/// Like [DraftKey], for the forms that edit more than vitals (mood, pain,
/// symptoms): `initial` is the whole stored entry the form opens on.
typedef CaptureDraftKey = ({Object form, MetricLogCapture? initial});

// ── Blood pressure ───────────────────────────────────────────

@immutable
class BpDraft {
  const BpDraft({this.sys = '', this.dia = '', this.onSys = true});

  factory BpDraft.from(Vitals? v) {
    final dia = v?.diastolic?.toString() ?? '';
    return BpDraft(sys: v?.systolic?.toString() ?? '', dia: dia, onSys: dia.isEmpty);
  }

  final String sys;
  final String dia;

  /// Whether the keypad is filling systolic (true) or diastolic.
  final bool onSys;

  /// A third systolic digit moves the cursor on to diastolic by itself.
  BpDraft key(String d) {
    if (onSys) {
      final next = sys.length < 3 ? sys + d : sys;
      return BpDraft(sys: next, dia: dia, onSys: next.length != 3);
    }
    return dia.length < 3 ? BpDraft(sys: sys, dia: dia + d, onSys: false) : this;
  }

  BpDraft back() {
    if (!onSys && dia.isEmpty) return BpDraft(sys: sys, dia: dia);
    if (!onSys) return BpDraft(sys: sys, dia: dia.substring(0, dia.length - 1), onSys: false);
    if (sys.isNotEmpty) return BpDraft(sys: sys.substring(0, sys.length - 1), dia: dia);
    return this;
  }

  BpDraft focus({required bool systolic}) => BpDraft(sys: sys, dia: dia, onSys: systolic);

  bool get valid => VitalLimits.bloodPressureOk(int.tryParse(sys), int.tryParse(dia));

  Vitals get vitals => valid ? Vitals(systolic: int.parse(sys), diastolic: int.parse(dia)) : Vitals.empty;

  @override
  bool operator ==(Object other) => other is BpDraft && other.sys == sys && other.dia == dia && other.onSys == onSys;

  @override
  int get hashCode => Object.hash(sys, dia, onSys);
}

class BpDraftNotifier extends Notifier<BpDraft> {
  BpDraftNotifier(this.args);
  final DraftKey args;

  @override
  BpDraft build() => BpDraft.from(args.initial);

  void key(String d) => state = state.key(d);
  void back() => state = state.back();
  void focus({required bool systolic}) => state = state.focus(systolic: systolic);
}

final NotifierProviderFamily<BpDraftNotifier, BpDraft, DraftKey> bpDraftProvider =
    NotifierProvider.autoDispose.family<BpDraftNotifier, BpDraft, DraftKey>(BpDraftNotifier.new);

// ── Glucose ──────────────────────────────────────────────────

@immutable
class GlucoseDraft {
  const GlucoseDraft({this.digits = '', this.context = GlucoseContext.fasting});

  factory GlucoseDraft.from(Vitals? v) => GlucoseDraft(
        digits: (v?.glucoseFasting ?? v?.glucosePostMeal ?? v?.glucoseRandom)?.toString() ?? '',
        context: switch (v) {
          Vitals(glucosePostMeal: _?) => GlucoseContext.postMeal,
          Vitals(glucoseRandom: _?) => GlucoseContext.random,
          _ => GlucoseContext.fasting,
        },
      );

  final String digits;
  final GlucoseContext context;

  GlucoseDraft key(String d) => digits.length >= 3 ? this : GlucoseDraft(digits: digits + d, context: context);

  GlucoseDraft back() =>
      digits.isEmpty ? this : GlucoseDraft(digits: digits.substring(0, digits.length - 1), context: context);

  GlucoseDraft withContext(GlucoseContext c) => GlucoseDraft(digits: digits, context: c);

  bool get valid => VitalLimits.glucoseOk(int.tryParse(digits));

  Vitals get vitals {
    if (!valid) return Vitals.empty;
    final value = int.parse(digits);
    return Vitals(
      glucoseFasting: context == GlucoseContext.fasting ? value : null,
      glucosePostMeal: context == GlucoseContext.postMeal ? value : null,
      glucoseRandom: context == GlucoseContext.random ? value : null,
    );
  }

  @override
  bool operator ==(Object other) => other is GlucoseDraft && other.digits == digits && other.context == context;

  @override
  int get hashCode => Object.hash(digits, context);
}

class GlucoseDraftNotifier extends Notifier<GlucoseDraft> {
  GlucoseDraftNotifier(this.args);
  final DraftKey args;

  @override
  GlucoseDraft build() => GlucoseDraft.from(args.initial);

  void key(String d) => state = state.key(d);
  void back() => state = state.back();
  void setContext(GlucoseContext c) => state = state.withContext(c);
}

final NotifierProviderFamily<GlucoseDraftNotifier, GlucoseDraft, DraftKey> glucoseDraftProvider =
    NotifierProvider.autoDispose.family<GlucoseDraftNotifier, GlucoseDraft, DraftKey>(GlucoseDraftNotifier.new);

// ── Weight ───────────────────────────────────────────────────

@immutable
class WeightDraft {
  const WeightDraft({this.kg = '', this.decimals = '', this.hasDot = false});

  /// Back into the pad's digits: whole kilos, then at most one decimal.
  factory WeightDraft.from(Vitals? v) {
    final w = v?.weightKg;
    if (w == null) return const WeightDraft();
    final tenths = (w * 10).round();
    return WeightDraft(
      kg: '${tenths ~/ 10}',
      decimals: tenths % 10 == 0 ? '' : '${tenths % 10}',
      hasDot: tenths % 10 != 0,
    );
  }

  final String kg;
  final String decimals;
  final bool hasDot;

  String get display => kg.isEmpty ? '' : (hasDot ? '$kg.${decimals.isEmpty ? '0' : decimals}' : kg);

  WeightDraft key(String d) {
    if (hasDot) return decimals.isEmpty ? WeightDraft(kg: kg, decimals: d, hasDot: true) : this;
    return kg.length < 3 ? WeightDraft(kg: kg + d) : this;
  }

  WeightDraft back() {
    if (hasDot && decimals.isNotEmpty) return WeightDraft(kg: kg, hasDot: true);
    if (hasDot) return WeightDraft(kg: kg);
    if (kg.isNotEmpty) return WeightDraft(kg: kg.substring(0, kg.length - 1));
    return this;
  }

  WeightDraft dot() => hasDot || kg.isEmpty ? this : WeightDraft(kg: kg, decimals: decimals, hasDot: true);

  bool get valid => VitalLimits.weightKgOk(double.tryParse(display));

  Vitals get vitals => valid ? Vitals(weightKg: double.parse(display)) : Vitals.empty;

  @override
  bool operator ==(Object other) =>
      other is WeightDraft && other.kg == kg && other.decimals == decimals && other.hasDot == hasDot;

  @override
  int get hashCode => Object.hash(kg, decimals, hasDot);
}

class WeightDraftNotifier extends Notifier<WeightDraft> {
  WeightDraftNotifier(this.args);
  final DraftKey args;

  @override
  WeightDraft build() => WeightDraft.from(args.initial);

  void key(String d) => state = state.key(d);
  void back() => state = state.back();
  void dot() => state = state.dot();
}

final NotifierProviderFamily<WeightDraftNotifier, WeightDraft, DraftKey> weightDraftProvider =
    NotifierProvider.autoDispose.family<WeightDraftNotifier, WeightDraft, DraftKey>(WeightDraftNotifier.new);

// ── SpO₂ ─────────────────────────────────────────────────────

@immutable
class Spo2Draft {
  const Spo2Draft([this.digits = '']);

  factory Spo2Draft.from(Vitals? v) => Spo2Draft(v?.spo2?.toString() ?? '');

  final String digits;

  /// Two digits cover 11–99; a third only completes 10 → 100.
  Spo2Draft key(String d) {
    if (digits.length >= 3) return this;
    if (digits.length == 2 && (digits != '10' || d != '0')) return this;
    return Spo2Draft(digits + d);
  }

  Spo2Draft back() => digits.isEmpty ? this : Spo2Draft(digits.substring(0, digits.length - 1));

  int? get percent => digits.isEmpty ? null : int.tryParse(digits);

  bool get valid => VitalLimits.spo2Ok(percent);

  Vitals get vitals => valid ? Vitals(spo2: percent) : Vitals.empty;

  @override
  bool operator ==(Object other) => other is Spo2Draft && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;
}

class Spo2DraftNotifier extends Notifier<Spo2Draft> {
  Spo2DraftNotifier(this.args);
  final DraftKey args;

  @override
  Spo2Draft build() => Spo2Draft.from(args.initial);

  void key(String d) => state = state.key(d);
  void back() => state = state.back();
}

final NotifierProviderFamily<Spo2DraftNotifier, Spo2Draft, DraftKey> spo2DraftProvider =
    NotifierProvider.autoDispose.family<Spo2DraftNotifier, Spo2Draft, DraftKey>(Spo2DraftNotifier.new);

// ── Pulse ────────────────────────────────────────────────────

/// Seconds the "count with me" mode listens for; the rate is the count × 60 / this.
const int kPulseCountSeconds = 15;

@immutable
class PulseDraft {
  const PulseDraft({this.digits = '', this.counting = false, this.beats = 0, this.left});

  factory PulseDraft.from(Vitals? v) => PulseDraft(digits: v?.heartRate?.toString() ?? '');

  final String digits;

  /// Tapping beats instead of typing.
  final bool counting;
  final int beats;

  /// Seconds left in the count; null until the first tap starts it.
  final int? left;

  PulseDraft key(String d) => digits.length >= 3 ? this : PulseDraft(digits: digits + d);

  PulseDraft back() => digits.isEmpty ? this : PulseDraft(digits: digits.substring(0, digits.length - 1));

  PulseDraft startCounting() => PulseDraft(digits: digits, counting: true);

  PulseDraft typeInstead() => PulseDraft(digits: digits);

  /// The first tap starts the clock and is itself the first beat.
  PulseDraft beat() {
    if (left == null) return PulseDraft(digits: digits, counting: true, beats: 1, left: kPulseCountSeconds);
    if (left! > 0) return PulseDraft(digits: digits, counting: true, beats: beats + 1, left: left);
    return this;
  }

  /// One second passes. When the count ends the rate becomes the typed value.
  PulseDraft tick() {
    final remaining = (left ?? 0) - 1;
    if (remaining > 0) return PulseDraft(digits: digits, counting: true, beats: beats, left: remaining);
    return PulseDraft(digits: '${beats * (60 ~/ kPulseCountSeconds)}');
  }

  int? get bpm => digits.isEmpty ? null : int.tryParse(digits);

  bool get valid => !counting && VitalLimits.heartRateOk(bpm);

  Vitals get vitals => valid ? Vitals(heartRate: bpm) : Vitals.empty;

  @override
  bool operator ==(Object other) =>
      other is PulseDraft &&
      other.digits == digits &&
      other.counting == counting &&
      other.beats == beats &&
      other.left == left;

  @override
  int get hashCode => Object.hash(digits, counting, beats, left);
}

class PulseDraftNotifier extends Notifier<PulseDraft> {
  PulseDraftNotifier(this.args);
  final DraftKey args;

  @override
  PulseDraft build() => PulseDraft.from(args.initial);

  void key(String d) => state = state.key(d);
  void back() => state = state.back();
  void startCounting() => state = state.startCounting();
  void typeInstead() => state = state.typeInstead();
  void beat() => state = state.beat();
  void tick() => state = state.tick();
}

final NotifierProviderFamily<PulseDraftNotifier, PulseDraft, DraftKey> pulseDraftProvider =
    NotifierProvider.autoDispose.family<PulseDraftNotifier, PulseDraft, DraftKey>(PulseDraftNotifier.new);

// ── Date and photo, shared by every form ─────────────────────

@immutable
class EntryExtras {
  const EntryExtras({required this.when, this.photo});

  final DateTime when;
  final PickedAttach? photo;

  EntryExtras withWhen(DateTime v) => EntryExtras(when: v, photo: photo);

  EntryExtras withPhoto(PickedAttach? p) => EntryExtras(when: when, photo: p);

  @override
  bool operator ==(Object other) => other is EntryExtras && other.when == when && identical(other.photo, photo);

  @override
  int get hashCode => Object.hash(when, identityHashCode(photo));
}

/// Key for [entryExtrasProvider]: the form's token and the stored entry's time
/// and photo, so an edit opens on them (quicklog.jsx `init`).
typedef ExtrasKey = ({Object form, DateTime? when, PickedAttach? photo});

class EntryExtrasNotifier extends Notifier<EntryExtras> {
  EntryExtrasNotifier(this.args);
  final ExtrasKey args;

  @override
  EntryExtras build() => EntryExtras(when: args.when ?? DateTime.now(), photo: args.photo);

  void setWhen(DateTime v) => state = state.withWhen(v);
  void setPhoto(PickedAttach? p) => state = state.withPhoto(p);
}

final NotifierProviderFamily<EntryExtrasNotifier, EntryExtras, ExtrasKey> entryExtrasProvider =
    NotifierProvider.autoDispose.family<EntryExtrasNotifier, EntryExtras, ExtrasKey>(EntryExtrasNotifier.new);

// ── Mood, pain and symptoms ──────────────────────────────────
//
// Sets in these drafts are unmodifiable and compared by value, so a toggle is
// a new draft that Riverpod 3's `==` filter lets through, and a widget can
// never change a draft in place.

Set<E> _toggled<E>(Set<E> set, E item) =>
    Set.unmodifiable(set.contains(item) ? set.difference({item}) : {...set, item});

@immutable
class MoodDraft {
  const MoodDraft([this.score = 0]);

  factory MoodDraft.from(MetricLogCapture? c) => MoodDraft(c?.mood?.score ?? 0);

  /// 1–5; 0 until a face is picked.
  final int score;

  MoodDraft pick(int s) => MoodDraft(s);

  bool get valid => score > 0;

  Mood? get mood => valid ? Mood(score) : null;

  @override
  bool operator ==(Object other) => other is MoodDraft && other.score == score;

  @override
  int get hashCode => score.hashCode;
}

class MoodDraftNotifier extends Notifier<MoodDraft> {
  MoodDraftNotifier(this.args);
  final CaptureDraftKey args;

  @override
  MoodDraft build() => MoodDraft.from(args.initial);

  void pick(int score) => state = state.pick(score);
}

final NotifierProviderFamily<MoodDraftNotifier, MoodDraft, CaptureDraftKey> moodDraftProvider =
    NotifierProvider.autoDispose.family<MoodDraftNotifier, MoodDraft, CaptureDraftKey>(MoodDraftNotifier.new);

@immutable
class PainDraft {
  PainDraft({this.level = 0, Set<PainSite> sites = const {}}) : sites = Set.unmodifiable(sites);

  factory PainDraft.from(MetricLogCapture? c) =>
      PainDraft(level: c?.painLevel.value ?? 0, sites: c?.painSites ?? const {});

  /// 0–10, as the slider stops on whole steps.
  final int level;
  final Set<PainSite> sites;

  PainDraft withLevel(int v) => PainDraft(level: v, sites: sites);

  /// A site of another tissue than the ones already picked is refused
  /// ([canToggleSite]).
  PainDraft toggleSite(PainSite site) =>
      canToggleSite(sites, site) ? PainDraft(level: level, sites: _toggled(sites, site)) : this;

  bool get valid => level > 0 || sites.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is PainDraft && other.level == level && const SetEquality<PainSite>().equals(other.sites, sites);

  @override
  int get hashCode => Object.hash(level, Object.hashAllUnordered(sites));
}

class PainDraftNotifier extends Notifier<PainDraft> {
  PainDraftNotifier(this.args);
  final CaptureDraftKey args;

  @override
  PainDraft build() => PainDraft.from(args.initial);

  void setLevel(int v) => state = state.withLevel(v);
  void toggleSite(PainSite site) => state = state.toggleSite(site);
}

final NotifierProviderFamily<PainDraftNotifier, PainDraft, CaptureDraftKey> painDraftProvider =
    NotifierProvider.autoDispose.family<PainDraftNotifier, PainDraft, CaptureDraftKey>(PainDraftNotifier.new);

@immutable
class SymptomsDraft {
  SymptomsDraft({Set<SymptomId> symptoms = const {}, this.none = false, Set<PainSite> sites = const {}})
      : symptoms = Set.unmodifiable(symptoms),
        sites = Set.unmodifiable(sites);

  final Set<SymptomId> symptoms;

  /// "No symptoms" ticked — clears every symptom and site.
  final bool none;
  final Set<PainSite> sites;

  /// The body map shows once a symptom the design locates is picked.
  bool get showMap => symptoms.any((id) => id.hasLocation);

  /// [multi] in the full check-in; one at a time in the one-metric quick log.
  SymptomsDraft select(SymptomId id, {required bool multi}) {
    final next = symptoms.contains(id) ? symptoms.difference({id}) : {if (multi) ...symptoms, id};
    final draft = SymptomsDraft(symptoms: next, sites: sites);
    return draft.showMap ? draft : SymptomsDraft(symptoms: next);
  }

  SymptomsDraft toggleNone() => none ? SymptomsDraft(symptoms: symptoms, sites: sites) : SymptomsDraft(none: true);

  SymptomsDraft toggleSite(PainSite site) =>
      canToggleSite(sites, site) ? SymptomsDraft(symptoms: symptoms, none: none, sites: _toggled(sites, site)) : this;

  bool get valid => symptoms.isNotEmpty || none;

  @override
  bool operator ==(Object other) =>
      other is SymptomsDraft &&
      other.none == none &&
      const SetEquality<SymptomId>().equals(other.symptoms, symptoms) &&
      const SetEquality<PainSite>().equals(other.sites, sites);

  @override
  int get hashCode => Object.hash(none, Object.hashAllUnordered(symptoms), Object.hashAllUnordered(sites));
}

class SymptomsDraftNotifier extends Notifier<SymptomsDraft> {
  SymptomsDraftNotifier(this.args);
  final CaptureDraftKey args;

  /// Opens empty, edit or not: the multi-symptom form has never prefilled,
  /// and an edit of one symptom opens [OneSymptomDraft] instead.
  @override
  SymptomsDraft build() => SymptomsDraft();

  void select(SymptomId id, {required bool multi}) => state = state.select(id, multi: multi);
  void toggleNone() => state = state.toggleNone();
  void toggleSite(PainSite site) => state = state.toggleSite(site);
}

final NotifierProviderFamily<SymptomsDraftNotifier, SymptomsDraft, CaptureDraftKey> symptomsDraftProvider =
    NotifierProvider.autoDispose.family<SymptomsDraftNotifier, SymptomsDraft, CaptureDraftKey>(
  SymptomsDraftNotifier.new,
);

/// Key for [oneSymptomDraftProvider]: the form, the stored entry an edit
/// opens on, and which catalog symptom the form captures.
typedef OneSymptomKey = ({Object form, MetricLogCapture? initial, SymptomId symptom});

@immutable
class OneSymptomDraft {
  OneSymptomDraft({Set<PainSite> sites = const {}, this.detail = const SymptomDetail()})
      : sites = Set.unmodifiable(sites);

  factory OneSymptomDraft.from(MetricLogCapture? c, SymptomId symptom) => OneSymptomDraft(
        sites: c?.painSites ?? const {},
        detail: c?.symptomDetails[symptom] ?? const SymptomDetail(),
      );

  final Set<PainSite> sites;

  /// Only urine and stool carry one (`SymptomId.hasDetail`).
  final SymptomDetail detail;

  OneSymptomDraft toggleSite(PainSite site) =>
      canToggleSite(sites, site) ? OneSymptomDraft(sites: _toggled(sites, site), detail: detail) : this;

  OneSymptomDraft withDetail(SymptomDetail d) => OneSymptomDraft(sites: sites, detail: d);

  @override
  bool operator ==(Object other) =>
      other is OneSymptomDraft && other.detail == detail && const SetEquality<PainSite>().equals(other.sites, sites);

  @override
  int get hashCode => Object.hash(detail, Object.hashAllUnordered(sites));
}

class OneSymptomDraftNotifier extends Notifier<OneSymptomDraft> {
  OneSymptomDraftNotifier(this.args);
  final OneSymptomKey args;

  @override
  OneSymptomDraft build() => OneSymptomDraft.from(args.initial, args.symptom);

  void toggleSite(PainSite site) => state = state.toggleSite(site);
  void setDetail(SymptomDetail d) => state = state.withDetail(d);
}

final NotifierProviderFamily<OneSymptomDraftNotifier, OneSymptomDraft, OneSymptomKey> oneSymptomDraftProvider =
    NotifierProvider.autoDispose.family<OneSymptomDraftNotifier, OneSymptomDraft, OneSymptomKey>(
  OneSymptomDraftNotifier.new,
);
