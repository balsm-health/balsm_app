import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:core/core.dart' show currentProfileIdProvider;
import 'package:medications/medications.dart'
    show Medication, DoseOutcome, medicationListProvider, recordDoseOutcomeUseCaseProvider;
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../shell.dart' show AdaptiveFrame;
import 'metric_log.dart';

export 'checkin_shared.dart' show MoodCell, moodColors, painInfo, symptomIcons, symptomLabel;

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

/// Full daily check-in wizard, on the real self-report module. Pages come
/// from [trackedCheckInMetricsProvider] (catalog defaults until the patient
/// can pick metrics) plus a medications page when the profile has meds.
///
/// Every metric page is the same one-metric log template used by quick-log.
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

  /// Medication adherence marks captured in the meds step, keyed by med id:
  /// '' | 'taken' | 'skipped'.
  final Map<String, String> medMarks = {};

  final Map<String, MetricLogCapture> _captures = {};
  final Map<String, bool> _valid = {};

  /// Steps the patient marked "I didn't measure this today" (`SkipRow`). A
  /// skipped step contributes nothing to the check-in and never blocks Next.
  final Set<String> _skipped = {};

  // Refreshed each build from the reactive providers.
  List<Medication> _meds = const [];
  List<String> _steps = const [];

  PatientAppState get s => widget.s;
  String get cur => (step >= 0 && step < _steps.length) ? _steps[step] : '';

  bool get canNext {
    if (cur == kMedsCheckInStepId) return true;
    if (_skipped.contains(cur)) return true;
    return _valid[cur] == true;
  }

  /// Measurements the patient may simply not have taken today. The design
  /// offers `SkipRow` under blood pressure and glucose; weight is the same
  /// class of reading.
  static final _skippable = {CheckInMetric.bloodPressure, CheckInMetric.glucose, CheckInMetric.weight};

  void _toggleSkip(String id) => setState(() {
        if (_skipped.remove(id)) return;
        _skipped.add(id);
        // Anything already typed is discarded — a skipped reading must not
        // reach the check-in or the summary.
        _captures.remove(id);
        _valid.remove(id);
      });

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

  void _onCapture(String id, MetricLogCapture capture, {required bool valid}) {
    if (_skipped.contains(id)) return;
    setState(() {
      _captures[id] = capture;
      _valid[id] = valid;
    });
  }

  Vitals _mergedVitals() {
    var out = Vitals.empty;
    for (final id in _steps) {
      final v = _captures[id]?.vitals;
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

  /// Persists the check-in on-device and records med marks as real dose events.
  /// Never logs the captured PHI.
  Future<void> _finish() async {
    if (saving) return;
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) return;
    setState(() => saving = true);

    Mood? mood;
    var painLevel = PainLevel.none;
    final painSites = <PainSite>{};
    final symptoms = <SymptomId>{};
    final notes = <String>[];

    for (final id in _steps) {
      if (id == kMedsCheckInStepId) continue;
      final c = _captures[id];
      if (c == null) continue;
      mood ??= c.mood;
      if (c.painLevel.value > painLevel.value) painLevel = c.painLevel;
      painSites.addAll(c.painSites);
      symptoms.addAll(c.symptoms);
      final n = c.note?.trim();
      if (n != null && n.isNotEmpty) notes.add(n);
    }

    final checkIn = CheckIn(
      id: CheckInId.uuid(),
      healthProfileId: profileId,
      recordedAt: DateTime.now(),
      mood: mood,
      painLevel: painLevel,
      painSites: painSites,
      symptoms: symptoms,
      vitals: _mergedVitals(),
      note: notes.isEmpty ? null : notes.join('\n'),
    );
    await ref.read(saveCheckInUseCaseProvider).call(checkIn);

    final meds = ref.read(medicationListProvider).valueOrNull ?? const <Medication>[];
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
    _steps = fullCheckInSteps(
      tracked: ref.watch(trackedCheckInMetricsProvider),
      hasMeds: _meds.isNotEmpty,
    );
    if (_steps.isEmpty) {
      _steps = fullCheckInSteps(
        tracked: CheckInMetric.defaultFullCheckup,
        hasMeds: _meds.isNotEmpty,
      );
    }
    if (step >= _steps.length) step = _steps.isEmpty ? 0 : _steps.length - 1;

    if (submitted) return _Summary(state: this);

    final isLast = step == _steps.length - 1;
    final profileId = ref.watch(currentProfileIdProvider);
    final canFinish = profileId != null && !saving;
    final enabled = isLast ? (canFinish && canNext) : canNext;
    final pct = _steps.isEmpty ? 1.0 : (step + 1) / _steps.length;

    return Scaffold(
      backgroundColor: T.cream50,
      body: ContentColumn(
        maxWidth: 480,
        child: Column(children: [
          const PadTop(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(children: [
              RoundBtn(icon: step == 0 ? LucideIcons.x : backArrow(context), ghost: true, onTap: back),
              const SizedBox(width: 12),
              Expanded(child: LinearProgress(value: pct, color: s.accent.main)),
              const SizedBox(width: 12),
              SizedBox(
                  width: 40,
                  child: Text('${step + 1} ${s.strings.common.step_of} ${_steps.length}',
                      textAlign: TextAlign.center,
                      style: Typo.num(size: FS.xs, weight: FontWeight.w600, color: T.fg3))),
            ]),
          ),
          Expanded(
            child: IndexedStack(
              index: _steps.isEmpty ? 0 : step,
              children: [
                for (final id in _steps)
                  SingleChildScrollView(
                    key: ValueKey(id),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: _stepBody(id),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 38),
            // `.flow-foot` reaches solid cream by 30% and stays there, so the
            // button never floats over half-transparent content.
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.3],
                    colors: [Color(0x00FAFAF7), T.cream50])),
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: PButton(isLast ? (saving ? '…' : s.strings.common.finish) : s.strings.common.continue_,
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

  Widget _title(String t, String h) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: Typo.title(ar: s.rtl).copyWith(fontSize: FS.xl2)),
        const SizedBox(height: 6),
        Text(h, style: Typo.body(ar: s.rtl).copyWith(color: T.fg3)),
        const SizedBox(height: 24),
      ]);

  Widget _stepBody(String id) {
    if (id == kMedsCheckInStepId) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(s.strings.checkin.q_med_t, s.strings.checkin.q_med_h),
        ..._meds.map(_medCheck),
      ]);
    }
    final metric = CheckInMetric.fromId(id);
    if (metric == null) return const SizedBox.shrink();
    final log = MetricLog(
      metric: metric,
      s: s,
      host: MetricLogHost.embedded,
      onChanged: (capture, {required valid}) => _onCapture(id, capture, valid: valid),
    );
    if (!_skippable.contains(metric)) return log;
    final skipped = _skipped.contains(id);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // `.card.is-disabled { opacity: .4 }` while the step is skipped.
      IgnorePointer(
        ignoring: skipped,
        child: AnimatedOpacity(
          opacity: skipped ? 0.4 : 1,
          duration: Motion.base,
          curve: Motion.easeOut,
          child: log,
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Center(
          child: PButton(s.strings.meds.skip_q,
              icon: skipped ? LucideIcons.checkCircle2 : LucideIcons.circle,
              variant: BtnVariant.ghost,
              accent: s.accent,
              ar: s.rtl,
              onTap: () => _toggleSkip(id)),
        ),
      ),
    ]);
  }

  Widget _medCheck(Medication m) {
    final st = medMarks[m.id.value] ?? '';
    final taken = st == 'taken';
    final skipped = st == 'skipped';
    final subtitle = m.doseAmount;
    return GestureDetector(
      onTap: () => setState(() => medMarks[m.id.value] = taken ? '' : 'taken'),
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
            border: Border.all(color: taken ? T.petalMint : T.border, width: 1.5),
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
                    border: Border.all(color: taken ? T.petalMint : T.borderStrong, width: 2)),
                child: taken ? const Icon(LucideIcons.check, size: 18, color: Colors.white) : null),
            const SizedBox(width: 14),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(subtitle, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ])),
            if (skipped)
              Pill(s.strings.meds.skipped, kind: PillKind.neutral, ar: s.rtl)
            else
              GestureDetector(
                onTap: () => setState(() => medMarks[m.id.value] = 'skipped'),
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(s.strings.meds.mark_skip,
                        style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600))),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Summary ──────────────────────────────────────────────────
class _Summary extends StatelessWidget {
  const _Summary({required this.state});
  final _ReportFlowState state;
  @override
  Widget build(BuildContext context) {
    final s = state.s;
    final taken = state._meds.where((m) => state.medMarks[m.id.value] == 'taken').length;
    final items = <(IconData, PillKind, String, String)>[
      for (final id in state._steps)
        if (id == kMedsCheckInStepId)
          (
            LucideIcons.pill,
            PillKind.info,
            s.strings.meds.meds_today,
            '$taken/${state._meds.length} ${s.strings.meds.meds_taken}'
          )
        else if (state._captures[id] case final c? when c.summary.isNotEmpty)
          (
            _summaryIcon(id).$1,
            _summaryIcon(id).$2,
            _summaryLabel(s, id),
            c.summary,
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
                    decoration: const BoxDecoration(color: T.petalMint50, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.check, size: 44, color: T.petalMint600)),
                const SizedBox(height: 18),
                Text(s.strings.common.saved_t, style: Typo.title(ar: s.rtl)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rPill)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(LucideIcons.cloudOff, size: 15, color: T.fg3),
                    const SizedBox(width: 8),
                    Text(s.strings.common.saved_local, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                  ]),
                ),
              ]),
            )),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                  children: items.indexed.map((e) => _summaryItem(s, e.$2, last: e.$1 == items.length - 1)).toList()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(children: [
                const Icon(LucideIcons.send, size: 15, color: T.fg3),
                const SizedBox(width: 8),
                Expanded(child: Text(s.strings.care.to_doctor, style: Typo.meta(ar: s.rtl))),
              ]),
            ),
            const SizedBox(height: 16),
          ]))),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 38),
            child: Row(children: [
              Expanded(
                  child: PButton(s.strings.checkin.view_trends,
                      variant: BtnVariant.secondary,
                      large: true,
                      block: true,
                      ar: s.rtl,
                      onTap: () => state._close('trends'))),
              const SizedBox(width: 12),
              Expanded(
                  child: PButton(s.strings.care.to_home,
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
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(it.$3, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          Text(it.$4, style: Typo.subhead(ar: s.rtl).copyWith(fontSize: FS.md)),
        ])),
      ]),
    );
  }
}

(IconData, PillKind) _summaryIcon(String id) {
  final metric = CheckInMetric.fromId(id);
  if (metric == CheckInMetric.mood) return (LucideIcons.smile, PillKind.info);
  if (metric == CheckInMetric.bloodPressure) return (LucideIcons.activity, PillKind.violet);
  if (metric == CheckInMetric.glucose) return (LucideIcons.droplet, PillKind.success);
  if (metric == CheckInMetric.weight) return (LucideIcons.scale, PillKind.info);
  if (metric == CheckInMetric.pain) return (LucideIcons.zap, PillKind.warn);
  if (metric == CheckInMetric.symptoms) return (LucideIcons.stethoscope, PillKind.neutral);
  return (LucideIcons.activity, PillKind.neutral);
}

String _summaryLabel(PatientAppState s, String id) {
  final metric = CheckInMetric.fromId(id);
  if (metric == CheckInMetric.mood) return s.strings.profile.m_mood;
  if (metric == CheckInMetric.bloodPressure) return s.strings.profile.m_bp;
  if (metric == CheckInMetric.glucose) return s.strings.profile.m_glucose;
  if (metric == CheckInMetric.weight) return s.strings.profile.m_weight;
  if (metric == CheckInMetric.pain) return s.strings.profile.m_pain;
  if (metric == CheckInMetric.symptoms) return s.strings.checkin.symptoms;
  return id;
}
