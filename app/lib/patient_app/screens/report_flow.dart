import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../data.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../shell.dart' show AdaptiveFrame;
import '../widgets/mood_face.dart';
import '../widgets/num_pad.dart';
import '../widgets/body_map.dart';

/// Opens the full daily check-in flow (report.jsx ReportFlow) as a route.
void openCheckin(BuildContext context) {
  final s = AppScope.of(context);
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => Directionality(
      textDirection: s.dir,
      child: AdaptiveFrame(child: ReportFlow(s: s)),
    ),
  ));
}

({String lbl, Color color}) _painInfo(PatientAppState s, int n) {
  if (n == 0) return (lbl: s.t('pain_0'), color: T.petalMint);
  if (n <= 3) return (lbl: s.t('pain_mild'), color: T.petalMint600);
  if (n <= 6) return (lbl: s.t('pain_mod'), color: T.sun600);
  if (n <= 9) return (lbl: s.t('pain_sev'), color: const Color(0xFFD97A20));
  return (lbl: s.t('pain_worst'), color: T.danger);
}

const _symptoms = [
  ('s_headache', LucideIcons.brain), ('s_dizzy', LucideIcons.rotateCw),
  ('s_fatigue', LucideIcons.batteryLow), ('s_blurred', LucideIcons.eye),
  ('s_swelling', LucideIcons.droplet), ('s_chest', LucideIcons.heartPulse),
  ('s_nausea', LucideIcons.frown), ('s_thirst', LucideIcons.cupSoda),
];

class ReportFlow extends StatefulWidget {
  const ReportFlow({super.key, required this.s});
  final PatientAppState s;
  @override
  State<ReportFlow> createState() => _ReportFlowState();
}

class _ReportFlowState extends State<ReportFlow> {
  static const steps = ['mood', 'bp', 'glucose', 'meds', 'symptoms'];
  int step = 0;
  bool submitted = false;

  int mood = 0;
  String bpSys = '', bpDia = '', bpField = 'sys';
  bool bpSkip = false;
  String glu = '', gluCtx = 'glu_fast';
  bool gluSkip = false;
  final meds = {for (final m in kMeds) m.id: ''}; // '' | taken | skipped
  double pain = 0;
  final Set<String> syms = {};
  final Set<String> painLocs = {};
  final note = TextEditingController();

  PatientAppState get s => widget.s;
  String get cur => steps[step];

  bool get canNext => switch (cur) {
        'mood' => mood > 0,
        'bp' => bpSkip || (bpSys.length >= 2 && bpDia.length >= 2),
        'glucose' => gluSkip || glu.length >= 2,
        _ => true,
      };

  void next() {
    if (step < steps.length - 1) {
      setState(() => step++);
    } else {
      setState(() => submitted = true);
    }
  }

  void back() {
    if (step > 0) { setState(() => step--); } else { Navigator.pop(context); }
  }

  void _finish(String tab) {
    s.completeCheckin(CheckinResult(
      bp: bpSkip ? null : '$bpSys/$bpDia',
      glu: gluSkip || glu.isEmpty ? null : int.tryParse(glu),
      mood: mood == 0 ? null : mood,
      pain: pain.round(),
    ));
    Navigator.pop(context);
    s.setTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    if (submitted) return _Summary(state: this);
    final pct = (step + 1) / steps.length;
    return Scaffold(
      backgroundColor: T.cream50,
      body: ContentColumn(
        maxWidth: 480,
        child: Column(children: [
        const PadTop(),
        // progress header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(children: [
            RoundBtn(icon: step == 0 ? LucideIcons.x : LucideIcons.arrowLeft, ghost: true, onTap: back),
            const SizedBox(width: 12),
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: pct, minHeight: 7, backgroundColor: T.ink100, color: s.accent.main),
            )),
            const SizedBox(width: 12),
            SizedBox(width: 40, child: Text('${step + 1} ${s.t('step_of')} ${steps.length}',
                textAlign: TextAlign.center, style: Typo.num(size: FS.xs, weight: FontWeight.w600, color: T.fg3))),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: _stepBody(),
        )),
        // foot
        Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 38),
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x00FAFAF7), T.cream50])),
          child: Opacity(
            opacity: canNext ? 1 : 0.4,
            child: PButton(step == steps.length - 1 ? s.t('finish') : s.t('continue'),
                variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: s.rtl,
                onTap: canNext ? next : null),
          ),
        ),
      ]),
      ),
    );
  }

  Widget _title(String t, String h) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.t(t), style: Typo.title(ar: s.rtl).copyWith(fontSize: FS.xl2)),
        const SizedBox(height: 6),
        Text(s.t(h), style: Typo.body(ar: s.rtl).copyWith(color: T.fg3)),
        const SizedBox(height: 24),
      ]);

  Widget _stepBody() => switch (cur) {
        'mood' => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _title('q_mood_t', 'q_mood_h'),
            Row(children: [
              for (var lv = 1; lv <= 5; lv++)
                Expanded(child: Padding(
                  padding: EdgeInsets.only(right: lv < 5 ? 10 : 0),
                  child: _MoodCell(lv: lv, selected: mood == lv, s: s, onTap: () => setState(() => mood = lv)),
                )),
            ]),
          ]),
        'bp' => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _title('q_bp_t', 'q_bp_h'),
            Opacity(opacity: bpSkip ? 0.4 : 1, child: PCard(padding: const EdgeInsets.all(18), child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _vitalBox(bpSys.isEmpty ? '—' : bpSys, bpField == 'sys', () => setState(() => bpField = 'sys')),
                Text('/', style: Typo.display().copyWith(fontSize: FS.xl3, color: T.ink300)),
                _vitalBox(bpDia.isEmpty ? '—' : bpDia, bpField == 'dia', () => setState(() => bpField = 'dia')),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(s.t('sys'), style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: bpField == 'sys' ? s.accent.main : T.fg3)),
                const SizedBox(width: 60),
                Text(s.t('dia'), style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: bpField == 'dia' ? s.accent.main : T.fg3)),
              ]),
              const SizedBox(height: 4),
              Text(s.t('unit_bp'), style: Typo.body(ar: s.rtl).copyWith(color: T.fg3, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              NumPad(
                onKey: (d) => setState(() {
                  if (bpField == 'sys') {
                    if (bpSys.length < 3) bpSys += d;
                  } else if (bpDia.length < 3) {
                    bpDia += d;
                  }
                }),
                onBack: () => setState(() {
                  if (bpField == 'sys') {
                    if (bpSys.isNotEmpty) bpSys = bpSys.substring(0, bpSys.length - 1);
                  } else if (bpDia.isNotEmpty) {
                    bpDia = bpDia.substring(0, bpDia.length - 1);
                  }
                }),
              ),
            ]))),
            _skipRow(bpSkip, () => setState(() => bpSkip = !bpSkip)),
          ]),
        'glucose' => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _title('q_glu_t', 'q_glu_h'),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final c in const ['glu_fast', 'glu_meal', 'glu_random'])
                _chip(s.t(c), gluCtx == c, () => setState(() => gluCtx = c)),
            ]),
            const SizedBox(height: 16),
            Opacity(opacity: gluSkip ? 0.4 : 1, child: PCard(padding: const EdgeInsets.all(18), child: Column(children: [
              _vitalBox(glu.isEmpty ? '—' : glu, true, null, minWidth: 130),
              const SizedBox(height: 4),
              Text(s.t('unit_glu'), style: Typo.body(ar: s.rtl).copyWith(color: T.fg3, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              NumPad(
                onKey: (d) => setState(() { if (glu.length < 3) glu += d; }),
                onBack: () => setState(() { if (glu.isNotEmpty) glu = glu.substring(0, glu.length - 1); }),
              ),
            ]))),
            _skipRow(gluSkip, () => setState(() => gluSkip = !gluSkip)),
          ]),
        'meds' => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _title('q_med_t', 'q_med_h'),
            for (final m in kMeds) _medCheck(m),
          ]),
        _ => _symptomsStep(),
      };

  Widget _symptomsStep() {
    final pinfo = _painInfo(s, pain.round());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('q_sym_t', 'q_sym_h'),
      Center(child: Column(children: [
        Text('${pain.round()}', style: Typo.display().copyWith(fontSize: 64, color: pinfo.color, fontWeight: FontWeight.w800)),
        Text(pinfo.lbl, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
      ])),
      SliderTheme(
        data: SliderThemeData(activeTrackColor: pinfo.color, thumbColor: pinfo.color, inactiveTrackColor: T.ink100, trackHeight: 10),
        child: Slider(value: pain, min: 0, max: 10, divisions: 10, onChanged: (v) => setState(() => pain = v)),
      ),
      if (pain > 0 || syms.where((x) => x != 's_none').isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(s.t('body_location'), style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
        const SizedBox(height: 8),
        BodyMap(selected: painLocs, onToggle: (id) => setState(() => painLocs.contains(id) ? painLocs.remove(id) : painLocs.add(id))),
      ],
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (final (id, icon) in _symptoms)
          _chip(s.t(id), syms.contains(id), () => _toggleSym(id), icon: icon),
        _chip(s.t('s_none'), syms.contains('s_none'), () => _toggleSym('s_none'), icon: LucideIcons.checkCircle2),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(s.t('note_lbl'), style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
      ),
      TextField(
        controller: note, minLines: 3, maxLines: 5, textDirection: s.dir,
        style: Typo.body(ar: s.rtl).copyWith(color: T.fg1),
        decoration: InputDecoration(
          hintText: s.t('note_ph'), hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(14),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
        ),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(T.rMd),
          border: Border.all(color: T.borderStrong, width: 1.5),
        ),
        child: Row(children: [
          const Icon(LucideIcons.camera, size: 20, color: T.fg3),
          const SizedBox(width: 12),
          Text(s.t('add_photo'), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
        ]),
      ),
    ]);
  }

  void _toggleSym(String id) => setState(() {
        if (id == 's_none') { syms.clear(); syms.add('s_none'); return; }
        syms.remove('s_none');
        syms.contains(id) ? syms.remove(id) : syms.add(id);
      });

  Widget _vitalBox(String text, bool active, VoidCallback? onTap, {double minWidth = 90}) => GestureDetector(
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

  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? s.accent.bg : Colors.white,
            borderRadius: BorderRadius.circular(T.rPill),
            border: Border.all(color: selected ? s.accent.main : T.border, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: selected ? s.accent.d : T.fg2), const SizedBox(width: 7)],
            Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: selected ? s.accent.d : T.fg2)),
          ]),
        ),
      );

  Widget _skipRow(bool on, VoidCallback onTap) => Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: PButton(s.t('skip_q'), icon: on ? LucideIcons.checkCircle2 : LucideIcons.circle,
              variant: BtnVariant.ghost, accent: s.accent, ar: s.rtl, onTap: onTap),
        ),
      );

  Widget _medCheck(Med m) {
    final st = meds[m.id];
    final taken = st == 'taken';
    final skipped = st == 'skipped';
    return GestureDetector(
      onTap: () => setState(() => meds[m.id] = taken ? '' : 'taken'),
      child: Opacity(
        opacity: skipped ? 0.6 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: taken ? T.petalMint50 : Colors.white,
            borderRadius: BorderRadius.circular(T.rLg),
            border: Border.all(color: taken ? T.petalMint : T.border, width: 1.5),
          ),
          child: Row(children: [
            Container(width: 30, height: 30, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: taken ? T.petalMint : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: taken ? T.petalMint : T.borderStrong, width: 2)),
                child: taken ? const Icon(LucideIcons.check, size: 18, color: Colors.white) : null),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name.of(s.lang), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              Text(m.dose.of(s.lang), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ])),
            if (skipped)
              Pill(s.t('skipped'), kind: PillKind.neutral, ar: s.rtl)
            else
              GestureDetector(
                onTap: () => setState(() => meds[m.id] = 'skipped'),
                child: Padding(padding: const EdgeInsets.all(8),
                    child: Text(s.t('mark_skip'), style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600))),
              ),
          ]),
        ),
      ),
    );
  }
}

class _MoodCell extends StatelessWidget {
  const _MoodCell({required this.lv, required this.selected, required this.s, required this.onTap});
  final int lv;
  final bool selected;
  final PatientAppState s;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: selected ? s.accent.bg : Colors.white,
              borderRadius: BorderRadius.circular(T.rLg),
              border: Border.all(color: selected ? s.accent.main : T.border, width: 1.5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              MoodFace(level: lv, size: 32, color: selected ? kMoodColors[lv - 1] : T.ink400),
              const SizedBox(height: 6),
              Text(s.t('mood_$lv'), style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs2, fontWeight: FontWeight.w600, color: selected ? s.accent.d : T.fg3)),
            ]),
          ),
        ),
      );
}

// ── Summary ──────────────────────────────────────────────────
class _Summary extends StatelessWidget {
  const _Summary({required this.state});
  final _ReportFlowState state;
  @override
  Widget build(BuildContext context) {
    final s = state.s;
    final taken = kMeds.where((m) => state.meds[m.id] == 'taken').length;
    final symList = state.syms.where((x) => x != 's_none').map((x) => s.t(x)).toList();
    final pinfo = _painInfo(s, state.pain.round());
    final items = <(IconData, PillKind, String, String)>[
      (LucideIcons.smile, PillKind.info, s.t('m_mood'), state.mood > 0 ? s.t('mood_${state.mood}') : '—'),
      if (!state.bpSkip) (LucideIcons.activity, PillKind.violet, s.t('m_bp'), '${state.bpSys}/${state.bpDia} ${s.t('unit_bp')}'),
      if (!state.gluSkip && state.glu.isNotEmpty) (LucideIcons.droplet, PillKind.success, '${s.t('m_glucose')} · ${s.t(state.gluCtx)}', '${state.glu} ${s.t('unit_glu')}'),
      (LucideIcons.pill, PillKind.info, s.t('meds_today'), '$taken/${kMeds.length} ${s.t('meds_taken')}'),
      (LucideIcons.thermometer, PillKind.warn, s.t('m_pain'), '${state.pain.round()}/10 · ${pinfo.lbl}'),
      if (symList.isNotEmpty) (LucideIcons.stethoscope, PillKind.neutral, s.t('q_sym_t'), symList.join(s.rtl ? '، ' : ', ')),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: ContentColumn(
        maxWidth: 480,
        child: Column(children: [
        const PadTop(),
        Expanded(child: SingleChildScrollView(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 8),
            child: Column(children: [
              Container(width: 88, height: 88, alignment: Alignment.center,
                  decoration: const BoxDecoration(color: T.petalMint50, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.check, size: 44, color: T.petalMint600)),
              const SizedBox(height: 18),
              Text(s.t('saved_t'), style: Typo.title(ar: s.rtl)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rPill)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.cloudOff, size: 15, color: T.fg3),
                  const SizedBox(width: 8),
                  Text(s.t('saved_local'), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              for (var i = 0; i < items.length; i++) _summaryItem(s, items[i], last: i == items.length - 1),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(children: [
              const Icon(LucideIcons.send, size: 15, color: T.fg3),
              const SizedBox(width: 8),
              Expanded(child: Text(s.t('to_doctor'), style: Typo.meta(ar: s.rtl))),
            ]),
          ),
          const SizedBox(height: 16),
        ]))),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 38),
          child: Row(children: [
            Expanded(child: PButton(s.t('view_trends'), variant: BtnVariant.secondary, large: true, block: true, ar: s.rtl, onTap: () => state._finish('trends'))),
            const SizedBox(width: 12),
            Expanded(child: PButton(s.t('to_home'), variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: s.rtl, onTap: () => state._finish('home'))),
          ]),
        ),
      ]),
      ),
    );
  }

  Widget _summaryItem(PatientAppState s, (IconData, PillKind, String, String) it, {required bool last}) {
    final c = switch (it.$2) {
      PillKind.info => (bg: T.petalBlue50, fg: T.petalBlue),
      PillKind.violet => (bg: T.petalViolet50, fg: T.petalViolet),
      PillKind.success => (bg: T.petalMint50, fg: T.petalMint600),
      PillKind.warn => (bg: const Color(0xFFFDF5DC), fg: T.sun600),
      _ => (bg: T.ink100, fg: T.ink600),
    };
    return Container(
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: T.ink100))),
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(children: [
        IconSquare(it.$1, bg: c.bg, fg: c.fg, size: 40, iconSize: 20),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(it.$3, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          Text(it.$4, style: Typo.subhead(ar: s.rtl).copyWith(fontSize: FS.md)),
        ])),
      ]),
    );
  }
}
