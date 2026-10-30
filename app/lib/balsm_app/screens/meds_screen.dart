import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:core/core.dart';
import 'package:prescriptions/prescriptions.dart';
import 'package:medications/medications.dart';
import '../app_state.dart';
import '../routes.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../storage_target.dart';
import '../widgets/data_loc_pill.dart';
import '../widgets/delete_kit.dart';
import '../widgets/med_plan_form.dart';

/// Medications tab (home.jsx MedsScreen).
///
/// Ported onto the REAL medications module: the med list + today's doses come
/// from the on-device (SQLCipher) DAO for [currentUserIdProvider]; add-med and
/// dose actions (taken / skip / snooze) go through the module use-cases and
/// invalidate-after-write. Signed out → empty/disabled, no crash. PHI (drug
/// names/doses) never leaves the device.
///
/// Each dose row deletes its medication through the shared [DeleteKit]
/// (swipe, `⋮`, Select). Deleting ends the medication (its dose history
/// stays), so every dose row of it leaves today's schedule.
///
/// Also hosts the FR-023 / gap-G9 timezone-shift confirm modal: on app
/// foreground it compares the device timezone to the last-seen one and, if it
/// changed, asks whether to recompute reminder times before rebuilding.
class MedsScreen extends ConsumerStatefulWidget {
  const MedsScreen({super.key});
  @override
  ConsumerState<MedsScreen> createState() => _MedsScreenState();
}

class _MedsScreenState extends ConsumerState<MedsScreen> with DeleteKit<MedsScreen, MedicationId> {
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

  Future<void> _addMedication(UserId userId, Medication med) async {
    await ref.read(addMedicationUseCaseProvider(userId)).call(med);
    if (!mounted) return;
    ref.invalidate(todayDosesProvider);
    ref.invalidate(medicationListProvider);
  }

  /// Asks before ending [meds]; nothing changes on Cancel.
  void _askDelete(UserId userId, List<Medication> meds) {
    if (meds.isEmpty) return;
    final s = AppScope.of(context);
    final m = s.strings.meds;
    final one = meds.length == 1 ? meds.single : null;
    final what = one?.name ?? m.med_count(meds.length);
    confirmDelete(
      title: s.strings.common.del_title(what),
      body: one != null ? m.med_del_body_one : m.med_del_body_n,
      done: what,
      onConfirmed: () async {
        final delete = ref.read(deleteMedicationUseCaseProvider(userId));
        for (final med in meds) {
          await delete(med.id);
        }
        if (!mounted) return;
        ref.invalidate(todayDosesProvider);
        ref.invalidate(medicationListProvider);
      },
    );
  }

  // ── UI actions ───────────────────────────────────────────────────────────

  Future<void> _openDoseActions(TodayDose dose) async {
    final s = AppScope.of(context);
    final outcome = await showAppSheet<DoseOutcome>(
      context,
      barrierColor: const Color(0x6114202B),
      textDirection: s.dir,
      builder: (_) => _DoseActionSheet(s: s, dose: dose),
    );
    if (outcome != null) await _recordDose(dose, outcome);
  }

  Future<void> _openAddMedication(UserId userId) async {
    final s = AppScope.of(context);
    await showAppSheet<void>(
      context,
      size: SheetSize.lg,
      barrierColor: const Color(0x6114202B),
      textDirection: s.dir,
      builder: (_) => _AddMedSheet(s: s, userId: userId, onSave: (med) => _addMedication(userId, med)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final doses = ref.watch(todayDosesProvider).valueOrNull ?? const <TodayDose>[];
    // A deleted medication is ended, not removed, so count the current ones.
    final medCount =
        (ref.watch(medicationListProvider).valueOrNull ?? const <Medication>[]).where((m) => !m.isExpired()).length;
    // Each medication once, in schedule order — what Select can tick.
    final scheduled = {for (final d in doses) d.medication.id: d.medication}.values.toList();
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

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selecting) endSelect();
      },
      child: ContentColumn(
        maxWidth: 720,
        child: Stack(children: [
          ListView(padding: EdgeInsets.zero, children: [
            const PadTop(),
            if (selecting)
              kitSelectAppBar(scheduled.map((m) => m.id))
            else
              AppBarRow(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.strings.meds.medications, style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl)),
                    const SizedBox(height: 2),
                    Text(s.strings.meds.regimen, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                  ]),
                ),
                const DataLocPill(category: DataCategory.meds),
                const SizedBox(width: 8),
                if (userId != null && scheduled.isNotEmpty) ...[kitSelectButton(), const SizedBox(width: 8)],
                // Add medication — disabled (hidden) when signed out.
                if (userId != null)
                  RoundBtn(
                      icon: LucideIcons.plus,
                      semanticLabel: s.strings.common.a11y_add,
                      iconSize: 20,
                      onTap: () => _openAddMedication(userId)),
              ]),

            // Adherence (last 7 days). Gradient card from the Claude Design.
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(T.rLg),
                border: Border.all(color: T.hueMint50),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.65],
                  colors: [T.hueMint50, Colors.white],
                ),
                boxShadow: T.shadowSm,
              ),
              child: Row(children: [
                RingProgress(
                    progress: adherence,
                    size: 68,
                    color: T.hueMint,
                    label: '$adherencePct%',
                    labelStyle: Typo.num(size: FS.base, weight: FontWeight.w700)),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.strings.meds.adherence,
                        style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(s.strings.meds.last_7d, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                    const SizedBox(height: 8),
                    if (total > 0 && adherencePct >= 80)
                      Pill(s.strings.home.on_track, kind: PillKind.success, ar: s.rtl),
                  ]),
                ),
              ]),
            ),

            // Prescriptions link (navigates to the separate rx tab).
            PCard(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              onTap: () => s.setTab(AppTab.prescriptions),
              child: Row(children: [
                const IconSquare(LucideIcons.fileText,
                    bg: T.hueViolet50, fg: T.hueViolet, size: 34, iconSize: 19, radius: T.rSm),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(T.rLg - 1),
                      child: Column(
                          children: list.indexed.map((e) {
                        final med = e.$2.medication;
                        void ask() => _askDelete(userId, [med]);
                        return kitSwipe(
                          item: med.id,
                          rowKey: (med.id, e.$2.scheduledAt),
                          label: med.name,
                          onDelete: ask,
                          child: _MedDoseRow(
                            s: s,
                            dose: e.$2,
                            first: e.$1 == 0,
                            lead: kitCheck(med.id),
                            trail: kitMore(label: med.name, onDelete: ask),
                            onTap: e.$2.isPending ? () => _openDoseActions(e.$2) : null,
                          ),
                        );
                      }).toList()),
                    ),
                  ),
                ],
              ],
            SizedBox(height: selecting ? kitBottomRoom : 24),
          ]),
          ...deleteKitOverlays(
            count: s.strings.meds.med_count,
            onDeleteSelected: () {
              if (userId != null) _askDelete(userId, scheduled.where((m) => selected.contains(m.id)).toList());
            },
          ),
        ]),
      ),
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
    (bg: T.hueBlue50, fg: T.hueBlue),
    (bg: T.hueViolet50, fg: T.hueViolet),
    (bg: T.hueMint50, fg: T.hueMint600),
  ];
  return tones[id.value.hashCode.abs() % tones.length];
}

String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// One scheduled dose row — same layout as the prototype `_MedListRow`, but the
/// status pill reflects the real recorded outcome and a pending row is tappable
/// to record taken/skip/snooze.
class _MedDoseRow extends StatelessWidget {
  const _MedDoseRow(
      {required this.s, required this.dose, required this.first, required this.lead, required this.trail, this.onTap});
  final PatientAppState s;
  final TodayDose dose;
  final bool first;

  /// Select's tick box, and the row's `⋮` (design MedsScreen row).
  final Widget lead;
  final Widget trail;
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
        decoration: BoxDecoration(
          color: Colors.white,
          border: first ? null : const Border(top: BorderSide(color: T.ink100)),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 8, 14),
        child: Row(children: [
          lead,
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
          trail,
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
          const IconSquare(LucideIcons.pill, bg: T.hueBlue50, fg: T.hueBlue, size: 38, iconSize: 20, radius: T.rSm),
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
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration:
          const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(children: [
            const Padding(padding: EdgeInsets.only(bottom: 10), child: SheetGrab()),
            Container(
              padding: const EdgeInsets.only(bottom: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink100))),
              child: Row(children: [
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(title, style: Typo.subhead(ar: st.rtl).copyWith(fontWeight: FontWeight.w700)))),
                RoundBtn(
                    icon: LucideIcons.x,
                    semanticLabel: st.strings.common.a11y_close,
                    ghost: true,
                    iconSize: 18,
                    onTap: () => Navigator.pop(context)),
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
            tone: T.hueMint600,
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

// ── Add-medication sheet (prescriptions.jsx AddMedSheet) ─────────────────────

/// A medication with no prescription (pain relief, vitamins, carried-over
/// meds). Saved on-device, then shown as a confirmation before closing.
class _AddMedSheet extends StatefulWidget {
  const _AddMedSheet({required this.s, required this.userId, required this.onSave});
  final PatientAppState s;
  final UserId userId;
  final Future<void> Function(Medication med) onSave;
  @override
  State<_AddMedSheet> createState() => _AddMedSheetState();
}

class _AddMedSheetState extends State<_AddMedSheet> {
  final _draft = MedPlanDraft();
  bool _saving = false;
  bool _done = false;

  PatientAppState get s => widget.s;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_draft.isNamed || _saving) return;
    setState(() => _saving = true);
    await widget.onSave(_draft.toMedication(widget.userId));
    if (!mounted) return;
    setState(() => _done = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = s.strings.meds;
    if (_done) {
      return _SheetChrome(s: s, title: '', child: _Added(s: s, label: m.med_added));
    }
    final ready = _draft.isNamed && !_saving;
    return _SheetChrome(
      s: s,
      title: m.med_add_title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: T.cream50, borderRadius: BorderRadius.circular(T.rLg)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(LucideIcons.info, size: 16, color: T.fg3),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(m.med_self_note, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2, height: 1.45)),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        MedPlanCard(draft: _draft, onChanged: () => setState(() {})),
        const SizedBox(height: 18),
        Opacity(
          opacity: ready ? 1 : 0.4,
          child: PButton(m.med_add_btn,
              large: true, block: true, accent: s.accent, ar: s.rtl, onTap: ready ? _submit : null),
        ),
      ]),
    );
  }
}

class _Added extends StatelessWidget {
  const _Added({required this.s, required this.label});
  final PatientAppState s;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: T.hueMint50, shape: BoxShape.circle),
            child: const Icon(LucideIcons.check, size: 36, color: T.hueMint600),
          ),
          const SizedBox(height: 14),
          Text(label, style: Typo.heading(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}
