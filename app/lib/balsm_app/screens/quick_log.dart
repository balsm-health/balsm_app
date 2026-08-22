import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:core/core.dart' show currentProfileIdProvider;
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import '../widgets/body_map.dart';
import '../widgets/num_pad.dart';
import 'report_flow.dart' show MoodCell, openCheckin, painInfo, symptomIcons, symptomLabelKey;

/// Opens the quick-log sheet (quicklog.jsx `QuickLogSheet`) — what the "+"
/// action in the tab bar / nav rail resolves to. It offers the full check-in
/// plus six one-metric mini flows; picking one and saving persists a check-in
/// carrying only what the patient actually entered.
void showQuickLog(BuildContext context) {
  final s = AppScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x612B2B25),
    builder: (sheetContext) => Directionality(
      textDirection: s.dir,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _QuickLogSheet(
            s: s,
            onFullCheckin: () {
              Navigator.pop(sheetContext);
              openCheckin(context);
            },
          ),
        ),
      ),
    ),
  );
}

/// The six one-metric flows, in the design's order.
enum _Metric { bp, glucose, mood, pain, weight, symptoms }

typedef _MetricStyle = ({IconData icon, Color color, Color bg, String labelKey});

const _metricStyles = <_Metric, _MetricStyle>{
  _Metric.bp: (icon: LucideIcons.activity, color: T.petalViolet, bg: T.petalViolet50, labelKey: 'profile.m_bp'),
  _Metric.glucose: (icon: LucideIcons.droplet, color: T.petalMint600, bg: T.petalMint50, labelKey: 'profile.m_glucose'),
  _Metric.mood: (icon: LucideIcons.smile, color: T.petalAqua, bg: T.petalAqua50, labelKey: 'profile.m_mood'),
  _Metric.pain: (icon: LucideIcons.zap, color: T.danger, bg: T.dangerBg, labelKey: 'profile.m_pain'),
  _Metric.weight: (icon: LucideIcons.scale, color: T.petalBlue, bg: T.petalBlue50, labelKey: 'profile.m_weight'),
  _Metric.symptoms: (
    icon: LucideIcons.stethoscope,
    color: Color(0xFF9A6E00),
    bg: Color(0xFFFDF5DC),
    labelKey: 'checkin.symptoms'
  ),
};

/// Symptoms the design pairs with the body map (`loc: true`) — the catalog's
/// only located entry is swelling; the rest are whole-body sensations.
const _locatedSymptomIds = {'swelling'};

/// What a mini flow hands back once the patient taps Save: the human-readable
/// value for the saved flash plus the check-in fields it captured.
typedef _SaveCallback = void Function({
  required String summary,
  String? note,
  Mood? mood,
  PainLevel painLevel,
  Set<BodyRegion> painRegions,
  Set<SymptomId> symptoms,
  Vitals vitals,
});

class _QuickLogSheet extends ConsumerStatefulWidget {
  const _QuickLogSheet({required this.s, required this.onFullCheckin});
  final PatientAppState s;
  final VoidCallback onFullCheckin;
  @override
  ConsumerState<_QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends ConsumerState<_QuickLogSheet> {
  _Metric? active;
  String? savedValue;
  String? savedNote;
  bool saving = false;
  Timer? _closeTimer;

  PatientAppState get s => widget.s;
  bool get ar => s.rtl;

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  /// Persists the single metric as a check-in on-device, then flashes the
  /// confirmation and closes. PHI: the captured values are never logged.
  Future<void> _save({
    required String summary,
    String? note,
    Mood? mood,
    PainLevel painLevel = PainLevel.none,
    Set<BodyRegion> painRegions = const {},
    Set<SymptomId> symptoms = const {},
    Vitals vitals = Vitals.empty,
  }) async {
    if (saving) return;
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) return;
    setState(() => saving = true);

    final trimmed = note?.trim();
    await ref.read(saveCheckInUseCaseProvider).call(CheckIn(
          id: CheckInId.uuid(),
          healthProfileId: profileId,
          recordedAt: DateTime.now(),
          mood: mood,
          painLevel: painLevel,
          painRegions: painRegions,
          symptoms: symptoms,
          vitals: vitals,
          note: trimmed == null || trimmed.isEmpty ? null : trimmed,
        ));

    if (!mounted) return;
    setState(() {
      saving = false;
      savedValue = summary;
      savedNote = trimmed == null || trimmed.isEmpty ? null : trimmed;
    });
    _closeTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final showBack = active != null && savedValue == null;
    final style = active == null ? null : _metricStyles[active]!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration:
            const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(children: [
              if (!showBack)
                Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(T.rPill))),
              Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink100))),
                child: Row(children: [
                  if (showBack) ...[
                    RoundBtn(
                        icon: backArrow(context),
                        ghost: true,
                        iconSize: 18,
                        onTap: () => setState(() => active = null)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      savedValue != null
                          ? s.strings.checkin.ql_saved
                          : (style == null ? s.strings.checkin.ql_title : s.t(style.labelKey)),
                      style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 18, onTap: () => Navigator.pop(context)),
                ]),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + MediaQuery.of(context).padding.bottom.clamp(0, 20)),
              child: RiseIn(key: ValueKey('${active}_${savedValue != null}'), child: _body()),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _body() {
    if (savedValue != null) return _SavedFlash(s: s, value: savedValue!, note: savedNote);
    return switch (active) {
      _Metric.bp => _BpFlow(s: s, onSave: _save),
      _Metric.glucose => _GlucoseFlow(s: s, onSave: _save),
      _Metric.mood => _MoodFlow(s: s, onSave: _save),
      _Metric.pain => _PainFlow(s: s, onSave: _save),
      _Metric.weight => _WeightFlow(s: s, onSave: _save),
      _Metric.symptoms => _SymptomsFlow(s: s, onSave: _save),
      null => _menu(),
    };
  }

  // ── Menu: full check-in CTA + the six metrics ────────────────
  Widget _menu() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Pressable(
          onTap: widget.onFullCheckin,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: s.accent.main,
              borderRadius: BorderRadius.circular(T.rLg),
              boxShadow: s.accent.boxShadow,
            ),
            child: Row(children: [
              const IconSquare(LucideIcons.clipboardList,
                  bg: Color(0x38FFFFFF), fg: Colors.white, size: 46, iconSize: 23),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.strings.checkin.full_checkin,
                    style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 1),
                Text(s.strings.checkin.ql_full_sub,
                    style: Typo.bodySm(ar: ar).copyWith(color: const Color(0xD9FFFFFF))),
              ])),
              Chevron(rtl: ar, color: const Color(0xBFFFFFFF)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            const Expanded(child: Divider(height: 1, color: T.ink100)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(s.strings.checkin.quick_log_or,
                  style: Typo.meta(ar: ar).copyWith(fontSize: FS.xs2, fontWeight: FontWeight.w600, color: T.fg4)),
            ),
            const Expanded(child: Divider(height: 1, color: T.ink100)),
          ]),
        ),
        ..._Metric.values.map(_metricRow),
      ]);

  Widget _metricRow(_Metric m) {
    final style = _metricStyles[m]!;
    return PressHighlight(
      onTap: () => setState(() => active = m),
      radius: T.rMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(children: [
          IconSquare(style.icon, bg: style.bg, fg: style.color, size: 42, iconSize: 21),
          const SizedBox(width: 14),
          Expanded(
              child: Text(s.t(style.labelKey),
                  style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg1))),
          Chevron(rtl: ar),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Shared flow pieces
// ════════════════════════════════════════════════════════════════

/// Optional note for the doctor. The design pairs this with a photo attachment;
/// a quick-log photo belongs in the records vault (`CheckIn.photoRecordId` is
/// only a back-reference), so it is not offered here.
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
        child: Text(s.t('checkin.note_lbl'),
            style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
      ),
      TextField(
        controller: controller,
        minLines: 2,
        maxLines: 4,
        textDirection: s.dir,
        style: Typo.body(ar: ar).copyWith(color: T.fg1),
        decoration: InputDecoration(
          hintText: s.t('checkin.note_ph'),
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

/// A big read-only reading (`.vital-num`). Input comes from [NumPad], so tapping
/// only re-targets the keypad — never the OS keyboard.
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

/// `.chip` — selectable pill, optionally icon-led.
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

class _SavedFlash extends StatelessWidget {
  const _SavedFlash({required this.s, required this.value, this.note});
  final PatientAppState s;
  final String value;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    return Column(children: [
      Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: T.petalMint50, shape: BoxShape.circle),
          child: const Icon(LucideIcons.check, size: 36, color: T.petalMint600)),
      const SizedBox(height: 14),
      Text(s.strings.checkin.ql_saved, style: Typo.heading(ar: ar)),
      const SizedBox(height: 6),
      Text(value, textAlign: TextAlign.center, style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rPill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.cloudOff, size: 15, color: T.fg3),
          const SizedBox(width: 8),
          Text(s.t('common.saved_local'), style: Typo.bodySm(ar: ar).copyWith(color: T.fg3)),
        ]),
      ),
      if (note != null)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rMd)),
          child: Row(children: [
            const Icon(LucideIcons.fileText, size: 14, color: T.fg4),
            const SizedBox(width: 8),
            Expanded(child: Text(note!, style: Typo.bodySm(ar: ar).copyWith(color: T.fg3))),
          ]),
        ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
//  Mini flows
// ════════════════════════════════════════════════════════════════

/// Blood pressure — systolic / diastolic pair, keypad-driven (quicklog.jsx
/// `QuickBP`).
class _BpFlow extends StatefulWidget {
  const _BpFlow({required this.s, required this.onSave});
  final PatientAppState s;
  final _SaveCallback onSave;
  @override
  State<_BpFlow> createState() => _BpFlowState();
}

class _BpFlowState extends State<_BpFlow> {
  final note = TextEditingController();
  String sys = '';
  String dia = '';
  bool onSys = true;

  PatientAppState get s => widget.s;
  bool get ok => sys.length >= 2 && dia.length >= 2;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  void _key(String d) => setState(() {
        if (onSys) {
          if (sys.length < 3) sys += d;
          // Three digits fills systolic — hand the keypad to diastolic.
          if (sys.length == 3) onSys = false;
        } else if (dia.length < 3) {
          dia += d;
        }
      });

  void _back() => setState(() {
        if (!onSys && dia.isEmpty) {
          onSys = true;
        } else if (!onSys) {
          dia = dia.substring(0, dia.length - 1);
        } else if (sys.isNotEmpty) {
          sys = sys.substring(0, sys.length - 1);
        }
      });

  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    return Column(children: [
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
            child: Text(s.t('checkin.sys'),
                textAlign: TextAlign.center,
                style: Typo.meta(ar: ar).copyWith(fontWeight: FontWeight.w600, color: onSys ? s.accent.main : T.fg3))),
        const SizedBox(width: 24),
        SizedBox(
            width: 104,
            child: Text(s.t('checkin.dia'),
                textAlign: TextAlign.center,
                style: Typo.meta(ar: ar).copyWith(fontWeight: FontWeight.w600, color: onSys ? T.fg3 : s.accent.main))),
      ]),
      const SizedBox(height: 8),
      Text(s.t('checkin.unit_bp'), style: Typo.meta(ar: ar).copyWith(color: T.fg3)),
      const SizedBox(height: 12),
      NumPad(onKey: _key, onBack: _back, pressBg: s.accent.bg),
      _NoteField(s: s, controller: note),
      _SaveButton(
        s: s,
        enabled: ok,
        onTap: () => widget.onSave(
          summary: '$sys/$dia ${s.t('checkin.unit_bp')}',
          note: note.text,
          vitals: Vitals(systolic: int.parse(sys), diastolic: int.parse(dia)),
        ),
      ),
    ]);
  }
}

/// Blood glucose — context chips + one reading (quicklog.jsx `QuickGlucose`).
class _GlucoseFlow extends StatefulWidget {
  const _GlucoseFlow({required this.s, required this.onSave});
  final PatientAppState s;
  final _SaveCallback onSave;
  @override
  State<_GlucoseFlow> createState() => _GlucoseFlowState();
}

class _GlucoseFlowState extends State<_GlucoseFlow> {
  static const _contexts = ['checkin.glu_fast', 'checkin.glu_meal', 'checkin.glu_random'];

  final note = TextEditingController();
  String glu = '';
  String ctx = _contexts.first;

  PatientAppState get s => widget.s;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Vitals _vitals() {
    final value = int.parse(glu);
    return Vitals(
      glucoseFasting: ctx == _contexts[0] ? value : null,
      glucosePostMeal: ctx == _contexts[1] ? value : null,
      glucoseRandom: ctx == _contexts[2] ? value : null,
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: _contexts
              .map((c) => _Chip(label: s.t(c), selected: ctx == c, s: s, onTap: () => setState(() => ctx = c)))
              .toList(),
        ),
        const SizedBox(height: 16),
        _BigReading(value: glu, s: s, width: 150),
        const SizedBox(height: 8),
        Text(s.t('checkin.unit_glu'), style: Typo.meta(ar: s.rtl).copyWith(color: T.fg3)),
        const SizedBox(height: 12),
        NumPad(
          onKey: (d) => setState(() => glu = glu.length >= 3 ? glu : glu + d),
          onBack: () => setState(() => glu = glu.isEmpty ? glu : glu.substring(0, glu.length - 1)),
          pressBg: s.accent.bg,
        ),
        _NoteField(s: s, controller: note),
        _SaveButton(
          s: s,
          enabled: glu.length >= 2,
          onTap: () => widget.onSave(
            summary: '$glu ${s.t('checkin.unit_glu')} · ${s.t(ctx)}',
            note: note.text,
            vitals: _vitals(),
          ),
        ),
      ]);
}

/// Weight — kilograms with one decimal (quicklog.jsx `QuickWeight`).
class _WeightFlow extends StatefulWidget {
  const _WeightFlow({required this.s, required this.onSave});
  final PatientAppState s;
  final _SaveCallback onSave;
  @override
  State<_WeightFlow> createState() => _WeightFlowState();
}

class _WeightFlowState extends State<_WeightFlow> {
  final note = TextEditingController();
  String kg = '';
  String decimals = '';
  bool hasDot = false;

  PatientAppState get s => widget.s;
  String get display => kg.isEmpty ? '' : (hasDot ? '$kg.${decimals.isEmpty ? '0' : decimals}' : kg);

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  void _key(String d) => setState(() {
        if (hasDot) {
          if (decimals.isEmpty) decimals = d;
        } else if (kg.length < 3) {
          kg += d;
        }
      });

  void _back() => setState(() {
        if (hasDot && decimals.isNotEmpty) {
          decimals = '';
        } else if (hasDot) {
          hasDot = false;
        } else if (kg.isNotEmpty) {
          kg = kg.substring(0, kg.length - 1);
        }
      });

  @override
  Widget build(BuildContext context) => Column(children: [
        _BigReading(value: display, s: s, width: 170),
        const SizedBox(height: 8),
        Text(s.t('profile.pd_kg'), style: Typo.meta(ar: s.rtl).copyWith(color: T.fg3)),
        const SizedBox(height: 12),
        NumPad(
          onKey: _key,
          onBack: _back,
          decimal: true,
          onDot: () => setState(() => hasDot = hasDot || kg.isNotEmpty),
          pressBg: s.accent.bg,
        ),
        _NoteField(s: s, controller: note),
        _SaveButton(
          s: s,
          enabled: kg.length >= 2,
          onTap: () => widget.onSave(
            summary: '$display ${s.t('profile.pd_kg')}',
            note: note.text,
            vitals: Vitals(weightKg: double.parse(display)),
          ),
        ),
      ]);
}

/// Mood — the five faces (quicklog.jsx `QuickMood`).
class _MoodFlow extends StatefulWidget {
  const _MoodFlow({required this.s, required this.onSave});
  final PatientAppState s;
  final _SaveCallback onSave;
  @override
  State<_MoodFlow> createState() => _MoodFlowState();
}

class _MoodFlowState extends State<_MoodFlow> {
  final note = TextEditingController();
  int mood = 0;

  PatientAppState get s => widget.s;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(
            children: List.generate(
                5,
                (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 4 ? 8 : 0),
                        child: MoodCell(
                            lv: i + 1, selected: mood == i + 1, s: s, onTap: () => setState(() => mood = i + 1)),
                      ),
                    ))),
        _NoteField(s: s, controller: note),
        _SaveButton(
          s: s,
          enabled: mood > 0,
          onTap: () => widget.onSave(
            summary: s.t('checkin.mood_$mood'),
            note: note.text,
            mood: Mood(mood),
          ),
        ),
      ]);
}

/// Pain — 0–10 slider plus the body map (quicklog.jsx `QuickPain`).
class _PainFlow extends StatefulWidget {
  const _PainFlow({required this.s, required this.onSave});
  final PatientAppState s;
  final _SaveCallback onSave;
  @override
  State<_PainFlow> createState() => _PainFlowState();
}

class _PainFlowState extends State<_PainFlow> {
  final note = TextEditingController();
  double pain = 0;
  final Set<String> locations = {};

  PatientAppState get s => widget.s;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    final info = painInfo(s, pain.round());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(
          child: Column(children: [
        Text('${pain.round()}', style: Typo.num(size: 64, weight: FontWeight.w700, color: info.color)),
        Text(info.lbl, style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
      ])),
      SliderTheme(
        data: SliderThemeData(
            activeTrackColor: info.color, thumbColor: info.color, inactiveTrackColor: T.ink100, trackHeight: 10),
        child: Slider(value: pain, min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() => pain = v)),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(s.t('checkin.body_location'),
            style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
      ),
      BodyMap(
          selected: locations,
          onToggle: (id) => setState(() => locations.contains(id) ? locations.remove(id) : locations.add(id))),
      _NoteField(s: s, controller: note),
      _SaveButton(
        s: s,
        enabled: pain > 0 || locations.isNotEmpty,
        onTap: () {
          final regions = locations.map(BodyRegion.fromId).whereType<BodyRegion>().toSet();
          final where = regions.map((r) => s.t(regionLabelKey(r.id))).join(ar ? '، ' : ', ');
          widget.onSave(
            summary: where.isEmpty ? '${pain.round()}/10' : '${pain.round()}/10 · $where',
            note: note.text,
            painLevel: PainLevel(pain.round()),
            painRegions: regions,
          );
        },
      ),
    ]);
  }
}

/// Symptoms — the curated catalog, one at a time (quicklog.jsx
/// `QuickSymptoms`).
class _SymptomsFlow extends StatefulWidget {
  const _SymptomsFlow({required this.s, required this.onSave});
  final PatientAppState s;
  final _SaveCallback onSave;
  @override
  State<_SymptomsFlow> createState() => _SymptomsFlowState();
}

class _SymptomsFlowState extends State<_SymptomsFlow> {
  final note = TextEditingController();

  /// The selected symptom, or null. "Nothing" is [noSymptoms] — a real answer
  /// that saves a check-in with an empty symptom set.
  SymptomId? symptom;
  bool noSymptoms = false;
  final Set<String> locations = {};

  PatientAppState get s => widget.s;
  bool get _showMap => symptom != null && _locatedSymptomIds.contains(symptom!.id);

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  void _select(SymptomId id) => setState(() {
        noSymptoms = false;
        symptom = symptom == id ? null : id;
        if (!_showMap) locations.clear();
      });

  @override
  Widget build(BuildContext context) {
    final ar = s.rtl;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        ...symptomIcons.map((e) => _Chip(
            label: s.t(symptomLabelKey(e.$1)),
            selected: symptom == e.$1,
            s: s,
            icon: e.$2,
            onTap: () => _select(e.$1))),
        _Chip(
            label: s.t('checkin.s_none'),
            selected: noSymptoms,
            s: s,
            icon: LucideIcons.checkCircle2,
            onTap: () => setState(() {
                  noSymptoms = !noSymptoms;
                  if (noSymptoms) {
                    symptom = null;
                    locations.clear();
                  }
                })),
      ]),
      if (_showMap) ...[
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(s.t('checkin.body_location'),
              style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
        ),
        BodyMap(
            selected: locations,
            onToggle: (id) => setState(() => locations.contains(id) ? locations.remove(id) : locations.add(id))),
      ],
      _NoteField(s: s, controller: note),
      _SaveButton(
        s: s,
        enabled: symptom != null || noSymptoms,
        onTap: () {
          final regions = locations.map(BodyRegion.fromId).whereType<BodyRegion>().toSet();
          final label = noSymptoms ? s.t('checkin.s_none') : s.t(symptomLabelKey(symptom!));
          final where = regions.map((r) => s.t(regionLabelKey(r.id))).join(ar ? '، ' : ', ');
          widget.onSave(
            summary: where.isEmpty ? label : '$label · $where',
            note: note.text,
            symptoms: symptom == null ? const {} : {symptom!},
            painRegions: regions,
          );
        },
      ),
    ]);
  }
}
