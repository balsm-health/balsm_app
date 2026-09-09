import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:core/core.dart' show UserId, currentUserIdProvider, globalKVDataSourceProvider;
import 'package:prescriptions/prescriptions.dart' show Prescription, prescriptionListProvider;
import 'package:medications/medications.dart'
    show
        Medication,
        MedicationId,
        ScheduleType,
        ScheduleConfig,
        DoseOutcome,
        TodayDose,
        todayDosesProvider,
        weekAdherenceProvider,
        medicationListProvider,
        addMedicationUseCaseProvider,
        recordDoseOutcomeUseCaseProvider,
        medicationSchedulerProvider;
import '../app_state.dart';
import '../kit.dart';
import '../prefs.dart';
import '../responsive.dart';
import '../tokens.dart';

/// Medications tab (home.jsx MedsScreen).
///
/// Ported onto the REAL medications module: the med list + today's doses come
/// from the on-device (SQLCipher) DAO for [currentUserIdProvider]; add-med and
/// dose actions (taken / skip / snooze) go through the module use-cases and
/// invalidate-after-write. Signed out → empty/disabled, no crash. PHI (drug
/// names/doses) never leaves the device.
///
/// Also hosts the FR-023 / gap-G9 timezone-shift confirm modal: on app
/// foreground it compares the device timezone to the last-seen one and, if it
/// changed, asks whether to recompute reminder times before rebuilding.
class MedsScreen extends ConsumerStatefulWidget {
  const MedsScreen({super.key});
  @override
  ConsumerState<MedsScreen> createState() => _MedsScreenState();
}

class _MedsScreenState extends ConsumerState<MedsScreen> with WidgetsBindingObserver {
  bool _tzBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Opening the meds tab after travel is itself a "foreground" moment.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTimezoneShift());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkTimezoneShift();
  }

  // ── G9 — timezone-shift detector (FR-023) ────────────────────────────────

  /// On foreground: compare the current device timezone marker to the last
  /// stored one. If it changed, ask (never silently rebuild) whether to
  /// recompute reminder times; on accept, rebuild via the scheduler. The marker
  /// is persisted so a shift is prompted at most once.
  Future<void> _checkTimezoneShift() async {
    if (_tzBusy || !mounted) return;
    _tzBusy = true;
    try {
      final prefs = PatientAppPrefs(ref.read(globalKVDataSourceProvider));
      // No `timezone`/`flutter_timezone` dep in the app package; the OS-backed
      // marker updates whenever the device timezone changes at runtime.
      final current = DateTime.now().timeZoneName;
      final last = await prefs.lastTimezone();
      if (last == null) {
        await prefs.setLastTimezone(current);
        return;
      }
      if (last == current) return;

      final userId = ref.read(currentUserIdProvider);
      // Signed out → no reminders to recompute; just refresh the marker so we
      // don't prompt on the next sign-in.
      if (userId == null) {
        await prefs.setLastTimezone(current);
        return;
      }
      if (!mounted) return;

      final accept = await _showTimezoneConfirm(last, current);
      if (accept == true && mounted) {
        // Rebuilds OS reminder triggers for the new local clock times.
        await ref.read(medicationSchedulerProvider(userId)).handleTimezoneShift(last);
        ref.invalidate(todayDosesProvider);
        ref.invalidate(medicationListProvider);
      }
      // One prompt per shift, whatever the choice (accept rebuilds, decline
      // leaves schedules untouched).
      await prefs.setLastTimezone(current);
    } finally {
      _tzBusy = false;
    }
  }

  Future<bool?> _showTimezoneConfirm(String previous, String current) {
    final s = AppScope.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x6114202B),
      builder: (ctx) => Directionality(
        textDirection: s.dir,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _TimezoneConfirmSheet(s: s, previous: previous, current: current),
          ),
        ),
      ),
    );
  }

  // ── Real writes (on-device only; nothing sent to the cloud) ──────────────

  Future<void> _recordDose(TodayDose dose, DoseOutcome outcome) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref.read(recordDoseOutcomeUseCaseProvider).call(
          medicationId: dose.medication.id,
          scheduledAt: dose.scheduledAt,
          outcome: outcome,
          snoozeUntil: outcome == DoseOutcome.snoozed ? DateTime.now().add(const Duration(minutes: 15)) : null,
        );
    if (!mounted) return;
    ref.invalidate(todayDosesProvider);
    ref.invalidate(medicationListProvider);
  }

  Future<void> _addMedication(UserId userId, _NewMed draft) async {
    final med = Medication(
      id: MedicationId.uuid(),
      userId: userId,
      name: draft.name,
      doseAmount: draft.dose,
      scheduleType: ScheduleType.daily,
      scheduleConfig: ScheduleConfig(times: [draft.time]),
      startDate: DateTime.now(),
      isControlled: false,
    );
    await ref.read(addMedicationUseCaseProvider(userId)).call(med);
    if (!mounted) return;
    ref.invalidate(todayDosesProvider);
    ref.invalidate(medicationListProvider);
  }

  // ── UI actions ───────────────────────────────────────────────────────────

  Future<void> _openDoseActions(TodayDose dose) async {
    final s = AppScope.of(context);
    final outcome = await showModalBottomSheet<DoseOutcome>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x6114202B),
      builder: (ctx) => Directionality(
        textDirection: s.dir,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _DoseActionSheet(s: s, dose: dose),
          ),
        ),
      ),
    );
    if (outcome != null) await _recordDose(dose, outcome);
  }

  Future<void> _openAddMedication(UserId userId) async {
    final s = AppScope.of(context);
    final draft = await showModalBottomSheet<_NewMed>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x6114202B),
      builder: (ctx) => Directionality(
        textDirection: s.dir,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _AddMedSheet(s: s),
          ),
        ),
      ),
    );
    if (draft != null) await _addMedication(userId, draft);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final doses = ref.watch(todayDosesProvider).valueOrNull ?? const <TodayDose>[];
    final medCount = ref.watch(medicationListProvider).valueOrNull?.length ?? 0;
    // The prescriptions row counts *prescriptions* still in force — not meds.
    final activeRxCount =
        (ref.watch(prescriptionListProvider).valueOrNull ?? const <Prescription>[]).where((rx) => rx.isActive()).length;

    // Group today's doses into morning (< 12:00) / evening for the two cards.
    final morning = doses.where((d) => d.scheduledAt.hour < 12).toList();
    final evening = doses.where((d) => d.scheduledAt.hour >= 12).toList();
    final groups = [
      ('morning', LucideIcons.sunrise, morning),
      ('evening', LucideIcons.moon, evening),
    ];

    // Adherence over the last 7 calendar days (design MedsScreen `last_7d`).
    final week = ref.watch(weekAdherenceProvider).valueOrNull;
    final total = week?.scheduled ?? 0;
    final adherence = week?.ratio ?? 0.0;
    final adherencePct = week?.percent ?? 0;

    return ContentColumn(
      maxWidth: 720,
      child: ListView(padding: EdgeInsets.zero, children: [
        const PadTop(),
        AppBarRow(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.strings.meds.medications, style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl)),
              const SizedBox(height: 2),
              Text(s.strings.meds.regimen, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ]),
          ),
          // Add medication — disabled (hidden) when signed out.
          if (userId != null) RoundBtn(icon: LucideIcons.plus, iconSize: 20, onTap: () => _openAddMedication(userId)),
        ]),

        // Adherence (last 7 days). Gradient card from the Claude Design.
        Container(
          margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(T.rLg),
            border: Border.all(color: T.petalMint50),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.65],
              colors: [T.petalMint50, Colors.white],
            ),
            boxShadow: T.shadowSm,
          ),
          child: Row(children: [
            RingProgress(
                progress: adherence,
                size: 68,
                color: T.petalMint,
                label: '$adherencePct%',
                labelStyle: Typo.num(size: FS.base, weight: FontWeight.w700)),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.strings.meds.adherence, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(s.strings.meds.last_7d, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                const SizedBox(height: 8),
                if (total > 0 && adherencePct >= 80) Pill(s.strings.home.on_track, kind: PillKind.success, ar: s.rtl),
              ]),
            ),
          ]),
        ),

        // Prescriptions link (navigates to the separate rx tab).
        PCard(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          onTap: () => s.setTab('rx'),
          child: Row(children: [
            const IconSquare(LucideIcons.fileText,
                bg: T.petalViolet50, fg: T.petalViolet, size: 34, iconSize: 19, radius: T.rSm),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.strings.records.prescriptions,
                    style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                const SizedBox(height: 1),
                Text(s.strings.meds.rx_manage, style: Typo.meta(ar: s.rtl)),
              ]),
            ),
            Pill('$activeRxCount ${s.strings.meds.rx_active.toLowerCase()}', kind: PillKind.success, ar: s.rtl),
            const SizedBox(width: 8),
            Chevron(rtl: s.rtl),
          ]),
        ),

        if (userId == null)
          _EmptyState(s: s, text: s.strings.meds.meds_signin_help)
        else if (doses.isEmpty)
          _EmptyState(s: s, text: medCount == 0 ? s.strings.meds.meds_empty_help : s.strings.meds.meds_none_today)
        else
          for (final (key, icon, list) in groups) ...[
            if (list.isNotEmpty) ...[
              _GroupHead(
                label: key == 'morning' ? s.strings.meds.morning : s.strings.meds.evening,
                icon: icon,
                count: list.length,
                ar: s.rtl,
              ),
              PCard(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                    children: list.indexed
                        .map((e) => _MedDoseRow(
                            s: s,
                            dose: e.$2,
                            first: e.$1 == 0,
                            onTap: e.$2.isPending ? () => _openDoseActions(e.$2) : null))
                        .toList()),
              ),
            ],
          ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// Morning / evening section title with the accent icon square from the design.
class _GroupHead extends StatelessWidget {
  const _GroupHead({required this.label, required this.icon, required this.count, required this.ar});
  final String label;
  final IconData icon;
  final int count;
  final bool ar;

  @override
  Widget build(BuildContext context) {
    final accent = AppScope.of(context).accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      // `.row-head` keeps `justify-content: space-between`, so the three items
      // spread across the row: icon chip at the start, label between, count at
      // the far end — not clustered together.
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: accent.bg, borderRadius: BorderRadius.circular(T.rSm)),
          child: Icon(icon, size: 15, color: accent.d),
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
          ),
        ),
        Text('· $count', style: Typo.meta(ar: ar)),
      ]),
    );
  }
}

/// (bg, fg) wash + icon color for a medication, keyed off its id so the same
/// med always gets the same tone. Mirrors the prototype `medTone` palette.
({Color bg, Color fg}) _toneFor(MedicationId id) {
  const tones = <({Color bg, Color fg})>[
    (bg: T.petalBlue50, fg: T.petalBlue),
    (bg: T.petalViolet50, fg: T.petalViolet),
    (bg: T.petalMint50, fg: T.petalMint600),
  ];
  return tones[id.value.hashCode.abs() % tones.length];
}

String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// One scheduled dose row — same layout as the prototype `_MedListRow`, but the
/// status pill reflects the real recorded outcome and a pending row is tappable
/// to record taken/skip/snooze.
class _MedDoseRow extends StatelessWidget {
  const _MedDoseRow({required this.s, required this.dose, required this.first, this.onTap});
  final PatientAppState s;
  final TodayDose dose;
  final bool first;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final med = dose.medication;
    final tone = _toneFor(med.id);
    final outcome = dose.event?.outcome;
    final (label, kind) = switch (outcome) {
      DoseOutcome.taken => (s.strings.meds.taken, PillKind.success),
      DoseOutcome.skipped => (s.strings.meds.dose_skipped, PillKind.neutral),
      DoseOutcome.snoozed => (s.strings.meds.dose_snoozed, PillKind.neutral),
      DoseOutcome.missed => (s.strings.meds.dose_missed, PillKind.neutral),
      _ => (s.strings.meds.due, PillKind.neutral),
    };
    final subtitle = [
      if (med.doseAmount != null && med.doseAmount!.isNotEmpty) med.doseAmount!,
      _hhmm(dose.scheduledAt),
    ].join(' · ');

    return Pressable(
      onTap: onTap,
      scale: onTap == null ? 1.0 : 0.99,
      child: Container(
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: T.ink100))),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(children: [
          Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(T.rMd)),
              child: Icon(med.isControlled ? LucideIcons.heartPulse : LucideIcons.pill, size: 21, color: tone.fg)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(med.name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            Text(subtitle, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ])),
          Pill(label, kind: kind, ar: s.rtl),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Chevron(rtl: s.rtl),
          ],
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.s, required this.text});
  final PatientAppState s;
  final String text;
  @override
  Widget build(BuildContext context) => PCard(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        padding: const EdgeInsets.all(22),
        child: Row(children: [
          const IconSquare(LucideIcons.pill, bg: T.petalBlue50, fg: T.petalBlue, size: 38, iconSize: 20, radius: T.rSm),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: Typo.body(ar: s.rtl).copyWith(color: T.fg3))),
        ]),
      );
}

// ── Bottom-sheet shell (local; mirrors the prototype sheet chrome) ───────────

class _SheetChrome extends StatelessWidget {
  const _SheetChrome({required this.title, required this.child, this.s});
  final String title;
  final Widget child;
  final PatientAppState? s;
  @override
  Widget build(BuildContext context) {
    final st = s ?? AppScope.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration:
          const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(children: [
            Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
            Container(
              padding: const EdgeInsets.only(bottom: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink100))),
              child: Row(children: [
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(title, style: Typo.subhead(ar: st.rtl).copyWith(fontWeight: FontWeight.w700)))),
                RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 18, onTap: () => Navigator.pop(context)),
              ]),
            ),
          ]),
        ),
        Flexible(
          // Add the keyboard inset to the bottom padding so the focused field
          // and the sheet's buttons scroll ABOVE the native keyboard.
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 14, 20, sheetBottomInset(context)),
            child: child,
          ),
        ),
      ]),
    );
  }
}

/// Full-width pill button (accent = primary, outline = secondary).
class _SheetButton extends StatelessWidget {
  const _SheetButton(
      {required this.s, required this.label, required this.onTap, this.icon, this.primary = false, this.tone});
  final PatientAppState s;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool primary;
  final Color? tone;
  @override
  Widget build(BuildContext context) {
    final accent = tone ?? s.accent.main;
    return Pressable(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? accent : Colors.white,
          borderRadius: BorderRadius.circular(T.rMd),
          border: Border.all(color: primary ? accent : T.borderStrong, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: primary ? Colors.white : T.fg1),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: primary ? Colors.white : T.fg1)),
        ]),
      ),
    );
  }
}

// ── Dose action sheet (taken / skip / snooze) ────────────────────────────────

class _DoseActionSheet extends StatelessWidget {
  const _DoseActionSheet({required this.s, required this.dose});
  final PatientAppState s;
  final TodayDose dose;
  @override
  Widget build(BuildContext context) {
    return _SheetChrome(
      s: s,
      title: dose.medication.name,
      child: Column(children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text('${s.strings.meds.med_scheduled} · ${_hhmm(dose.scheduledAt)}',
              style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
        ),
        const SizedBox(height: 16),
        _SheetButton(
            s: s,
            label: s.strings.meds.taken,
            icon: LucideIcons.check,
            primary: true,
            tone: T.petalMint600,
            onTap: () => Navigator.pop(context, DoseOutcome.taken)),
        const SizedBox(height: 10),
        _SheetButton(
            s: s,
            label: s.strings.meds.med_snooze15,
            icon: LucideIcons.clock,
            onTap: () => Navigator.pop(context, DoseOutcome.snoozed)),
        const SizedBox(height: 10),
        _SheetButton(
            s: s,
            label: s.strings.meds.med_skip,
            icon: LucideIcons.x,
            onTap: () => Navigator.pop(context, DoseOutcome.skipped)),
      ]),
    );
  }
}

// ── Timezone-shift confirm sheet (G9 / FR-023) ───────────────────────────────

class _TimezoneConfirmSheet extends StatelessWidget {
  const _TimezoneConfirmSheet({required this.s, required this.previous, required this.current});
  final PatientAppState s;
  final String previous;
  final String current;
  @override
  Widget build(BuildContext context) {
    return _SheetChrome(
      s: s,
      title: s.strings.meds.tz_changed,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: T.petalBlue50, borderRadius: BorderRadius.circular(T.rMd)),
              child: const Icon(LucideIcons.globe, size: 22, color: T.petalBlue)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(s.strings.meds.meds_tz_moved(previous, current),
                style: Typo.body(ar: s.rtl).copyWith(color: T.fg2)),
          ),
        ]),
        const SizedBox(height: 20),
        _SheetButton(
            s: s, label: s.strings.meds.tz_recompute, primary: true, onTap: () => Navigator.pop(context, true)),
        const SizedBox(height: 10),
        _SheetButton(s: s, label: s.strings.meds.tz_keep, onTap: () => Navigator.pop(context, false)),
      ]),
    );
  }
}

// ── Add-medication sheet ─────────────────────────────────────────────────────

/// Result of the add-medication sheet — on-device PHI, never sent to the cloud.
class _NewMed {
  const _NewMed({required this.name, required this.time, this.dose});
  final String name;
  final String time; // HH:mm
  final String? dose;
}

class _AddMedSheet extends StatefulWidget {
  const _AddMedSheet({required this.s});
  final PatientAppState s;
  @override
  State<_AddMedSheet> createState() => _AddMedSheetState();
}

class _AddMedSheetState extends State<_AddMedSheet> {
  final _name = TextEditingController();
  final _dose = TextEditingController();
  String _time = '08:00';

  PatientAppState get s => widget.s;

  static const _timeOptions = <(String, String)>[
    ('08:00', 'meds.med_time_morning'),
    ('13:00', 'meds.med_time_midday'),
    ('20:00', 'meds.med_time_evening'),
    ('22:00', 'meds.med_time_night'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final dose = _dose.text.trim();
    Navigator.pop(context, _NewMed(name: name, time: _time, dose: dose.isEmpty ? null : dose));
  }

  Widget _field(TextEditingController c, String hint, {TextInputType? kb}) => TextField(
        controller: c,
        textDirection: s.dir,
        keyboardType: kb,
        style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.md, color: T.fg1),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return _SheetChrome(
      s: s,
      title: s.strings.meds.med_add_title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.strings.meds.med_field_name,
            style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
        const SizedBox(height: 8),
        _field(_name, s.strings.meds.med_ph_name),
        const SizedBox(height: 16),
        Text(s.strings.meds.med_field_dose,
            style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
        const SizedBox(height: 8),
        _field(_dose, s.strings.meds.med_ph_dose),
        const SizedBox(height: 16),
        Text(s.strings.meds.med_reminder_time,
            style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (value, key) in _timeOptions)
            Pressable(
              onTap: () => setState(() => _time = value),
              scale: 0.96,
              child: AnimatedContainer(
                duration: Motion.base,
                curve: Motion.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: _time == value ? s.accent.bg : Colors.white,
                  borderRadius: BorderRadius.circular(T.rMd),
                  border: Border.all(color: _time == value ? s.accent.main : T.border, width: 1.5),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(s.t(key),
                      style: Typo.body(ar: s.rtl).copyWith(
                          fontSize: FS.xs, fontWeight: FontWeight.w700, color: _time == value ? s.accent.d : T.fg2)),
                  Text(value,
                      style:
                          Typo.num(size: FS.xs2, weight: FontWeight.w600, color: _time == value ? s.accent.d : T.fg4)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 22),
        _SheetButton(s: s, label: s.strings.meds.med_add_btn, icon: LucideIcons.plus, primary: true, onTap: _submit),
      ]),
    );
  }
}
