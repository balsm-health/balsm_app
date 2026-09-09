import 'package:account/account.dart' show accountProfileUseCaseProvider;
import 'package:core/core.dart' show currentUserIdProvider, Gender;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import '../widgets/body_map.dart';
import '../widgets/num_pad.dart';
import '../widgets/date_time_row.dart';
import '../widgets/photo_attach.dart';
import 'checkin_shared.dart';

/// How a metric capture is hosted.
enum MetricLogHost {
  /// Quick-log sheet: note + Save. [MetricLog.onSave] fires on tap.
  standalone,

  /// Full check-in step: same capture + note, no Save. Wizard footer continues.
  /// [MetricLog.onChanged] fires on every edit.
  embedded,
}

/// What a metric template currently holds. PHI — never log these values.
class MetricLogCapture {
  const MetricLogCapture({
    this.summary = '',
    this.note,
    this.mood,
    this.painLevel = PainLevel.none,
    this.painSites = const {},
    this.symptoms = const {},
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
      _sameSet(other.painSites, painSites) &&
      _sameSet(other.symptoms, symptoms);

  @override
  int get hashCode => Object.hash(
        summary,
        note,
        mood,
        painLevel,
        vitals,
        Object.hashAllUnordered(painSites),
        Object.hashAllUnordered(symptoms),
      );
}

bool _sameSet<E>(Set<E> a, Set<E> b) => a.length == b.length && a.containsAll(b);

typedef MetricLogSave = void Function(MetricLogCapture capture);
typedef MetricLogChanged = void Function(MetricLogCapture capture, {required bool valid});

/// Gender from the signed-in user's current profile. Profile details remain
/// ephemeral and are never logged or copied into metric captures.
final _currentProfileGenderProvider = FutureProvider.autoDispose<Gender?>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return null;
  return (await ref.watch(accountProfileUseCaseProvider).load())?.gender;
});

class _CurrentProfileBodyMap extends ConsumerWidget {
  const _CurrentProfileBodyMap({
    required this.s,
    required this.selected,
    required this.onToggle,
  });

  final PatientAppState s;
  final Set<PainSite> selected;
  final ValueChanged<PainSite> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gender = ref.watch(_currentProfileGenderProvider).valueOrNull ?? s.gender;
    return BodyMap(
      gender: gender,
      selected: selected,
      onToggle: onToggle,
    );
  }
}

/// The one-metric log template for [metric]. Same UI in the quick-log sheet
/// and as a full check-in step.
class MetricLog extends StatelessWidget {
  const MetricLog({
    super.key,
    required this.metric,
    required this.s,
    required this.host,
    this.onSave,
    this.onChanged,
    this.focusedSymptom,
    this.belowField,
  });

  final CheckInMetric metric;
  final PatientAppState s;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final MetricLogChanged? onChanged;

  /// Quick-log one-symptom detail: skip the multi-select picker and capture
  /// just this catalog entry (body map only when the design marks it located).
  final SymptomId? focusedSymptom;

  /// Passed straight through to the metric's chrome — see
  /// [_MetricLogState.belowField].
  final Widget? belowField;

  @override
  Widget build(BuildContext context) {
    if (focusedSymptom != null) {
      return _OneSymptomLog(
        s: s,
        host: host,
        belowField: belowField,
        symptom: focusedSymptom!,
        onSave: onSave,
        onChanged: onChanged,
      );
    }
    if (metric == CheckInMetric.mood) {
      return _MoodLog(s: s, host: host, belowField: belowField, onSave: onSave, onChanged: onChanged);
    }
    if (metric == CheckInMetric.bloodPressure) {
      return _BpLog(s: s, host: host, belowField: belowField, onSave: onSave, onChanged: onChanged);
    }
    if (metric == CheckInMetric.glucose) {
      return _GlucoseLog(s: s, host: host, belowField: belowField, onSave: onSave, onChanged: onChanged);
    }
    if (metric == CheckInMetric.weight) {
      return _WeightLog(s: s, host: host, belowField: belowField, onSave: onSave, onChanged: onChanged);
    }
    if (metric == CheckInMetric.spo2) {
      return _O2Log(s: s, host: host, belowField: belowField, onSave: onSave, onChanged: onChanged);
    }
    if (metric == CheckInMetric.pain) {
      return _PainLog(s: s, host: host, belowField: belowField, onSave: onSave, onChanged: onChanged);
    }
    if (metric == CheckInMetric.symptoms) {
      return _SymptomsLog(s: s, host: host, belowField: belowField, onSave: onSave, onChanged: onChanged);
    }
    return const SizedBox.shrink();
  }
}

/// Symptoms the design pairs with the body map (`loc: true`). Catalog-only —
/// urine/stool/tingling from the prototype are not in [SymptomId].
const _locatedSymptomIds = {'swelling', 'chestTightness'};

mixin _MetricLogState<T extends StatefulWidget> on State<T> {
  PatientAppState get s;
  MetricLogHost get host;
  MetricLogSave? get onSave;
  MetricLogChanged? get onChanged;
  bool get valid;
  MetricLogCapture get capture;

  /// Rendered between the field and the date/time group. The full check-in
  /// puts its "I didn't measure this today" row here (report.jsx).
  Widget? get belowField => null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onChanged?.call(capture, valid: valid);
    });
  }

  void emit() {
    onChanged?.call(capture, valid: valid);
  }

  Widget chrome({required Widget child}) {
    // report.jsx cards only the numeric-vital steps (`.card.card-pad` around
    // BPField / GlucoseField) — mood, pain and symptoms stay bare on the flow
    // surface, and a card there squeezed the mood tiles into an overflow.
    // Those are exactly the steps that carry a skip row, so the two travel
    // together rather than needing a second flag.
    final field = belowField == null
        ? child
        : PCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18), child: child);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      field,
      if (belowField != null) belowField!,
      DateTimeWhen(
          when: when,
          onChanged: (v) {
            setState(() => when = v);
            emit();
          }),
      if (host == MetricLogHost.standalone) ...[
        _NoteField(
            s: s,
            controller: noteCtrl,
            photo: photo,
            onPhoto: (p) {
              setState(() => photo = p);
              emit();
            }),
        _SaveButton(
          s: s,
          enabled: valid,
          onTap: () => onSave?.call(capture),
        ),
      ],
    ]);
  }

  DateTime when = DateTime.now();
  PickedAttach? photo;
  TextEditingController get noteCtrl;
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.s, required this.controller, required this.photo, required this.onPhoto});
  final PatientAppState s;
  final TextEditingController controller;
  final PickedAttach? photo;
  final ValueChanged<PickedAttach?> onPhoto;
  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // `NoteAttach` opens with a rule — it closes the metric block above it.
      const Padding(padding: EdgeInsets.only(top: 18), child: Divider(height: 1, color: T.ink100)),
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(s.strings.checkin.note_lbl,
            style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
      ),
      TextField(
        controller: controller,
        minLines: 2,
        maxLines: 4,
        textDirection: s.dir,
        style: Typo.body(ar: ar).copyWith(color: T.fg1),
        decoration: InputDecoration(
          hintText: s.strings.checkin.note_ph,
          hintStyle: Typo.body(ar: ar).copyWith(color: T.fg4),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(14),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
        ),
      ),
      NotePhotoAttach(photo: photo, onChanged: onPhoto),
    ]);
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.s, required this.enabled, required this.onTap});
  final PatientAppState s;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: PButton(s.strings.checkin.ql_save,
              variant: BtnVariant.primary,
              large: true,
              block: true,
              accent: s.accent,
              ar: s.rtl,
              onTap: enabled ? onTap : null),
        ),
      );
}

class _BigReading extends StatelessWidget {
  const _BigReading({required this.value, required this.s, this.active = true, this.onTap, this.width = 108});
  final String value;
  final PatientAppState s;
  final bool active;
  final VoidCallback? onTap;
  final double width;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: onTap == null ? 1 : 0.98,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.easeOut,
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? s.accent.bg : Colors.white,
            borderRadius: BorderRadius.circular(T.rMd),
            // `.vital-num` carries a transparent 1.5px border at rest so the
            // box does not jump when the accent border appears.
            border: Border.all(color: active ? s.accent.main : Colors.transparent, width: 1.5),
          ),
          child: Text(value.isEmpty ? '—' : value,
              style: Typo.num(size: FS.xl4, weight: FontWeight.w600, color: value.isEmpty ? T.ink300 : T.fg1)),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.s, required this.onTap});
  final String label;
  final bool selected;
  final PatientAppState s;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.97,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? s.accent.bg : Colors.white,
            borderRadius: BorderRadius.circular(T.rPill),
            border: Border.all(color: selected ? s.accent.main : T.border, width: 1.5),
          ),
          child: Text(label,
              style:
                  Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: selected ? s.accent.d : T.fg2)),
        ),
      );
}

String? _trimmedNote(TextEditingController c) {
  final t = c.text.trim();
  return t.isEmpty ? null : t;
}

// ── Mood ─────────────────────────────────────────────────────

class _MoodLog extends StatefulWidget {
  const _MoodLog({required this.s, required this.host, this.onSave, this.onChanged, this.belowField});
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final MetricLogChanged? onChanged;
  @override
  State<_MoodLog> createState() => _MoodLogState();
}

class _MoodLogState extends State<_MoodLog> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  late final TextEditingController noteCtrl = TextEditingController()..addListener(emit);

  int mood = 0;

  @override
  bool get valid => mood > 0;

  @override
  MetricLogCapture get capture => MetricLogCapture(
        summary: mood > 0 ? moodLabel(s, mood) : '',
        note: _trimmedNote(noteCtrl),
        mood: mood > 0 ? Mood(mood) : null,
        when: when,
        photoBytes: photo?.bytes,
      );

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => chrome(
        child: Row(
            children: List.generate(
                5,
                (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 4 ? 10 : 0),
                        child: MoodCell(
                            lv: i + 1,
                            selected: mood == i + 1,
                            s: s,
                            onTap: () => setState(() {
                                  mood = i + 1;
                                  emit();
                                })),
                      ),
                    ))),
      );
}

// ── Blood pressure ───────────────────────────────────────────

class _BpLog extends StatefulWidget {
  const _BpLog({required this.s, required this.host, this.onSave, this.onChanged, this.belowField});
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final MetricLogChanged? onChanged;
  @override
  State<_BpLog> createState() => _BpLogState();
}

class _BpLogState extends State<_BpLog> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  late final TextEditingController noteCtrl = TextEditingController()..addListener(emit);

  String sys = '';
  String dia = '';
  bool onSys = true;

  @override
  bool get valid => sys.length >= 2 && dia.length >= 2;

  @override
  MetricLogCapture get capture => MetricLogCapture(
        summary:
            valid ? s.strings.checkin.reading_unit(s.strings.checkin.bp_pair(sys, dia), s.strings.checkin.unit_bp) : '',
        note: _trimmedNote(noteCtrl),
        vitals: valid ? Vitals(systolic: int.parse(sys), diastolic: int.parse(dia)) : Vitals.empty,
        when: when,
        photoBytes: photo?.bytes,
      );

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  void _key(String d) => setState(() {
        if (onSys) {
          if (sys.length < 3) sys += d;
          if (sys.length == 3) onSys = false;
        } else if (dia.length < 3) {
          dia += d;
        }
        emit();
      });

  void _back() => setState(() {
        if (!onSys && dia.isEmpty) {
          onSys = true;
        } else if (!onSys) {
          dia = dia.substring(0, dia.length - 1);
        } else if (sys.isNotEmpty) {
          sys = sys.substring(0, sys.length - 1);
        }
        emit();
      });

  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    return chrome(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _BigReading(value: sys, s: s, active: onSys, onTap: () => setState(() => onSys = true), width: 108),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('/',
                style:
                    Typo.subhead(ar: s.rtl).copyWith(fontSize: FS.xl3, fontWeight: FontWeight.w700, color: T.ink300)),
          ),
          _BigReading(value: dia, s: s, active: !onSys, onTap: () => setState(() => onSys = false), width: 108),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Text(s.strings.checkin.sys,
              style: Typo.meta(ar: ar).copyWith(fontWeight: FontWeight.w600, color: onSys ? s.accent.main : T.fg3)),
          const SizedBox(width: 60),
          Text(s.strings.checkin.dia,
              style: Typo.meta(ar: ar).copyWith(fontWeight: FontWeight.w600, color: onSys ? T.fg3 : s.accent.main)),
        ]),
        const SizedBox(height: 4),
        Text(s.strings.checkin.unit_bp,
            style: Typo.bodySm(ar: ar).copyWith(fontSize: FS.md, fontWeight: FontWeight.w600, color: T.fg3)),
        const SizedBox(height: 16),
        NumPad(onKey: _key, onBack: _back),
      ]),
    );
  }
}

// ── Glucose ──────────────────────────────────────────────────

enum _GluCtx { fasting, meal, random }

class _GlucoseLog extends StatefulWidget {
  const _GlucoseLog({required this.s, required this.host, this.onSave, this.onChanged, this.belowField});
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final MetricLogChanged? onChanged;
  @override
  State<_GlucoseLog> createState() => _GlucoseLogState();
}

class _GlucoseLogState extends State<_GlucoseLog> with _MetricLogState {
  static const _contexts = [_GluCtx.fasting, _GluCtx.meal, _GluCtx.random];

  @override
  PatientAppState get s => widget.s;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  late final TextEditingController noteCtrl = TextEditingController()..addListener(emit);

  String glu = '';
  _GluCtx ctx = _GluCtx.fasting;

  String get _ctxLabel => switch (ctx) {
        _GluCtx.fasting => s.strings.checkin.glu_fast,
        _GluCtx.meal => s.strings.checkin.glu_meal,
        _GluCtx.random => s.strings.checkin.glu_random,
      };

  @override
  bool get valid => glu.length >= 2;

  Vitals _vitals() {
    if (!valid) return Vitals.empty;
    final value = int.parse(glu);
    return Vitals(
      glucoseFasting: ctx == _GluCtx.fasting ? value : null,
      glucosePostMeal: ctx == _GluCtx.meal ? value : null,
      glucoseRandom: ctx == _GluCtx.random ? value : null,
    );
  }

  @override
  MetricLogCapture get capture => MetricLogCapture(
        summary: valid ? s.strings.checkin.reading_unit_ctx(glu, s.strings.checkin.unit_glu, _ctxLabel) : '',
        note: _trimmedNote(noteCtrl),
        vitals: _vitals(),
        when: when,
        photoBytes: photo?.bytes,
      );

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => chrome(
        child: Column(children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _contexts
                .map((c) => _Chip(
                    label: switch (c) {
                      _GluCtx.fasting => s.strings.checkin.glu_fast,
                      _GluCtx.meal => s.strings.checkin.glu_meal,
                      _GluCtx.random => s.strings.checkin.glu_random,
                    },
                    selected: ctx == c,
                    s: s,
                    onTap: () => setState(() {
                          ctx = c;
                          emit();
                        })))
                .toList(),
          ),
          const SizedBox(height: 16),
          _BigReading(value: glu, s: s, width: 150),
          const SizedBox(height: 8),
          Text(s.strings.checkin.unit_glu,
              style: Typo.bodySm(ar: s.rtl).copyWith(fontSize: FS.md, fontWeight: FontWeight.w600, color: T.fg3)),
          const SizedBox(height: 16),
          NumPad(
            onKey: (d) => setState(() {
              glu = glu.length >= 3 ? glu : glu + d;
              emit();
            }),
            onBack: () => setState(() {
              glu = glu.isEmpty ? glu : glu.substring(0, glu.length - 1);
              emit();
            }),
          ),
        ]),
      );
}

// ── Weight ───────────────────────────────────────────────────

class _WeightLog extends StatefulWidget {
  const _WeightLog({required this.s, required this.host, this.onSave, this.onChanged, this.belowField});
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final MetricLogChanged? onChanged;
  @override
  State<_WeightLog> createState() => _WeightLogState();
}

class _WeightLogState extends State<_WeightLog> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  late final TextEditingController noteCtrl = TextEditingController()..addListener(emit);

  String kg = '';
  String decimals = '';
  bool hasDot = false;

  String get display => kg.isEmpty ? '' : (hasDot ? '$kg.${decimals.isEmpty ? '0' : decimals}' : kg);

  @override
  bool get valid => kg.length >= 2;

  @override
  MetricLogCapture get capture => MetricLogCapture(
        summary: valid ? s.strings.checkin.reading_unit(display, s.strings.profile.pd_kg) : '',
        note: _trimmedNote(noteCtrl),
        vitals: valid ? Vitals(weightKg: double.parse(display)) : Vitals.empty,
        when: when,
        photoBytes: photo?.bytes,
      );

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  void _key(String d) => setState(() {
        if (hasDot) {
          if (decimals.isEmpty) decimals = d;
        } else if (kg.length < 3) {
          kg += d;
        }
        emit();
      });

  void _back() => setState(() {
        if (hasDot && decimals.isNotEmpty) {
          decimals = '';
        } else if (hasDot) {
          hasDot = false;
        } else if (kg.isNotEmpty) {
          kg = kg.substring(0, kg.length - 1);
        }
        emit();
      });

  @override
  Widget build(BuildContext context) => chrome(
        child: Column(children: [
          _BigReading(value: display, s: s, width: 170),
          const SizedBox(height: 8),
          Text(s.strings.profile.pd_kg,
              style: Typo.bodySm(ar: s.rtl).copyWith(fontSize: FS.md, fontWeight: FontWeight.w600, color: T.fg3)),
          const SizedBox(height: 16),
          NumPad(
            onKey: _key,
            onBack: _back,
            decimal: true,
            onDot: () => setState(() => hasDot = hasDot || kg.isNotEmpty),
          ),
        ]),
      );
}

// ── SpO₂ ─────────────────────────────────────────────────────

class _O2Log extends StatefulWidget {
  const _O2Log({required this.s, required this.host, this.onSave, this.onChanged, this.belowField});
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final MetricLogChanged? onChanged;
  @override
  State<_O2Log> createState() => _O2LogState();
}

class _O2LogState extends State<_O2Log> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  late final TextEditingController noteCtrl = TextEditingController()..addListener(emit);

  String digits = '';

  int? get _pct => digits.isEmpty ? null : int.tryParse(digits);

  @override
  bool get valid {
    final n = _pct;
    return digits.length >= 2 && n != null && n <= 100;
  }

  @override
  MetricLogCapture get capture => MetricLogCapture(
        summary: valid ? '$digits${s.strings.checkin.unit_spo2}' : '',
        note: _trimmedNote(noteCtrl),
        vitals: valid ? Vitals(spo2: _pct) : Vitals.empty,
        when: when,
        photoBytes: photo?.bytes,
      );

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  void _key(String d) => setState(() {
        // Two digits for 11–99; a third digit only completes 10 → 100.
        if (digits.length >= 3) return;
        if (digits.length == 2 && (digits != '10' || d != '0')) return;
        digits += d;
        emit();
      });

  void _back() => setState(() {
        if (digits.isNotEmpty) digits = digits.substring(0, digits.length - 1);
        emit();
      });

  @override
  Widget build(BuildContext context) => chrome(
        child: Column(children: [
          _BigReading(value: digits, s: s, width: 150),
          const SizedBox(height: 8),
          Text(s.strings.checkin.unit_spo2,
              style: Typo.bodySm(ar: s.rtl).copyWith(fontSize: FS.md, fontWeight: FontWeight.w600, color: T.fg3)),
          const SizedBox(height: 16),
          NumPad(onKey: _key, onBack: _back),
        ]),
      );
}

// ── Pain ─────────────────────────────────────────────────────

class _PainLog extends StatefulWidget {
  const _PainLog({required this.s, required this.host, this.onSave, this.onChanged, this.belowField});
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final MetricLogChanged? onChanged;
  @override
  State<_PainLog> createState() => _PainLogState();
}

class _PainLogState extends State<_PainLog> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  late final TextEditingController noteCtrl = TextEditingController()..addListener(emit);

  double pain = 0;
  final Set<PainSite> locations = {};

  @override
  bool get valid => pain > 0 || locations.isNotEmpty;

  @override
  MetricLogCapture get capture {
    final where = locations.map((r) => siteLabel(s, r)).join(s.strings.checkin.list_sep);
    return MetricLogCapture(
      summary: where.isEmpty
          ? s.strings.checkin.pain_n('${pain.round()}')
          : s.strings.checkin.pain_n_where('${pain.round()}', where),
      note: _trimmedNote(noteCtrl),
      painLevel: PainLevel(pain.round()),
      painSites: locations,
      when: when,
      photoBytes: photo?.bytes,
    );
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    final info = painInfo(s, pain.round());
    return chrome(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
            child: Column(children: [
          Text('${pain.round()}',
              style: Typo.display(ar: s.rtl).copyWith(fontSize: 64, fontWeight: FontWeight.w800, color: info.color)),
          Text(info.lbl, style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
        ])),
        PainSlider(
          value: pain,
          knobColor: info.color,
          onChanged: (v) => setState(() {
            pain = v;
            emit();
          }),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(s.strings.checkin.body_location,
              style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
        ),
        _CurrentProfileBodyMap(
            s: s,
            selected: locations,
            onToggle: (site) => setState(() {
                  locations.contains(site) ? locations.remove(site) : locations.add(site);
                  emit();
                })),
      ]),
    );
  }
}

// ── Symptoms ─────────────────────────────────────────────────

class _SymptomsLog extends StatefulWidget {
  const _SymptomsLog({required this.s, required this.host, this.onSave, this.onChanged, this.belowField});
  final PatientAppState s;
  final Widget? belowField;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final MetricLogChanged? onChanged;
  @override
  State<_SymptomsLog> createState() => _SymptomsLogState();
}

class _SymptomsLogState extends State<_SymptomsLog> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  late final TextEditingController noteCtrl = TextEditingController()..addListener(emit);

  final Set<SymptomId> symptoms = {};
  bool noSymptoms = false;
  final Set<PainSite> locations = {};

  /// `SymptomPicker` is `multi` in the full check-in and single-select in the
  /// one-metric quick log — the design passes `multi={false}` only there.
  bool get _multi => host == MetricLogHost.embedded;

  bool get _showMap => symptoms.any((id) => _locatedSymptomIds.contains(id.id));

  @override
  bool get valid => symptoms.isNotEmpty || noSymptoms;

  @override
  MetricLogCapture get capture {
    final label = noSymptoms
        ? s.strings.checkin.s_none
        : symptoms.map((id) => symptomLabel(s, id)).join(s.strings.checkin.list_sep);
    final where = locations.map((r) => siteLabel(s, r)).join(s.strings.checkin.list_sep);
    return MetricLogCapture(
      summary: where.isEmpty ? label : s.strings.checkin.labeled_where(label, where),
      note: _trimmedNote(noteCtrl),
      symptoms: Set.unmodifiable(symptoms),
      painSites: locations,
      when: when,
      photoBytes: photo?.bytes,
    );
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  void _select(SymptomId id) => setState(() {
        noSymptoms = false;
        if (symptoms.contains(id)) {
          symptoms.remove(id);
        } else {
          if (!_multi) symptoms.clear();
          symptoms.add(id);
        }
        if (!_showMap) locations.clear();
        emit();
      });

  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    return chrome(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // `SymptomPicker` — a `.b-check-group--row`: checkboxes in the full
        // check-in, radios in the one-metric log. Not chips.
        Wrap(spacing: 16, runSpacing: 11, children: [
          ...symptomIcons.map((e) => BCheck(
              label: symptomLabel(s, e.$1),
              checked: symptoms.contains(e.$1),
              icon: e.$2,
              radio: !_multi,
              accent: s.accent,
              ar: ar,
              onTap: () => _select(e.$1))),
          BCheck(
              label: s.strings.checkin.s_none,
              checked: noSymptoms,
              icon: LucideIcons.checkCircle2,
              radio: !_multi,
              accent: s.accent,
              ar: ar,
              onTap: () => setState(() {
                    noSymptoms = !noSymptoms;
                    if (noSymptoms) {
                      symptoms.clear();
                      locations.clear();
                    }
                    emit();
                  })),
        ]),
        if (_showMap) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(s.strings.checkin.body_location,
                style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
          ),
          _CurrentProfileBodyMap(
              s: s,
              selected: locations,
              onToggle: (site) => setState(() {
                    locations.contains(site) ? locations.remove(site) : locations.add(site);
                    emit();
                  })),
        ],
      ]),
    );
  }
}

/// One catalog symptom from the quick-log list — note + save, body map
/// only when the design marks the entry located.
class _OneSymptomLog extends StatefulWidget {
  const _OneSymptomLog({
    required this.s,
    required this.host,
    required this.symptom,
    this.onSave,
    this.onChanged,
    this.belowField,
  });
  final PatientAppState s;
  final MetricLogHost host;
  final Widget? belowField;
  final SymptomId symptom;
  final MetricLogSave? onSave;
  final MetricLogChanged? onChanged;
  @override
  State<_OneSymptomLog> createState() => _OneSymptomLogState();
}

class _OneSymptomLogState extends State<_OneSymptomLog> with _MetricLogState {
  @override
  PatientAppState get s => widget.s;
  @override
  Widget? get belowField => widget.belowField;
  @override
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  late final TextEditingController noteCtrl = TextEditingController()..addListener(emit);

  final Set<PainSite> locations = {};

  bool get _showMap => _locatedSymptomIds.contains(widget.symptom.id);

  @override
  bool get valid => true;

  @override
  MetricLogCapture get capture {
    final label = symptomLabel(s, widget.symptom);
    final where = locations.map((r) => siteLabel(s, r)).join(s.strings.checkin.list_sep);
    return MetricLogCapture(
      summary: where.isEmpty ? label : s.strings.checkin.labeled_where(label, where),
      note: _trimmedNote(noteCtrl),
      symptoms: {widget.symptom},
      painSites: locations,
      when: when,
      photoBytes: photo?.bytes,
    );
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showMap) return chrome(child: const SizedBox.shrink());
    final ar = s.rtl;
    return chrome(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(s.strings.checkin.body_location,
              style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
        ),
        _CurrentProfileBodyMap(
          s: s,
          selected: locations,
          onToggle: (site) => setState(() {
            locations.contains(site) ? locations.remove(site) : locations.add(site);
            emit();
          }),
        ),
      ]),
    );
  }
}

/// `.pain-track` — a 0–10 scale on a mint→sun→danger gradient rail.
///
/// Material's `Slider` can only paint a flat active track, so the rail, knob
/// and ticks are drawn directly. The rail shows the whole scale at once (it is
/// a severity legend, not a progress bar), which is why it is not split into
/// active/inactive halves.
class PainSlider extends StatelessWidget {
  const PainSlider({super.key, required this.value, required this.knobColor, required this.onChanged});

  final double value; // 0..10
  final Color knobColor;
  final ValueChanged<double> onChanged;

  static const _railHeight = 12.0;
  static const _knob = 36.0;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Column(children: [
        SizedBox(
          height: 56,
          child: LayoutBuilder(builder: (context, c) {
            // The knob centre travels between half-knob insets so it never
            // overhangs the rail ends.
            final travel = c.maxWidth - _knob;
            void report(double dx) {
              final raw = ((dx - _knob / 2) / travel).clamp(0.0, 1.0);
              final t = rtl ? 1 - raw : raw;
              onChanged((t * 10).roundToDouble());
            }

            final fraction = (rtl ? 10 - value : value) / 10;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => report(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => report(d.localPosition.dx),
              child: Stack(alignment: Alignment.centerLeft, children: [
                Center(
                  child: Container(
                    height: _railHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(T.rPill),
                      gradient: const LinearGradient(
                        colors: [T.petalMint, T.sun400, T.danger],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: fraction * travel,
                  child: Container(
                    width: _knob,
                    height: _knob,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: knobColor, width: 3),
                      boxShadow: T.shadowMd,
                    ),
                  ),
                ),
              ]),
            );
          }),
        ),
        // `.pain-ticks` — the endpoints and midpoint, in tabular figures.
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final n in const [0, 5, 10])
            Text('$n', style: Typo.num(size: FS.xs2, weight: FontWeight.w600, color: T.fg4)),
        ]),
      ]),
    );
  }
}
