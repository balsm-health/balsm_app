import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:core/core.dart' show currentProfileIdProvider;
import 'package:medications/medications.dart'
    show
        Medication,
        DoseOutcome,
        medicationListProvider,
        recordDoseOutcomeUseCaseProvider;
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../shell.dart' show AdaptiveFrame;
import '../widgets/mood_face.dart';
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

/// MoodFace stroke color per level (1 = rough … 5 = great).
const _moodColors = <Color>[
  T.danger,
  Color(0xFFD97A20),
  T.sun600,
  T.petalMint,
  T.petalMint600,
];

/// The self-report symptom catalog paired with its display icon. Ids come from
/// the module's [SymptomId] catalog; icons are presentation-only.
const _symptomIcons = <(SymptomId, IconData)>[
  (SymptomId.headache, LucideIcons.brain),
  (SymptomId.dizzy, LucideIcons.rotateCw),
  (SymptomId.fatigue, LucideIcons.batteryLow),
  (SymptomId.blurredVision, LucideIcons.eye),
  (SymptomId.swelling, LucideIcons.droplet),
  (SymptomId.chestTightness, LucideIcons.heartPulse),
  (SymptomId.nausea, LucideIcons.frown),
  (SymptomId.thirst, LucideIcons.cupSoda),
];

/// i69n key for a symptom label. The module's ids are camelCase
/// (`blurredVision`); the app's flat keys are snake_case (`sym_blurred_vision`).
String symptomLabelKey(SymptomId id) => 'checkin.sym_${_snakeCase(id.id)}';

String _snakeCase(String v) =>
    v.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

({String lbl, Color color}) _painInfo(PatientAppState s, int n) {
  if (n == 0) return (lbl: s.t('checkin.pain_0'), color: T.petalMint);
  if (n <= 3) return (lbl: s.t('checkin.pain_mild'), color: T.petalMint600);
  if (n <= 6) return (lbl: s.t('checkin.pain_mod'), color: T.sun600);
  if (n <= 9) return (lbl: s.t('checkin.pain_sev'), color: const Color(0xFFD97A20));
  return (lbl: s.t('checkin.pain_worst'), color: T.danger);
}

/// Full daily check-in wizard, on the real self-report module. Captures mood,
/// vitals, medication adherence (only when the profile has medications), pain +
/// body regions, symptoms, and a note, then persists a [CheckIn] on-device and
/// records any med marks as real dose events. PHI: check-in contents are never
/// logged.
class ReportFlow extends ConsumerStatefulWidget {
  const ReportFlow({super.key, required this.s});
  final PatientAppState s;
  @override
  ConsumerState<ReportFlow> createState() => _ReportFlowState();
}

class _ReportFlowState extends ConsumerState<ReportFlow> {
  int step = 0;
  bool submitted = false;
  bool saving = false;

  int mood = 0;

  // Vitals — every field optional; an empty field maps to null.
  final sysCtrl = TextEditingController();
  final diaCtrl = TextEditingController();
  final hrCtrl = TextEditingController();
  final tempCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final spo2Ctrl = TextEditingController();
  final gluCtrl = TextEditingController();
  String gluCtx = 'checkin.glu_fast'; // glu_fast | glu_meal | glu_random

  double pain = 0;
  final Set<SymptomId> syms = {};
  bool noSymptoms = false;
  final Set<String> painLocs = {};
  final note = TextEditingController();

  /// Medication adherence marks captured in the meds step, keyed by med id:
  /// '' | 'taken' | 'skipped'.
  final Map<String, String> medMarks = {};

  // Refreshed each build from the reactive providers.
  List<Medication> _meds = const [];
  List<String> _steps = const ['mood', 'vitals', 'symptoms'];

  PatientAppState get s => widget.s;
  String get cur => _steps[step];

  @override
  void dispose() {
    sysCtrl.dispose();
    diaCtrl.dispose();
    hrCtrl.dispose();
    tempCtrl.dispose();
    weightCtrl.dispose();
    spo2Ctrl.dispose();
    gluCtrl.dispose();
    note.dispose();
    super.dispose();
  }

  bool get canNext => switch (cur) {
        'mood' => mood > 0,
        _ => true,
      };

  void next() {
    if (step < _steps.length - 1) {
      setState(() => step++);
    } else {
      _finish();
    }
  }

  void back() {
    if (step > 0) {
      setState(() => step--);
    } else {
      Navigator.pop(context);
    }
  }

  int? _parseInt(TextEditingController c) => int.tryParse(c.text.trim());
  double? _parseDouble(TextEditingController c) => double.tryParse(c.text.trim());

  Vitals _buildVitals() {
    final glucose = _parseInt(gluCtrl);
    return Vitals(
      systolic: _parseInt(sysCtrl),
      diastolic: _parseInt(diaCtrl),
      heartRate: _parseInt(hrCtrl),
      temperature: _parseDouble(tempCtrl),
      weightKg: _parseDouble(weightCtrl),
      spo2: _parseInt(spo2Ctrl),
      glucoseFasting: gluCtx == 'checkin.glu_fast' ? glucose : null,
      glucosePostMeal: gluCtx == 'checkin.glu_meal' ? glucose : null,
      glucoseRandom: gluCtx == 'checkin.glu_random' ? glucose : null,
    );
  }

  /// Persists the check-in on-device and records med marks as real dose events.
  /// Never logs the captured PHI.
  Future<void> _finish() async {
    if (saving) return;
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) return; // finish is disabled while signed out
    setState(() => saving = true);

    final noteText = note.text.trim();
    final checkIn = CheckIn(
      id: CheckInId.uuid(),
      healthProfileId: profileId,
      recordedAt: DateTime.now(),
      mood: Mood(mood),
      painLevel: PainLevel(pain.round()),
      painRegions:
          painLocs.map(BodyRegion.fromId).whereType<BodyRegion>().toSet(),
      symptoms: syms.toSet(),
      vitals: _buildVitals(),
      note: noteText.isEmpty ? null : noteText,
    );
    await ref.read(saveCheckInUseCaseProvider).call(checkIn);

    // Any med the patient marked taken/skipped is recorded as a real (append-
    // only) dose event via the medications module — on-device, never synced.
    final meds =
        ref.read(medicationListProvider).valueOrNull ?? const <Medication>[];
    final recordDose = ref.read(recordDoseOutcomeUseCaseProvider);
    final now = DateTime.now();
    for (final med in meds) {
      final outcome = switch (medMarks[med.id.value]) {
        'taken' => DoseOutcome.taken,
        'skipped' => DoseOutcome.skipped,
        _ => null,
      };
      if (outcome == null) continue;
      await recordDose.call(
        medicationId: med.id,
        scheduledAt: now,
        outcome: outcome,
      );
    }

    if (!mounted) return;
    ref.invalidate(medicationListProvider);
    setState(() {
      saving = false;
      submitted = true;
    });
  }

  void _close(String tab) {
    Navigator.pop(context);
    s.setTab(tab);
  }

  @override
  Widget build(BuildContext context) {
    _meds = ref.watch(medicationListProvider).valueOrNull ?? const [];
    _steps = [
      'mood',
      'vitals',
      if (_meds.isNotEmpty) 'meds',
      'symptoms',
    ];
    if (step > _steps.length - 1) step = _steps.length - 1;

    if (submitted) return _Summary(state: this);

    final isLast = step == _steps.length - 1;
    final profileId = ref.watch(currentProfileIdProvider);
    final canFinish = profileId != null && !saving;
    final enabled = isLast ? canFinish : canNext;
    final pct = (step + 1) / _steps.length;

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
              RoundBtn(
                  icon: step == 0 ? LucideIcons.x : LucideIcons.arrowLeft,
                  ghost: true,
                  onTap: back),
              const SizedBox(width: 12),
              Expanded(child: LinearProgress(value: pct, color: s.accent.main)),
              const SizedBox(width: 12),
              SizedBox(
                  width: 40,
                  child: Text('${step + 1} ${s.t('common.step_of')} ${_steps.length}',
                      textAlign: TextAlign.center,
                      style: Typo.num(
                          size: FS.xs,
                          weight: FontWeight.w600,
                          color: T.fg3))),
            ]),
          ),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: RiseIn(key: ValueKey(cur), child: _stepBody()),
          )),
          // foot
          Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 38),
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00FAFAF7), T.cream50])),
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: PButton(
                  isLast
                      ? (saving ? '…' : s.t('common.finish'))
                      : s.t('continue'),
                  variant: BtnVariant.primary,
                  large: true,
                  block: true,
                  accent: s.accent,
                  ar: s.rtl,
                  onTap: enabled ? next : null),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _title(String t, String h) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.t(t), style: Typo.title(ar: s.rtl).copyWith(fontSize: FS.xl2)),
        const SizedBox(height: 6),
        Text(s.t(h), style: Typo.body(ar: s.rtl).copyWith(color: T.fg3)),
        const SizedBox(height: 24),
      ]);

  Widget _stepBody() => switch (cur) {
        'mood' =>
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _title(s.g(s.strings.checkin.q_mood_t_select), 'checkin.q_mood_h'),
            Row(
                children: List.generate(
                    5,
                    (i) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i < 4 ? 10 : 0),
                            child: _MoodCell(
                                lv: i + 1,
                                selected: mood == i + 1,
                                s: s,
                                onTap: () => setState(() => mood = i + 1)),
                          ),
                        ))),
          ]),
        'vitals' => _vitalsStep(),
        'meds' =>
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _title('checkin.q_med_t', 'checkin.q_med_h'),
            ..._meds.map(_medCheck),
          ]),
        _ => _symptomsStep(),
      };

  Widget _vitalsStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title('checkin.q_vitals_t', 'checkin.q_vitals_h'),
        PCard(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Expanded(child: _vitalField(s.t('checkin.sys'), sysCtrl, s.t('checkin.unit_bp'))),
                const SizedBox(width: 12),
                Expanded(child: _vitalField(s.t('checkin.dia'), diaCtrl, s.t('checkin.unit_bp'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _vitalField(s.t('checkin.vital_hr'), hrCtrl, s.t('checkin.unit_hr'))),
                const SizedBox(width: 12),
                Expanded(
                    child: _vitalField(s.t('checkin.vital_temp'), tempCtrl,
                        s.t('checkin.unit_temp'),
                        decimal: true)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _vitalField(
                        s.strings.profile.pd_weight, weightCtrl, s.strings.profile.pd_kg,
                        decimal: true)),
                const SizedBox(width: 12),
                Expanded(
                    child: _vitalField(s.t('checkin.vital_spo2'), spo2Ctrl,
                        s.t('checkin.unit_spo2'))),
              ]),
            ])),
        const SizedBox(height: 16),
        Text(s.t('profile.m_glucose'),
            style: Typo.bodySm(ar: s.rtl)
                .copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
        const SizedBox(height: 10),
        Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const ['checkin.glu_fast', 'checkin.glu_meal', 'checkin.glu_random']
                .map((c) =>
                    _chip(s.t(c), gluCtx == c, () => setState(() => gluCtx = c)))
                .toList()),
        const SizedBox(height: 12),
        PCard(
            padding: const EdgeInsets.all(16),
            child: _vitalField(s.t('profile.m_glucose'), gluCtrl, s.t('checkin.unit_glu'))),
      ]);

  Widget _vitalField(String label, TextEditingController c, String unit,
          {bool decimal = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: Typo.meta(ar: s.rtl).copyWith(
                fontSize: FS.xs2,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: T.fg3)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          style: Typo.num(size: FS.lg),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            suffixText: unit,
            suffixStyle: Typo.meta(ar: s.rtl),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(T.rMd),
                borderSide: const BorderSide(color: T.border, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(T.rMd),
                borderSide: BorderSide(color: s.accent.main, width: 1.5)),
          ),
        ),
      ]);

  Widget _symptomsStep() {
    final pinfo = _painInfo(s, pain.round());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _title('checkin.q_sym_t', s.g(s.strings.checkin.q_sym_h_select)),
      Center(
          child: Column(children: [
        Text('${pain.round()}',
            style: Typo.display().copyWith(
                fontSize: 64, color: pinfo.color, fontWeight: FontWeight.w800)),
        Text(pinfo.lbl,
            style: Typo.body(ar: s.rtl)
                .copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
      ])),
      SliderTheme(
        data: SliderThemeData(
            activeTrackColor: pinfo.color,
            thumbColor: pinfo.color,
            inactiveTrackColor: T.ink100,
            trackHeight: 10),
        child: Slider(
            value: pain,
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (v) => setState(() => pain = v)),
      ),
      if (pain > 0 || syms.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(s.t('checkin.body_location'),
            style: Typo.bodySm(ar: s.rtl)
                .copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
        const SizedBox(height: 8),
        BodyMap(
            selected: painLocs,
            onToggle: (id) => setState(() => painLocs.contains(id)
                ? painLocs.remove(id)
                : painLocs.add(id))),
      ],
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        ..._symptomIcons.map((e) => _chip(
            s.t(symptomLabelKey(e.$1)), syms.contains(e.$1),
            () => _toggleSym(e.$1),
            icon: e.$2)),
        _chip(s.t('checkin.s_none'), noSymptoms, _toggleNone,
            icon: LucideIcons.checkCircle2),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(s.t('checkin.note_lbl'),
            style: Typo.bodySm(ar: s.rtl)
                .copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
      ),
      TextField(
        controller: note,
        minLines: 3,
        maxLines: 5,
        textDirection: s.dir,
        style: Typo.body(ar: s.rtl).copyWith(color: T.fg1),
        decoration: InputDecoration(
          hintText: s.t('checkin.note_ph'),
          hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(14),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd),
              borderSide: const BorderSide(color: T.border, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd),
              borderSide: BorderSide(color: s.accent.main, width: 1.5)),
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
          Text(s.t('settings.add_photo'),
              style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
        ]),
      ),
    ]);
  }

  void _toggleSym(SymptomId id) => setState(() {
        noSymptoms = false;
        syms.contains(id) ? syms.remove(id) : syms.add(id);
      });

  void _toggleNone() => setState(() {
        noSymptoms = !noSymptoms;
        if (noSymptoms) syms.clear();
      });

  // `.chip` — border/bg/color animate over --dur-base ease-out.
  Widget _chip(String label, bool selected, VoidCallback onTap,
          {IconData? icon}) =>
      Pressable(
        onTap: onTap,
        scale: 0.97,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? s.accent.bg : Colors.white,
            borderRadius: BorderRadius.circular(T.rPill),
            border: Border.all(
                color: selected ? s.accent.main : T.border, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? s.accent.d : T.fg2),
              const SizedBox(width: 7)
            ],
            Text(label,
                style: Typo.bodySm(ar: s.rtl).copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? s.accent.d : T.fg2)),
          ]),
        ),
      );

  Widget _medCheck(Medication m) {
    final st = medMarks[m.id.value] ?? '';
    final taken = st == 'taken';
    final skipped = st == 'skipped';
    final subtitle = m.doseAmount;
    return GestureDetector(
      onTap: () =>
          setState(() => medMarks[m.id.value] = taken ? '' : 'taken'),
      // `.check-row` + `.check-box` — border/bg animate over --dur-base.
      child: AnimatedOpacity(
        duration: Motion.base,
        curve: Motion.easeOut,
        opacity: skipped ? 0.6 : 1,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.easeOut,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: taken ? T.petalMint50 : Colors.white,
            borderRadius: BorderRadius.circular(T.rLg),
            border: Border.all(
                color: taken ? T.petalMint : T.border, width: 1.5),
          ),
          child: Row(children: [
            AnimatedContainer(
                duration: Motion.base,
                curve: Motion.easeOut,
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: taken ? T.petalMint : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: taken ? T.petalMint : T.borderStrong,
                        width: 2)),
                child: taken
                    ? const Icon(LucideIcons.check, size: 18, color: Colors.white)
                    : null),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(m.name,
                      style: Typo.body(ar: s.rtl).copyWith(
                          fontWeight: FontWeight.w600, color: T.fg1)),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(subtitle,
                        style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                ])),
            if (skipped)
              Pill(s.t('meds.skipped'), kind: PillKind.neutral, ar: s.rtl)
            else
              GestureDetector(
                onTap: () => setState(() => medMarks[m.id.value] = 'skipped'),
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(s.t('meds.mark_skip'),
                        style: Typo.meta(ar: s.rtl)
                            .copyWith(fontWeight: FontWeight.w600))),
              ),
          ]),
        ),
      ),
    );
  }
}

class _MoodCell extends StatelessWidget {
  const _MoodCell(
      {required this.lv,
      required this.selected,
      required this.s,
      required this.onTap});
  final int lv;
  final bool selected;
  final PatientAppState s;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        // `.mood.sel` — bg/border animate + lift translateY(-2px), --dur-base.
        child: AspectRatio(
          aspectRatio: 1,
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.easeOut,
            transform: Matrix4.translationValues(0, selected ? -2 : 0, 0),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? s.accent.bg : Colors.white,
              borderRadius: BorderRadius.circular(T.rLg),
              border: Border.all(
                  color: selected ? s.accent.main : T.border, width: 1.5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              MoodFace(
                  level: lv,
                  size: 32,
                  color: selected ? _moodColors[lv - 1] : T.ink400),
              const SizedBox(height: 6),
              Text(s.t('checkin.mood_$lv'),
                  style: Typo.meta(ar: s.rtl).copyWith(
                      fontSize: FS.xs2,
                      fontWeight: FontWeight.w600,
                      color: selected ? s.accent.d : T.fg3)),
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
    final vitals = state._buildVitals();
    final glucose = vitals.glucoseFasting ??
        vitals.glucosePostMeal ??
        vitals.glucoseRandom;
    final taken = state._meds
        .where((m) => state.medMarks[m.id.value] == 'taken')
        .length;
    final symList =
        state.syms.map((sym) => s.t(symptomLabelKey(sym))).toList();
    final pinfo = _painInfo(s, state.pain.round());
    final items = <(IconData, PillKind, String, String)>[
      (
        LucideIcons.smile,
        PillKind.info,
        s.t('profile.m_mood'),
        state.mood > 0 ? s.t('checkin.mood_${state.mood}') : '—'
      ),
      if (vitals.systolic != null && vitals.diastolic != null)
        (
          LucideIcons.activity,
          PillKind.violet,
          s.t('profile.m_bp'),
          '${vitals.systolic}/${vitals.diastolic} ${s.t('checkin.unit_bp')}'
        ),
      if (glucose != null)
        (
          LucideIcons.droplet,
          PillKind.success,
          '${s.t('profile.m_glucose')} · ${s.t(state.gluCtx)}',
          '$glucose ${s.t('checkin.unit_glu')}'
        ),
      if (state._meds.isNotEmpty)
        (
          LucideIcons.pill,
          PillKind.info,
          s.t('meds.meds_today'),
          '$taken/${state._meds.length} ${s.t('meds.meds_taken')}'
        ),
      (
        LucideIcons.thermometer,
        PillKind.warn,
        s.t('profile.m_pain'),
        '${state.pain.round()}/10 · ${pinfo.lbl}'
      ),
      if (symList.isNotEmpty)
        (
          LucideIcons.stethoscope,
          PillKind.neutral,
          s.t('checkin.q_sym_t'),
          symList.join(s.rtl ? '، ' : ', ')
        ),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: ContentColumn(
        maxWidth: 480,
        child: Column(children: [
          const PadTop(),
          Expanded(
              child: SingleChildScrollView(
                  child: Column(children: [
            RiseIn(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 8),
              child: Column(children: [
                Container(
                    width: 88,
                    height: 88,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: T.petalMint50, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.check,
                        size: 44, color: T.petalMint600)),
                const SizedBox(height: 18),
                Text(s.t('common.saved_t'), style: Typo.title(ar: s.rtl)),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: T.ink50,
                      borderRadius: BorderRadius.circular(T.rPill)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(LucideIcons.cloudOff, size: 15, color: T.fg3),
                    const SizedBox(width: 8),
                    Text(s.t('common.saved_local'),
                        style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                  ]),
                ),
              ]),
            )),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                  children: items.indexed
                      .map((e) => _summaryItem(s, e.$2,
                          last: e.$1 == items.length - 1))
                      .toList()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(children: [
                const Icon(LucideIcons.send, size: 15, color: T.fg3),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(s.t('care.to_doctor'), style: Typo.meta(ar: s.rtl))),
              ]),
            ),
            const SizedBox(height: 16),
          ]))),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 38),
            child: Row(children: [
              Expanded(
                  child: PButton(s.t('checkin.view_trends'),
                      variant: BtnVariant.secondary,
                      large: true,
                      block: true,
                      ar: s.rtl,
                      onTap: () => state._close('trends'))),
              const SizedBox(width: 12),
              Expanded(
                  child: PButton(s.t('care.to_home'),
                      variant: BtnVariant.primary,
                      large: true,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: () => state._close('home'))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _summaryItem(
      PatientAppState s, (IconData, PillKind, String, String) it,
      {required bool last}) {
    final c = switch (it.$2) {
      PillKind.info => (bg: T.petalBlue50, fg: T.petalBlue),
      PillKind.violet => (bg: T.petalViolet50, fg: T.petalViolet),
      PillKind.success => (bg: T.petalMint50, fg: T.petalMint600),
      PillKind.warn => (bg: const Color(0xFFFDF5DC), fg: T.sun600),
      _ => (bg: T.ink100, fg: T.ink600),
    };
    return Container(
      decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: T.ink100))),
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(children: [
        IconSquare(it.$1, bg: c.bg, fg: c.fg, size: 40, iconSize: 20),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(it.$3,
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
              Text(it.$4,
                  style: Typo.subhead(ar: s.rtl).copyWith(fontSize: FS.md)),
            ])),
      ]),
    );
  }
}
