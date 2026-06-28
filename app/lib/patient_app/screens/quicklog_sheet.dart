import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../data.dart';
import '../kit.dart';
import '../tokens.dart';
import '../widgets/num_pad.dart';
import '../widgets/mood_face.dart';
import '../widgets/body_map.dart';

const _painColors = [
  Color(0xFF55D77F), Color(0xFF7AD455), Color(0xFF9CC92E), Color(0xFFC5C424),
  Color(0xFFE5B428), Color(0xFFE89428), Color(0xFFE07228), Color(0xFFD85030),
  Color(0xFFCF3C38), Color(0xFFC43040), Color(0xFFB82040),
];

class _QlMetric {
  const _QlMetric(this.id, this.icon, this.color, this.bg, this.labelKey);
  final String id;
  final IconData icon;
  final Color color;
  final Color bg;
  final String labelKey;
}

const _metrics = [
  _QlMetric('bp', LucideIcons.activity, T.petalViolet, T.petalViolet50, 'm_bp'),
  _QlMetric('glucose', LucideIcons.droplet, T.petalMint600, T.petalMint50, 'm_glucose'),
  _QlMetric('mood', LucideIcons.smile, T.petalAqua, T.petalAqua50, 'm_mood'),
  _QlMetric('pain', LucideIcons.zap, T.danger, T.dangerBg, 'm_pain'),
  _QlMetric('weight', LucideIcons.scale, T.petalBlue, T.petalBlue50, 'm_weight'),
  _QlMetric('symptoms', LucideIcons.stethoscope, Color(0xFF9A6E00), Color(0xFFFDF5DC), 'symptoms'),
];

const _quickSymptoms = [
  ('s_headache', LucideIcons.brain), ('s_dizzy', LucideIcons.rotateCw),
  ('s_fatigue', LucideIcons.batteryLow), ('s_blurred', LucideIcons.eye),
  ('s_swelling', LucideIcons.droplet), ('s_chest', LucideIcons.heartPulse),
  ('s_nausea', LucideIcons.frown), ('s_thirst', LucideIcons.cupSoda),
];

/// FAB quick-log bottom sheet (quicklog.jsx). [onFullCheckin] opens the report flow.
Future<void> showQuickLog(BuildContext context, {required VoidCallback onFullCheckin}) {
  final s = AppScope.of(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x612B2B25),
    builder: (ctx) => Directionality(
      textDirection: s.dir,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _QuickLogSheet(s: s, onFullCheckin: () { Navigator.pop(ctx); onFullCheckin(); }),
        ),
      ),
    ),
  );
}

class _QuickLogSheet extends StatefulWidget {
  const _QuickLogSheet({required this.s, required this.onFullCheckin});
  final PatientAppState s;
  final VoidCallback onFullCheckin;
  @override
  State<_QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<_QuickLogSheet> {
  String? active;
  String? savedValue;

  PatientAppState get s => widget.s;

  void _save(String value) {
    setState(() => savedValue = value);
    Future.delayed(const Duration(milliseconds: 1600), () { if (mounted) Navigator.pop(context); });
  }

  @override
  Widget build(BuildContext context) {
    final info = active == null ? null : _metrics.firstWhere((m) => m.id == active);
    return _SheetShell(
      onBack: active != null && savedValue == null ? () => setState(() => active = null) : null,
      title: info == null ? null : s.t(info.labelKey),
      child: savedValue != null
          ? _SavedFlash(value: savedValue!)
          : active == null
              ? _menu()
              : _flow(active!),
    );
  }

  Widget _menu() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Full check-in CTA
        GestureDetector(
          onTap: widget.onFullCheckin,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: s.accent.main, borderRadius: BorderRadius.circular(T.rLg), boxShadow: s.accent.boxShadow),
            child: Row(children: [
              Container(width: 46, height: 46, alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0x38FFFFFF), borderRadius: BorderRadius.circular(T.rMd)),
                  child: const Icon(LucideIcons.clipboardList, size: 23, color: Colors.white)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.t('full_checkin'), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Mood · BP · glucose · meds · symptoms', style: Typo.bodySm(ar: s.rtl).copyWith(color: const Color(0xD9FFFFFF))),
              ])),
              const Icon(LucideIcons.chevronRight, size: 18, color: Color(0xBFFFFFFF)),
            ]),
          ),
        ),
        Row(children: [
          const Expanded(child: Divider(color: T.ink100)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(s.t('quick_log_or'), style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg4))),
          const Expanded(child: Divider(color: T.ink100)),
        ]),
        const SizedBox(height: 4),
        for (final m in _metrics)
          GestureDetector(
            onTap: () => setState(() => active = m.id),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
              child: Row(children: [
                Container(width: 42, height: 42, alignment: Alignment.center,
                    decoration: BoxDecoration(color: m.bg, borderRadius: BorderRadius.circular(T.rMd)),
                    child: Icon(m.icon, size: 21, color: m.color)),
                const SizedBox(width: 14),
                Expanded(child: Text(s.t(m.labelKey), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1))),
                const Icon(LucideIcons.chevronRight, size: 18, color: T.fg4),
              ]),
            ),
          ),
      ]);

  Widget _flow(String id) => switch (id) {
        'bp' => _BpFlow(s: s, onSave: _save),
        'glucose' => _GlucoseFlow(s: s, onSave: _save),
        'mood' => _MoodFlow(s: s, onSave: _save),
        'pain' => _PainFlow(s: s, onSave: _save),
        'weight' => _WeightFlow(s: s, onSave: _save),
        _ => _SymptomsFlow(s: s, onSave: _save),
      };
}

// ── Sheet shell ──────────────────────────────────────────────
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child, this.onBack, this.title});
  final Widget child;
  final VoidCallback? onBack;
  final String? title;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(children: [
            if (onBack == null)
              Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
            Container(
              padding: const EdgeInsets.only(bottom: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink100))),
              child: Row(children: [
                if (onBack != null) RoundBtn(icon: LucideIcons.arrowLeft, ghost: true, iconSize: 18, onTap: onBack),
                Expanded(child: title != null
                    ? Padding(padding: const EdgeInsets.only(left: 4), child: Text(title!, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)))
                    : const SizedBox()),
                RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 18, onTap: () => Navigator.pop(context)),
              ]),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 38),
            child: child,
          ),
        ),
      ]),
    );
  }
}

class _SavedFlash extends StatelessWidget {
  const _SavedFlash({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(children: [
      const SizedBox(height: 8),
      Container(width: 72, height: 72, alignment: Alignment.center,
          decoration: BoxDecoration(color: T.petalMint50, shape: BoxShape.circle),
          child: const Icon(LucideIcons.check, size: 36, color: T.petalMint600)),
      const SizedBox(height: 14),
      Text(s.t('store_synced') == 'Synced' ? 'Saved' : 'تم الحفظ',
          style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl)),
      const SizedBox(height: 6),
      Text(value, textAlign: TextAlign.center, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
    ]);
  }
}

// ── Note + photo block (simplified) ──────────────────────────
class _NoteAttach extends StatelessWidget {
  const _NoteAttach({required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.only(top: 18),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: T.ink100))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.t('note_lbl'), style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: 2, maxLines: 4,
          textDirection: s.dir,
          style: Typo.body(ar: s.rtl).copyWith(color: T.fg1),
          decoration: InputDecoration(
            hintText: s.t('note_ph'),
            hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4),
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(T.rMd),
            border: Border.all(color: T.borderStrong, width: 1.5, style: BorderStyle.solid),
          ),
          child: Row(children: [
            const Icon(LucideIcons.camera, size: 20, color: T.fg3),
            const SizedBox(width: 12),
            Text(s.t('add_photo'), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ]),
        ),
      ]),
    );
  }
}

class _SaveBtn extends StatelessWidget {
  const _SaveBtn({required this.enabled, required this.onTap, required this.s});
  final bool enabled;
  final VoidCallback onTap;
  final PatientAppState s;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: PButton('Save', variant: BtnVariant.primary, large: true, block: true,
              accent: s.accent, ar: s.rtl, onTap: enabled ? onTap : null),
        ),
      );
}

// Big vital number box
class _VitalBox extends StatelessWidget {
  const _VitalBox({required this.text, required this.active, this.onTap, this.minWidth = 90, required this.s});
  final String text;
  final bool active;
  final VoidCallback? onTap;
  final double minWidth;
  final PatientAppState s;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? s.accent.bg : Colors.transparent,
            borderRadius: BorderRadius.circular(T.rMd),
            border: Border.all(color: active ? s.accent.main : Colors.transparent, width: 1.5),
          ),
          child: Text(text, style: Typo.num(size: FS.xl4, weight: FontWeight.w600)),
        ),
      );
}

// ── BP flow ──────────────────────────────────────────────────
class _BpFlow extends StatefulWidget {
  const _BpFlow({required this.s, required this.onSave});
  final PatientAppState s;
  final ValueChanged<String> onSave;
  @override
  State<_BpFlow> createState() => _BpFlowState();
}

class _BpFlowState extends State<_BpFlow> {
  String sys = '', dia = '';
  String field = 'sys';
  final note = TextEditingController();
  bool get ok => sys.length >= 2 && dia.length >= 2;
  void _key(String d) => setState(() {
        if (field == 'sys') { if (sys.length < 3) { sys += d; if (sys.length == 3) field = 'dia'; } }
        else if (dia.length < 3) dia += d;
      });
  void _back() => setState(() {
        if (field == 'dia' && dia.isEmpty) field = 'sys';
        else if (field == 'dia') dia = dia.substring(0, dia.length - 1);
        else if (sys.isNotEmpty) sys = sys.substring(0, sys.length - 1);
      });
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _VitalBox(text: sys.isEmpty ? '—' : sys, active: field == 'sys', onTap: () => setState(() => field = 'sys'), s: s),
        Text('/', style: Typo.display().copyWith(fontSize: FS.xl3, color: T.ink300)),
        _VitalBox(text: dia.isEmpty ? '—' : dia, active: field == 'dia', onTap: () => setState(() => field = 'dia'), s: s),
      ]),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(s.t('sys'), style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: field == 'sys' ? s.accent.main : T.fg3)),
        const SizedBox(width: 60),
        Text(s.t('dia'), style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: field == 'dia' ? s.accent.main : T.fg3)),
      ]),
      const SizedBox(height: 4),
      Text(s.t('unit_bp'), style: Typo.body(ar: s.rtl).copyWith(color: T.fg3, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      NumPad(onKey: _key, onBack: _back),
      _NoteAttach(controller: note),
      _SaveBtn(enabled: ok, s: s, onTap: () => widget.onSave('$sys/$dia ${s.t('unit_bp')}')),
    ]);
  }
}

// ── Glucose flow ─────────────────────────────────────────────
class _GlucoseFlow extends StatefulWidget {
  const _GlucoseFlow({required this.s, required this.onSave});
  final PatientAppState s;
  final ValueChanged<String> onSave;
  @override
  State<_GlucoseFlow> createState() => _GlucoseFlowState();
}

class _GlucoseFlowState extends State<_GlucoseFlow> {
  String glu = '';
  String ctx = 'glu_fast';
  final note = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(children: [
      Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
        for (final c in const ['glu_fast', 'glu_meal', 'glu_random'])
          _Chip(label: s.t(c), selected: ctx == c, accent: s.accent, ar: s.rtl, onTap: () => setState(() => ctx = c)),
      ]),
      const SizedBox(height: 14),
      _VitalBox(text: glu.isEmpty ? '—' : glu, active: true, minWidth: 120, s: s),
      const SizedBox(height: 4),
      Text(s.t('unit_glu'), style: Typo.body(ar: s.rtl).copyWith(color: T.fg3, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      NumPad(onKey: (d) => setState(() { if (glu.length < 3) glu += d; }), onBack: () => setState(() { if (glu.isNotEmpty) glu = glu.substring(0, glu.length - 1); })),
      _NoteAttach(controller: note),
      _SaveBtn(enabled: glu.length >= 2, s: s, onTap: () => widget.onSave('$glu ${s.t('unit_glu')} · ${s.t(ctx)}')),
    ]);
  }
}

// ── Mood flow ────────────────────────────────────────────────
class _MoodFlow extends StatefulWidget {
  const _MoodFlow({required this.s, required this.onSave});
  final PatientAppState s;
  final ValueChanged<String> onSave;
  @override
  State<_MoodFlow> createState() => _MoodFlowState();
}

class _MoodFlowState extends State<_MoodFlow> {
  int mood = 0;
  final note = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(children: [
      Row(children: [
        for (var lv = 1; lv <= 5; lv++)
          Expanded(child: Padding(
            padding: EdgeInsets.only(right: lv < 5 ? 10 : 0),
            child: GestureDetector(
              onTap: () => setState(() => mood = lv),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: mood == lv ? s.accent.bg : Colors.white,
                    borderRadius: BorderRadius.circular(T.rLg),
                    border: Border.all(color: mood == lv ? s.accent.main : T.border, width: 1.5),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    MoodFace(level: lv, size: 34, color: mood == lv ? kMoodColors[lv - 1] : T.ink400),
                    const SizedBox(height: 8),
                    Text(s.t('mood_$lv'), style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs2, fontWeight: FontWeight.w600, color: mood == lv ? s.accent.d : T.fg3)),
                  ]),
                ),
              ),
            ),
          )),
      ]),
      _NoteAttach(controller: note),
      _SaveBtn(enabled: mood > 0, s: s, onTap: () => widget.onSave(s.t('mood_$mood'))),
    ]);
  }
}

// ── Pain flow (slider) ───────────────────────────────────────
class _PainFlow extends StatefulWidget {
  const _PainFlow({required this.s, required this.onSave});
  final PatientAppState s;
  final ValueChanged<String> onSave;
  @override
  State<_PainFlow> createState() => _PainFlowState();
}

class _PainFlowState extends State<_PainFlow> {
  double intensity = 0;
  final Set<String> locs = {};
  final note = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final color = _painColors[intensity.round().clamp(0, 10)];
    return Column(children: [
      RichText(text: TextSpan(children: [
        TextSpan(text: '${intensity.round()}', style: Typo.num(size: 64, weight: FontWeight.w700, color: color)),
        TextSpan(text: ' /10', style: Typo.body(ar: s.rtl).copyWith(color: T.fg3)),
      ])),
      SliderTheme(
        data: SliderThemeData(activeTrackColor: color, thumbColor: color, inactiveTrackColor: T.ink100, trackHeight: 8),
        child: Slider(value: intensity, min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() => intensity = v)),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(s.t('pain_0'), style: Typo.meta(ar: s.rtl).copyWith(color: T.fg4)),
        Text(s.t('pain_worst'), style: Typo.meta(ar: s.rtl).copyWith(color: T.fg4)),
      ]),
      const SizedBox(height: 16),
      Align(alignment: AlignmentDirectional.centerStart, child: Text(s.t('body_location'), style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3))),
      const SizedBox(height: 8),
      BodyMap(selected: locs, onToggle: (id) => setState(() => locs.contains(id) ? locs.remove(id) : locs.add(id))),
      _NoteAttach(controller: note),
      _SaveBtn(enabled: intensity > 0, s: s, onTap: () => widget.onSave('${intensity.round()}/10')),
    ]);
  }
}

// ── Weight flow ──────────────────────────────────────────────
class _WeightFlow extends StatefulWidget {
  const _WeightFlow({required this.s, required this.onSave});
  final PatientAppState s;
  final ValueChanged<String> onSave;
  @override
  State<_WeightFlow> createState() => _WeightFlowState();
}

class _WeightFlowState extends State<_WeightFlow> {
  String kg = '', dec = '';
  bool dot = false;
  final note = TextEditingController();
  String get display => kg.isEmpty ? '—' : (dot ? '$kg.$dec' : kg);
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(children: [
      _VitalBox(text: display, active: true, minWidth: 130, s: s),
      const SizedBox(height: 4),
      Text(s.rtl ? 'كج' : 'kg', style: Typo.body(ar: s.rtl).copyWith(color: T.fg3, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      NumPad(
        decimal: true,
        onDot: () => setState(() { if (!dot && kg.isNotEmpty) dot = true; }),
        onKey: (d) => setState(() { if (dot) { if (dec.isEmpty) dec += d; } else if (kg.length < 3) kg += d; }),
        onBack: () => setState(() {
          if (dot && dec.isNotEmpty) dec = '';
          else if (dot) dot = false;
          else if (kg.isNotEmpty) kg = kg.substring(0, kg.length - 1);
        }),
      ),
      _NoteAttach(controller: note),
      _SaveBtn(enabled: kg.length >= 2, s: s, onTap: () => widget.onSave('$display ${s.rtl ? 'كج' : 'kg'}')),
    ]);
  }
}

// ── Symptoms flow (chips) ────────────────────────────────────
class _SymptomsFlow extends StatefulWidget {
  const _SymptomsFlow({required this.s, required this.onSave});
  final PatientAppState s;
  final ValueChanged<String> onSave;
  @override
  State<_SymptomsFlow> createState() => _SymptomsFlowState();
}

class _SymptomsFlowState extends State<_SymptomsFlow> {
  final Set<String> syms = {};
  final Set<String> locs = {};
  final note = TextEditingController();
  void _toggle(String id) => setState(() {
        if (id == 's_none') { syms.clear(); syms.add('s_none'); return; }
        syms.remove('s_none');
        syms.contains(id) ? syms.remove(id) : syms.add(id);
      });
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final showMap = syms.where((x) => x != 's_none').isNotEmpty;
    return Column(children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final (id, icon) in _quickSymptoms)
          _Chip(label: s.t(id), icon: icon, selected: syms.contains(id), accent: s.accent, ar: s.rtl, onTap: () => _toggle(id)),
        _Chip(label: s.t('s_none'), icon: LucideIcons.checkCircle2, selected: syms.contains('s_none'), accent: s.accent, ar: s.rtl, onTap: () => _toggle('s_none')),
      ]),
      if (showMap) ...[
        const SizedBox(height: 16),
        Align(alignment: AlignmentDirectional.centerStart, child: Text(s.t('body_location'), style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3))),
        const SizedBox(height: 8),
        BodyMap(selected: locs, onToggle: (id) => setState(() => locs.contains(id) ? locs.remove(id) : locs.add(id))),
      ],
      _NoteAttach(controller: note),
      _SaveBtn(enabled: syms.isNotEmpty, s: s, onTap: () => widget.onSave(
          syms.contains('s_none') ? s.t('s_none') : syms.map((x) => s.t(x)).join(', '))),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon, required this.selected, required this.accent, required this.ar, required this.onTap});
  final String label;
  final IconData? icon;
  final bool selected;
  final Accent accent;
  final bool ar;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? accent.bg : Colors.white,
            borderRadius: BorderRadius.circular(T.rPill),
            border: Border.all(color: selected ? accent.main : T.border, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: selected ? accent.d : T.fg2), const SizedBox(width: 7)],
            Text(label, style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: selected ? accent.d : T.fg2)),
          ]),
        ),
      );
}
