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
  });

  final String summary;
  final String? note;
  final Mood? mood;
  final PainLevel painLevel;
  final Set<PainSite> painSites;
  final Set<SymptomId> symptoms;
  final Vitals vitals;

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
  });

  final CheckInMetric metric;
  final PatientAppState s;
  final MetricLogHost host;
  final MetricLogSave? onSave;
  final MetricLogChanged? onChanged;

  @override
  Widget build(BuildContext context) {
    if (metric == CheckInMetric.mood) {
      return _MoodLog(s: s, host: host, onSave: onSave, onChanged: onChanged);
    }
    if (metric == CheckInMetric.bloodPressure) {
      return _BpLog(s: s, host: host, onSave: onSave, onChanged: onChanged);
    }
    if (metric == CheckInMetric.glucose) {
      return _GlucoseLog(s: s, host: host, onSave: onSave, onChanged: onChanged);
    }
    if (metric == CheckInMetric.weight) {
      return _WeightLog(s: s, host: host, onSave: onSave, onChanged: onChanged);
    }
    if (metric == CheckInMetric.pain) {
      return _PainLog(s: s, host: host, onSave: onSave, onChanged: onChanged);
    }
    if (metric == CheckInMetric.symptoms) {
      return _SymptomsLog(s: s, host: host, onSave: onSave, onChanged: onChanged);
    }
    return const SizedBox.shrink();
  }
}

/// Symptoms the design pairs with the body map (`loc: true`) — the catalog's
/// only located entry is swelling; the rest are whole-body sensations.
const _locatedSymptomIds = {'swelling'};

mixin _MetricLogState<T extends StatefulWidget> on State<T> {
  PatientAppState get s;
  MetricLogHost get host;
  MetricLogSave? get onSave;
  MetricLogChanged? get onChanged;
  bool get valid;
  MetricLogCapture get capture;

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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      child,
      _NoteField(s: s, controller: noteCtrl),
      if (host == MetricLogHost.standalone)
        _SaveButton(
          s: s,
          enabled: valid,
          onTap: () => onSave?.call(capture),
        ),
    ]);
  }

  TextEditingController get noteCtrl;
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.s, required this.controller});
  final PatientAppState s;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? s.accent.bg : Colors.white,
            borderRadius: BorderRadius.circular(T.rLg),
            border: Border.all(color: active ? s.accent.main : T.border, width: 1.5),
          ),
          child: Text(value.isEmpty ? '—' : value,
              style: Typo.num(size: FS.xl3, weight: FontWeight.w700, color: value.isEmpty ? T.ink300 : T.fg1)),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.s, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final PatientAppState s;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.97,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? s.accent.bg : Colors.white,
            borderRadius: BorderRadius.circular(T.rPill),
            border: Border.all(color: selected ? s.accent.main : T.border, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? s.accent.d : T.fg2),
              const SizedBox(width: 7),
            ],
            Text(label,
                style:
                    Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: selected ? s.accent.d : T.fg2)),
          ]),
        ),
      );
}

String? _trimmedNote(TextEditingController c) {
  final t = c.text.trim();
  return t.isEmpty ? null : t;
}

// ── Mood ─────────────────────────────────────────────────────

class _MoodLog extends StatefulWidget {
  const _MoodLog({required this.s, required this.host, this.onSave, this.onChanged});
  final PatientAppState s;
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
                        padding: EdgeInsets.only(right: i < 4 ? 8 : 0),
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
  const _BpLog({required this.s, required this.host, this.onSave, this.onChanged});
  final PatientAppState s;
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
          _BigReading(value: sys, s: s, active: onSys, onTap: () => setState(() => onSys = true), width: 104),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('/', style: Typo.num(size: FS.xl3, weight: FontWeight.w700, color: T.ink300)),
          ),
          _BigReading(value: dia, s: s, active: !onSys, onTap: () => setState(() => onSys = false), width: 104),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
              width: 104,
              child: Text(s.strings.checkin.sys,
                  textAlign: TextAlign.center,
                  style:
                      Typo.meta(ar: ar).copyWith(fontWeight: FontWeight.w600, color: onSys ? s.accent.main : T.fg3))),
          const SizedBox(width: 24),
          SizedBox(
              width: 104,
              child: Text(s.strings.checkin.dia,
                  textAlign: TextAlign.center,
                  style:
                      Typo.meta(ar: ar).copyWith(fontWeight: FontWeight.w600, color: onSys ? T.fg3 : s.accent.main))),
        ]),
        const SizedBox(height: 8),
        Text(s.strings.checkin.unit_bp, style: Typo.meta(ar: ar).copyWith(color: T.fg3)),
        const SizedBox(height: 12),
        NumPad(onKey: _key, onBack: _back, pressBg: s.accent.bg),
      ]),
    );
  }
}

// ── Glucose ──────────────────────────────────────────────────

enum _GluCtx { fasting, meal, random }

class _GlucoseLog extends StatefulWidget {
  const _GlucoseLog({required this.s, required this.host, this.onSave, this.onChanged});
  final PatientAppState s;
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
          Text(s.strings.checkin.unit_glu, style: Typo.meta(ar: s.rtl).copyWith(color: T.fg3)),
          const SizedBox(height: 12),
          NumPad(
            onKey: (d) => setState(() {
              glu = glu.length >= 3 ? glu : glu + d;
              emit();
            }),
            onBack: () => setState(() {
              glu = glu.isEmpty ? glu : glu.substring(0, glu.length - 1);
              emit();
            }),
            pressBg: s.accent.bg,
          ),
        ]),
      );
}

// ── Weight ───────────────────────────────────────────────────

class _WeightLog extends StatefulWidget {
  const _WeightLog({required this.s, required this.host, this.onSave, this.onChanged});
  final PatientAppState s;
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
          Text(s.strings.profile.pd_kg, style: Typo.meta(ar: s.rtl).copyWith(color: T.fg3)),
          const SizedBox(height: 12),
          NumPad(
            onKey: _key,
            onBack: _back,
            decimal: true,
            onDot: () => setState(() => hasDot = hasDot || kg.isNotEmpty),
            pressBg: s.accent.bg,
          ),
        ]),
      );
}

// ── Pain ─────────────────────────────────────────────────────

class _PainLog extends StatefulWidget {
  const _PainLog({required this.s, required this.host, this.onSave, this.onChanged});
  final PatientAppState s;
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
          Text('${pain.round()}', style: Typo.num(size: 64, weight: FontWeight.w700, color: info.color)),
          Text(info.lbl, style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
        ])),
        SliderTheme(
          data: SliderThemeData(
              activeTrackColor: info.color, thumbColor: info.color, inactiveTrackColor: T.ink100, trackHeight: 10),
          child: Slider(
              value: pain,
              min: 0,
              max: 10,
              divisions: 10,
              onChanged: (v) => setState(() {
                    pain = v;
                    emit();
                  })),
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
  const _SymptomsLog({required this.s, required this.host, this.onSave, this.onChanged});
  final PatientAppState s;
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
  MetricLogHost get host => widget.host;
  @override
  MetricLogSave? get onSave => widget.onSave;
  @override
  MetricLogChanged? get onChanged => widget.onChanged;
  @override
  late final TextEditingController noteCtrl = TextEditingController()..addListener(emit);

  SymptomId? symptom;
  bool noSymptoms = false;
  final Set<PainSite> locations = {};

  bool get _showMap => symptom != null && _locatedSymptomIds.contains(symptom!.id);

  @override
  bool get valid => symptom != null || noSymptoms;

  @override
  MetricLogCapture get capture {
    final label = noSymptoms ? s.strings.checkin.s_none : (symptom == null ? '' : symptomLabel(s, symptom!));
    final where = locations.map((r) => siteLabel(s, r)).join(s.strings.checkin.list_sep);
    return MetricLogCapture(
      summary: where.isEmpty ? label : s.strings.checkin.labeled_where(label, where),
      note: _trimmedNote(noteCtrl),
      symptoms: symptom == null ? const {} : {symptom!},
      painSites: locations,
    );
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  void _select(SymptomId id) => setState(() {
        noSymptoms = false;
        symptom = symptom == id ? null : id;
        if (!_showMap) locations.clear();
        emit();
      });

  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    return chrome(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          ...symptomIcons.map((e) => _Chip(
              label: symptomLabel(s, e.$1), selected: symptom == e.$1, s: s, icon: e.$2, onTap: () => _select(e.$1))),
          _Chip(
              label: s.strings.checkin.s_none,
              selected: noSymptoms,
              s: s,
              icon: LucideIcons.checkCircle2,
              onTap: () => setState(() {
                    noSymptoms = !noSymptoms;
                    if (noSymptoms) {
                      symptom = null;
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
