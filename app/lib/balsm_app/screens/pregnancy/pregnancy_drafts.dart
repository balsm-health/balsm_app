import 'package:core/core.dart';
import 'package:flutter/foundation.dart' show immutable, setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily, ProviderFamily;
import 'package:pregnancy/pregnancy.dart';

import '../../widgets/photo_attach.dart';

/// What the pregnancy forms hold while they are open: starting tracking,
/// recording a birth, attaching a record, and the next antenatal visit.
///
/// The rules live here as pure transitions (unit-tested without a widget);
/// each form watches one auto-disposing provider keyed by a token its State
/// creates once, so two open forms never share a draft. Free text stays in
/// the forms' text controllers.
///
/// PHI: every draft here is health data; none of it is ever logged.

// ── Start tracking ───────────────────────────────────────────

/// Whether the start form's day is the due date or the last period's first day.
enum PregnancyStartMode { due, lastPeriod }

@immutable
class PregnancyStartDraft {
  const PregnancyStartDraft({this.mode = PregnancyStartMode.due, this.date, this.visit, this.count = 1});

  final PregnancyStartMode mode;

  /// The day picked, read as [mode] says; null until one is picked.
  final DateTime? date;

  /// The optional next antenatal visit.
  final DateTime? visit;

  /// How many babies, 1 to [Pregnancy.maxBabies].
  final int count;

  /// The due date the form gives: the day picked, or estimated from the last period.
  DateTime? get due => switch ((mode, date)) {
        (_, null) => null,
        (PregnancyStartMode.due, final DateTime d) => d,
        (PregnancyStartMode.lastPeriod, final DateTime d) => PregnancyDates.dueFromLastPeriod(d),
      };

  /// A day picked under one mode means something else under the other, so
  /// switching clears it.
  PregnancyStartDraft withMode(PregnancyStartMode m) =>
      m == mode ? this : PregnancyStartDraft(mode: m, visit: visit, count: count);

  PregnancyStartDraft withDate(DateTime d) => PregnancyStartDraft(mode: mode, date: d, visit: visit, count: count);

  PregnancyStartDraft withVisit(DateTime d) => PregnancyStartDraft(mode: mode, date: date, visit: d, count: count);

  PregnancyStartDraft withCount(int n) =>
      PregnancyStartDraft(mode: mode, date: date, visit: visit, count: n.clamp(1, Pregnancy.maxBabies));

  @override
  bool operator ==(Object other) =>
      other is PregnancyStartDraft &&
      other.mode == mode &&
      other.date == date &&
      other.visit == visit &&
      other.count == count;

  @override
  int get hashCode => Object.hash(mode, date, visit, count);
}

class PregnancyStartDraftNotifier extends Notifier<PregnancyStartDraft> {
  PregnancyStartDraftNotifier(this.form);
  final Object form;

  @override
  PregnancyStartDraft build() => const PregnancyStartDraft();

  void setMode(PregnancyStartMode m) => state = state.withMode(m);
  void setDate(DateTime d) => state = state.withDate(d);
  void setVisit(DateTime d) => state = state.withVisit(d);
  void setCount(int n) => state = state.withCount(n);
}

final NotifierProviderFamily<PregnancyStartDraftNotifier, PregnancyStartDraft, Object> pregnancyStartDraftProvider =
    NotifierProvider.autoDispose.family<PregnancyStartDraftNotifier, PregnancyStartDraft, Object>(
  PregnancyStartDraftNotifier.new,
);

// ── Birth ────────────────────────────────────────────────────

@immutable
class BirthDraft {
  BirthDraft({
    this.babyId,
    this.name = '',
    this.sex,
    this.dob,
    this.blood,
    this.bloodUnsure = false,
    Set<PregnancyItemId> keep = const {},
  }) : keep = Set.unmodifiable(keep);

  /// Which baby arrived; null until one is chosen.
  final HealthProfileId? babyId;

  /// The baby's name as typed (seeded from the name given in pregnancy).
  final String name;
  final Sex? sex;
  final DateTime? dob;
  final BloodType? blood;

  /// "Not sure" picked on the blood type grid.
  final bool bloodUnsure;

  /// The records about this baby that move with it; the others stay.
  final Set<PregnancyItemId> keep;

  /// Choosing a baby starts its answers afresh: its given name, no sex or
  /// blood type, and every record about it ticked. The date of birth stays.
  BirthDraft choose(PregnancyBaby b, List<PregnancyItem> items) => BirthDraft(
        babyId: b.id,
        name: b.givenName ?? '',
        dob: dob,
        keep: items.where((i) => i.isAbout(b.id)).map((i) => i.id).toSet(),
      );

  BirthDraft _with({
    String? name,
    Sex? sex,
    DateTime? dob,
    (BloodType?,)? blood,
    Set<PregnancyItemId>? keep,
  }) =>
      BirthDraft(
        babyId: babyId,
        name: name ?? this.name,
        sex: sex ?? this.sex,
        dob: dob ?? this.dob,
        blood: blood == null ? this.blood : blood.$1,
        bloodUnsure: blood == null ? bloodUnsure : blood.$1 == null,
        keep: keep ?? this.keep,
      );

  BirthDraft withName(String v) => _with(name: v);
  BirthDraft withSex(Sex v) => _with(sex: v);
  BirthDraft withDob(DateTime v) => _with(dob: v);

  /// A blood type, or null for "not sure".
  BirthDraft withBlood(BloodType? b) => _with(blood: (b,));

  BirthDraft toggleKeep(PregnancyItemId id) => _with(keep: keep.contains(id) ? ({...keep}..remove(id)) : {...keep, id});

  /// What is recorded, for the baby chosen; null before one is.
  BirthDetails? details({Relationship relationship = Relationship.child}) {
    final id = babyId;
    if (id == null) return null;
    return BirthDetails(
      babyId: id,
      name: name,
      sex: sex,
      dateOfBirth: dob,
      bloodType: bloodUnsure ? null : blood,
      keepItemIds: keep,
      relationship: relationship,
    );
  }

  /// A baby is chosen and its details break no rule as of [now].
  bool valid(DateTime now) => details()?.violations(now).isEmpty ?? false;

  @override
  bool operator ==(Object other) =>
      other is BirthDraft &&
      other.babyId == babyId &&
      other.name == name &&
      other.sex == sex &&
      other.dob == dob &&
      other.blood == blood &&
      other.bloodUnsure == bloodUnsure &&
      setEquals(other.keep, keep);

  @override
  int get hashCode => Object.hash(babyId, name, sex, dob, blood, bloodUnsure, Object.hashAllUnordered(keep));
}

/// The one baby still followed in mother `mother`'s pregnancy, with the
/// pregnancy's records; null while loading, or when there are several.
final ProviderFamily<({PregnancyBaby baby, List<PregnancyItem> items})?, HealthProfileId?> _onlyBabyProvider =
    Provider.autoDispose.family<({PregnancyBaby baby, List<PregnancyItem> items})?, HealthProfileId?>(
  (ref, mother) {
    final preg = ref.watch(activePregnancyOfProvider(mother));
    if (preg == null) return null;
    final babies = ref.watch(pregnancyBabiesProvider(preg.id)).value;
    final items = ref.watch(pregnancyItemsProvider(preg.itemsKey)).value;
    if (babies == null || items == null) return null;
    final active = babies.where((b) => b.isActive).toList();
    return active.length == 1 ? (baby: active.single, items: items) : null;
  },
);

/// One open birth form for mother `mother` (null = the account holder).
typedef BirthDraftKey = ({Object form, HealthProfileId? mother});

/// With a single baby still followed, the form chooses it by itself.
class BirthDraftNotifier extends Notifier<BirthDraft> {
  BirthDraftNotifier(this.args);
  final BirthDraftKey args;

  @override
  BirthDraft build() {
    final blank = BirthDraft(dob: DateTime.now());
    final only = ref.listen(_onlyBabyProvider(args.mother), (_, next) {
      if (state.babyId == null && next != null) state = state.choose(next.baby, next.items);
    });
    return switch (only.read()) { final o? => blank.choose(o.baby, o.items), _ => blank };
  }

  void choose(PregnancyBaby b, List<PregnancyItem> items) => state = state.choose(b, items);
  void setName(String v) => state = state.withName(v);
  void setSex(Sex v) => state = state.withSex(v);
  void setDob(DateTime v) => state = state.withDob(v);
  void setBlood(BloodType? v) => state = state.withBlood(v);
  void toggleKeep(PregnancyItemId id) => state = state.toggleKeep(id);
}

final NotifierProviderFamily<BirthDraftNotifier, BirthDraft, BirthDraftKey> birthDraftProvider =
    NotifierProvider.autoDispose.family<BirthDraftNotifier, BirthDraft, BirthDraftKey>(BirthDraftNotifier.new);

// ── Attach a record ──────────────────────────────────────────

@immutable
class PregnancyItemDraft {
  PregnancyItemDraft({
    required this.date,
    this.me = false,
    Set<HealthProfileId> babies = const {},
    this.kind = ItemKind.scan,
    this.file,
  }) : babies = Set.unmodifiable(babies);

  /// The record is about the mother.
  final bool me;

  /// The babies it is about (several = a shared report).
  final Set<HealthProfileId> babies;

  /// The kind picked; see [effectiveKind].
  final ItemKind kind;
  final DateTime date;

  /// The scan or document picked; not used for measurements.
  final PickedAttach? file;

  bool get chosen => me || babies.isNotEmpty;

  /// Measurements are taken for one baby at a time.
  bool get canMeasure => !me && babies.length == 1;

  ItemKind get effectiveKind => kind == ItemKind.measure && !canMeasure ? ItemKind.scan : kind;

  PregnancyItemDraft _with({
    bool? me,
    Set<HealthProfileId>? babies,
    ItemKind? kind,
    DateTime? date,
    PickedAttach? file,
  }) =>
      PregnancyItemDraft(
        me: me ?? this.me,
        babies: babies ?? this.babies,
        kind: kind ?? this.kind,
        date: date ?? this.date,
        file: file ?? this.file,
      );

  /// "Me" on or off; either way no baby stays ticked.
  PregnancyItemDraft toggleMe() => _with(me: !me, babies: const {});

  PregnancyItemDraft toggleBaby(HealthProfileId id) =>
      _with(me: false, babies: babies.contains(id) ? ({...babies}..remove(id)) : {...babies, id});

  /// Ticks every baby in [all], or none when they all are already.
  PregnancyItemDraft toggleAll(Iterable<HealthProfileId> all) {
    final allOn = all.every(babies.contains);
    return _with(me: false, babies: allOn ? const {} : {...babies, ...all});
  }

  PregnancyItemDraft withKind(ItemKind k) => _with(kind: k);
  PregnancyItemDraft withDate(DateTime d) => _with(date: d);
  PregnancyItemDraft withFile(PickedAttach f) => _with(file: f);

  @override
  bool operator ==(Object other) =>
      other is PregnancyItemDraft &&
      other.me == me &&
      setEquals(other.babies, babies) &&
      other.kind == kind &&
      other.date == date &&
      other.file == file;

  @override
  int get hashCode => Object.hash(me, Object.hashAllUnordered(babies), kind, date, file);
}

/// One open attach form; `babyIds` are the babies it opens ticked.
typedef PregnancyItemDraftKey = ({Object form, List<HealthProfileId> babyIds});

class PregnancyItemDraftNotifier extends Notifier<PregnancyItemDraft> {
  PregnancyItemDraftNotifier(this.args);
  final PregnancyItemDraftKey args;

  @override
  PregnancyItemDraft build() => PregnancyItemDraft(date: DateTime.now(), babies: args.babyIds.toSet());

  void toggleMe() => state = state.toggleMe();
  void toggleBaby(HealthProfileId id) => state = state.toggleBaby(id);
  void toggleAll(Iterable<HealthProfileId> all) => state = state.toggleAll(all);
  void setKind(ItemKind k) => state = state.withKind(k);
  void setDate(DateTime d) => state = state.withDate(d);
  void attach(PickedAttach f) => state = state.withFile(f);
}

final NotifierProviderFamily<PregnancyItemDraftNotifier, PregnancyItemDraft, PregnancyItemDraftKey>
    pregnancyItemDraftProvider =
    NotifierProvider.autoDispose.family<PregnancyItemDraftNotifier, PregnancyItemDraft, PregnancyItemDraftKey>(
  PregnancyItemDraftNotifier.new,
);

// ── Next antenatal visit ─────────────────────────────────────

/// The visit sheet's day; `initial` is the stored visit's day it opens on.
typedef NextVisitDayKey = ({Object form, DateTime? initial});

class NextVisitDayNotifier extends Notifier<DateTime?> {
  NextVisitDayNotifier(this.args);
  final NextVisitDayKey args;

  @override
  DateTime? build() => args.initial;

  /// The day picked for the visit.
  DateTime? get day => state;
  set day(DateTime? d) => state = d;
}

final NotifierProviderFamily<NextVisitDayNotifier, DateTime?, NextVisitDayKey> nextVisitDayProvider =
    NotifierProvider.autoDispose.family<NextVisitDayNotifier, DateTime?, NextVisitDayKey>(NextVisitDayNotifier.new);
