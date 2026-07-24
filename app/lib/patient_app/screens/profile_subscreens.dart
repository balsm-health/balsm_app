import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:core/core.dart' show currentUserIdProvider;
import 'package:profile/profile.dart'
    show
        HealthProfile,
        Allergy,
        ChronicCondition,
        AllergyId,
        profileDataSourceProvider,
        updateHealthProfileUseCaseProvider,
        addAllergyUseCaseProvider,
        removeAllergyUseCaseProvider,
        addChronicConditionUseCaseProvider;
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../shell.dart' show AdaptiveFrame;

/// Profile sub-screens ported from `home.jsx`: Medical profile, Care team,
/// Privacy & data, Emergency numbers. Each opens as a pushed full-screen route
/// (mirrors `openPersonalDetails`) and width-caps its content for tablet/desktop.

void _push(BuildContext context, Widget Function(PatientAppState s) build) {
  final s = AppScope.of(context);
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
    builder: (_) => Directionality(textDirection: s.dir, child: AdaptiveFrame(child: build(s))),
  ));
}

void openMedicalProfile(BuildContext context) => _push(context, (s) => MedicalProfileScreen(s: s));
void openCareTeam(BuildContext context) => _push(context, (s) => CareTeamScreen(s: s));
void openPrivacyData(BuildContext context) => _push(context, (s) => PrivacyDataScreen(s: s));
void openEmergency(BuildContext context) => _push(context, (s) => EmergencyScreen(s: s));

/// Shared scaffold: status-bar spacer + back app bar + width-capped scroll body.
class _SubScreen extends StatelessWidget {
  const _SubScreen({required this.s, required this.title, required this.children, this.trailing, this.maxWidth = 640});
  final PatientAppState s;
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Column(children: [
          const PadTop(),
          AppBarRow(
            leading: RoundBtn(icon: LucideIcons.arrowLeft, onTap: () => Navigator.pop(context)),
            children: [
              Expanded(child: Text(title, style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl))),
              if (trailing != null) trailing!,
            ],
          ),
          Expanded(
            child: ContentColumn(
              maxWidth: maxWidth,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: children),
            ),
          ),
        ]),
      );
}

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.icon, this.title, {required this.s});
  final IconData icon;
  final String title;
  final PatientAppState s;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
        child: Row(children: [
          Icon(icon, size: 16, color: s.accent.main),
          const SizedBox(width: 8),
          Text(title, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
        ]),
      );
}

// ── Medical profile ──────────────────────────────────────────

/// Reads the current user's on-device [HealthProfile] (SQLCipher-backed PHI).
/// Re-runs when the signed-in user changes; emits `null` when signed out.
/// Writes go through the profile use-cases, which invalidate this provider.
final _medProfileProvider =
    FutureProvider.autoDispose<HealthProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(profileDataSourceProvider).getProfile(userId);
});

class MedicalProfileScreen extends ConsumerStatefulWidget {
  const MedicalProfileScreen({super.key, required this.s});
  final PatientAppState s;
  @override
  ConsumerState<MedicalProfileScreen> createState() =>
      _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends ConsumerState<MedicalProfileScreen> {
  PatientAppState get s => widget.s;
  final algInput = TextEditingController();
  // Measurements are local-only (no on-device schema for weight/height/BMI).
  final weight = TextEditingController(text: '78');
  final height = TextEditingController(text: '162');
  bool saving = false, saved = false;

  @override
  void dispose() {
    algInput.dispose();
    weight.dispose();
    height.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Real PHI writes (on-device only; nothing sent to the cloud) ──────────

  /// Toggle blood type via UpdateHealthProfileUseCase. Tapping the currently
  /// selected type clears it (back to unknown).
  Future<void> _setBloodType(String bt) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final current = ref.read(_medProfileProvider).valueOrNull?.bloodType;
    final toClear = current == bt;
    final result = await ref.read(updateHealthProfileUseCaseProvider).execute(
          userId: userId,
          bloodType: toClear ? null : bt,
          clearBloodType: toClear,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      ref.invalidate(_medProfileProvider);
    } else {
      _snack(result.error.message);
    }
  }

  /// Add an allergy. The prototype chip captures a name only, so severity
  /// defaults to 'mild' (real model requires a severity).
  Future<void> _addAllergy(String name) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final result = await ref.read(addAllergyUseCaseProvider).execute(
          userId: userId,
          name: name,
          severity: 'mild',
        );
    if (!mounted) return;
    if (result.isSuccess) {
      ref.invalidate(_medProfileProvider);
    } else {
      _snack(result.error.message);
    }
  }

  Future<void> _removeAllergy(AllergyId id) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final result = await ref
        .read(removeAllergyUseCaseProvider)
        .execute(userId: userId, allergyId: id);
    if (!mounted) return;
    if (result.isSuccess) {
      ref.invalidate(_medProfileProvider);
    } else {
      _snack(result.error.message);
    }
  }

  /// G7: add a chronic condition with optional ICD-10 code + onset year.
  Future<void> _addCondition(String name, String? icd10Code, int? onsetYear) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final result = await ref.read(addChronicConditionUseCaseProvider).execute(
          userId: userId,
          name: name,
          icd10Code: icd10Code,
          onsetYear: onsetYear,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      ref.invalidate(_medProfileProvider);
    } else {
      _snack(result.error.message);
    }
  }

  void _save() {
    if (saving) return;
    setState(() => saving = true);
    Future.delayed(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      setState(() { saving = false; saved = true; });
      Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => saved = false); });
    });
  }

  ({String value, double pct, Color color, Color bg, String key})? get _bmi {
    final w = double.tryParse(weight.text) ?? 0;
    final h = (double.tryParse(height.text) ?? 0) / 100;
    if (w <= 0 || h <= 0) return null;
    final v = w / (h * h);
    if (!v.isFinite) return null;
    final (key, color, bg) = v < 18.5
        ? ('bmi_under', T.petalBlue, T.petalBlue50)
        : v < 25
            ? ('bmi_normal', T.petalMint600, T.petalMint50)
            : v < 30
                ? ('bmi_over', const Color(0xFFD97A20), const Color(0xFFFBF0E2))
                : ('bmi_obese', T.danger, const Color(0xFFFBEBE7));
    final pct = (((v - 15) / 20) * 100).clamp(2.0, 98.0);
    return (value: v.toStringAsFixed(1), pct: pct, color: color, bg: bg, key: key);
  }

  @override
  Widget build(BuildContext context) {
    final bmi = _bmi;
    // Real on-device PHI. `null` while loading or when signed out (empty state).
    final profile = ref.watch(_medProfileProvider).valueOrNull;
    final allergyList = profile?.allergies ?? const <Allergy>[];
    final conditionList = profile?.conditions ?? const <ChronicCondition>[];
    final selectedBlood = profile?.bloodType;
    return _SubScreen(
      s: s,
      title: s.strings.p_cond,
      maxWidth: 560,
      trailing: saved ? Pill(s.strings.pd_saved, kind: PillKind.success, ar: s.rtl) : null,
      children: [
        _SectionHead(LucideIcons.clipboardList, s.strings.pd_conditions, s: s),
        _ConditionEditor(s: s, conditions: conditionList,
            bg: s.accent.bg, fg: s.accent.d, onAdd: _addCondition),
        _SectionHead(LucideIcons.alertOctagon, s.strings.pd_allergies, s: s),
        _ChipEditor(s: s, labels: allergyList.map((a) => a.name).toList(), ctrl: algInput,
            hint: s.strings.pd_add_alg, bg: const Color(0xFFFBEBE7), fg: T.danger,
            onAdd: _addAllergy, onRemoveAt: (i) => _removeAllergy(allergyList[i].id)),
        _SectionHead(LucideIcons.droplet, s.strings.pd_blood, s: s),
        PCard(padding: const EdgeInsets.all(16), child: Wrap(spacing: 8, runSpacing: 8, children: const ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
            .map((bt) => Pressable(
                  onTap: () => _setBloodType(bt),
                  scale: 0.96,
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(
                      color: selectedBlood == bt ? s.accent.bg : Colors.white,
                      borderRadius: BorderRadius.circular(T.rMd),
                      border: Border.all(color: selectedBlood == bt ? s.accent.main : T.border, width: 1.5),
                    ),
                    child: Text(bt, style: Typo.num(size: FS.sm, weight: FontWeight.w700, color: selectedBlood == bt ? s.accent.d : T.fg2)),
                  ),
                ))
            .toList())),
        _SectionHead(LucideIcons.ruler, s.strings.pd_measurements, s: s),
        PCard(padding: const EdgeInsets.all(16), child: Column(children: [
          Row(children: [
            Expanded(child: _numField('${s.strings.pd_weight} (${s.strings.pd_kg})', weight)),
            const SizedBox(width: 12),
            Expanded(child: _numField('${s.strings.pd_height} (${s.strings.pd_cm})', height)),
          ]),
          if (bmi != null) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: T.ink100)),
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.strings.bmi_label.toUpperCase(), style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs2, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: T.fg3)),
                Text(bmi.value, style: Typo.display().copyWith(fontSize: FS.xl2)),
              ]),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Pill(s.t(bmi.key), kind: PillKind.neutral, dot: false, ar: s.rtl, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3)),
                const SizedBox(height: 8),
                LayoutBuilder(builder: (context, c) => Stack(clipBehavior: Clip.none, children: [
                  Container(height: 6, decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: const LinearGradient(colors: [T.petalBlue, T.petalMint, Color(0xFFD97A20), T.danger], stops: [0, 0.33, 0.66, 1]),
                  )),
                  Positioned(
                    left: (c.maxWidth * bmi.pct / 100) - 6,
                    top: -3,
                    child: Container(width: 12, height: 12, decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle, border: Border.all(color: T.fg1, width: 2.5))),
                  ),
                ])),
              ])),
            ]),
          ],
        ])),
        const SizedBox(height: 22),
        PButton(saving ? '…' : (saved ? s.strings.pd_saved : s.strings.pd_save),
            icon: saved ? LucideIcons.check : LucideIcons.save,
            variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: s.rtl,
            onTap: saving ? null : _save),
      ],
    );
  }

  Widget _numField(String label, TextEditingController c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs2, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: T.fg3)),
        const SizedBox(height: 8),
        TextField(
          controller: c, textDirection: TextDirection.ltr, keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          style: Typo.num(size: FS.lg),
          decoration: InputDecoration(
            isDense: true, filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
          ),
        ),
      ]);
}

/// Chip list + single-line add field. Backed by real data: [labels] render the
/// current items, [onAdd] persists a new one, and [onRemoveAt] (when provided)
/// deletes item `i`. No local list mutation.
class _ChipEditor extends StatelessWidget {
  const _ChipEditor({required this.s, required this.labels, required this.ctrl, required this.hint, required this.bg, required this.fg, required this.onAdd, this.onRemoveAt});
  final PatientAppState s;
  final List<String> labels;
  final TextEditingController ctrl;
  final String hint;
  final Color bg, fg;
  final void Function(String value) onAdd;
  final void Function(int index)? onRemoveAt;
  void _add() {
    final v = ctrl.text.trim();
    if (v.isEmpty) return;
    ctrl.clear();
    onAdd(v);
  }
  @override
  Widget build(BuildContext context) => PCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (labels.isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Wrap(spacing: 8, runSpacing: 8, children: labels.indexed
              .map((e) => Container(
                    padding: onRemoveAt == null
                        ? const EdgeInsetsDirectional.only(start: 11, end: 11, top: 6, bottom: 6)
                        : const EdgeInsetsDirectional.only(start: 11, end: 6, top: 4, bottom: 4),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(T.rPill)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(e.$2, style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.xs, fontWeight: FontWeight.w600, color: fg)),
                      if (onRemoveAt != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => onRemoveAt!(e.$1),
                          child: Icon(LucideIcons.x, size: 13, color: fg),
                        ),
                      ],
                    ]),
                  ))
              .toList())),
        Row(children: [
          Expanded(child: TextField(
            controller: ctrl, textDirection: s.dir, onSubmitted: (_) => _add(),
            style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.md, color: T.fg1),
            decoration: InputDecoration(
              hintText: hint, hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4),
              isDense: true, filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
            ),
          )),
          const SizedBox(width: 8),
          Pressable(
            onTap: _add,
            scale: 0.94,
            child: Container(width: 44, height: 44, alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.rMd), border: Border.all(color: T.borderStrong)),
                child: const Icon(LucideIcons.plus, size: 18, color: T.fg1)),
          ),
        ]),
      ]));
}

/// Chronic-condition editor (G7). Renders existing conditions as chips showing
/// name + optional ICD-10 code + onset year, and an add form with a name field
/// plus optional ICD-10 code / onset-year fields. Add persists via
/// AddChronicConditionUseCase. (No remove: the module exposes no remove-condition
/// use-case yet, so condition chips are display-only.) Prototype field styling.
class _ConditionEditor extends StatefulWidget {
  const _ConditionEditor({required this.s, required this.conditions, required this.bg, required this.fg, required this.onAdd});
  final PatientAppState s;
  final List<ChronicCondition> conditions;
  final Color bg, fg;
  final Future<void> Function(String name, String? icd10Code, int? onsetYear) onAdd;
  @override
  State<_ConditionEditor> createState() => _ConditionEditorState();
}

class _ConditionEditorState extends State<_ConditionEditor> {
  final _name = TextEditingController();
  final _icd10 = TextEditingController();
  final _year = TextEditingController();

  PatientAppState get s => widget.s;

  @override
  void dispose() {
    _name.dispose();
    _icd10.dispose();
    _year.dispose();
    super.dispose();
  }

  void _add() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final icd10 = _icd10.text.trim();
    final year = int.tryParse(_year.text.trim());
    widget.onAdd(name, icd10.isEmpty ? null : icd10, year);
    _name.clear();
    _icd10.clear();
    _year.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => PCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.conditions.isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Wrap(spacing: 8, runSpacing: 8, children: widget.conditions.map(_chip).toList())),
        _field(_name, s.strings.pd_add_cond, s.dir),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _field(_icd10, s.strings.cond_icd10_hint, TextDirection.ltr)),
          const SizedBox(width: 8),
          SizedBox(width: 92, child: _field(_year, s.strings.cond_onset_hint, TextDirection.ltr, number: true)),
          const SizedBox(width: 8),
          Pressable(
            onTap: _add,
            scale: 0.94,
            child: Container(width: 44, height: 44, alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.rMd), border: Border.all(color: T.borderStrong)),
                child: const Icon(LucideIcons.plus, size: 18, color: T.fg1)),
          ),
        ]),
      ]));

  Widget _chip(ChronicCondition c) {
    final meta = [
      if (c.icd10Code != null && c.icd10Code!.isNotEmpty) c.icd10Code!,
      if (c.onsetYear != null) c.onsetYear!.toString(),
    ].join(' · ');
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 11, end: 11, top: 6, bottom: 6),
      decoration: BoxDecoration(color: widget.bg, borderRadius: BorderRadius.circular(T.rPill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(c.name, style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.xs, fontWeight: FontWeight.w600, color: widget.fg)),
        if (meta.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(meta, textDirection: TextDirection.ltr,
              style: Typo.num(size: FS.xs2, weight: FontWeight.w700, color: widget.fg)),
        ],
      ]),
    );
  }

  Widget _field(TextEditingController c, String hint, TextDirection dir, {bool number = false}) => TextField(
        controller: c, textDirection: dir, onSubmitted: (_) => _add(),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.md, color: T.fg1),
        decoration: InputDecoration(
          hintText: hint, hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4, fontSize: FS.sm),
          isDense: true, filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
        ),
      );
}

// ── Care team ────────────────────────────────────────────────
class CareTeamScreen extends StatelessWidget {
  const CareTeamScreen({super.key, required this.s});
  final PatientAppState s;
  @override
  Widget build(BuildContext context) => _SubScreen(
        s: s,
        title: s.strings.p_care,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
            child: Text(s.strings.care_intro, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ),
          // P001 has no care-team backend yet, so this shows a neutral empty
          // state (no fabricated doctors). The "find care" CTA below routes to
          // the map where a real care team is built in a later phase.
          PCard(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            child: Column(children: [
              const Icon(LucideIcons.stethoscope, size: 36, color: T.ink300),
              const SizedBox(height: 12),
              Text(s.strings.care_empty,
                  textAlign: TextAlign.center,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
              const SizedBox(height: 4),
              Text(s.strings.care_add_help,
                  textAlign: TextAlign.center,
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ]),
          ),
          const SizedBox(height: 16),
          Pressable(
            onTap: () { Navigator.pop(context); s.setTab('map'); },
            child: Container(
              height: 52, alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(T.rMd),
                border: Border.all(color: T.borderStrong, width: 1.5, style: BorderStyle.solid),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.userPlus, size: 17, color: T.fg1),
                const SizedBox(width: 8),
                Text(s.strings.care_find, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              ]),
            ),
          ),
        ],
      );
}

// ── Privacy & data ───────────────────────────────────────────
class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key, required this.s});
  final PatientAppState s;
  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  PatientAppState get s => widget.s;
  bool shareTeam = true, analytics = false, research = false, bioLock = true, pin = false;

  @override
  Widget build(BuildContext context) => _SubScreen(
        s: s,
        title: s.strings.p_privacy,
        children: [
          _SectionHead(LucideIcons.share2, s.strings.pv_sharing, s: s),
          _listCard([
            _toggle(s.strings.pv_share_team, s.strings.pv_share_team_h, shareTeam, (v) => setState(() => shareTeam = v)),
            _toggle(s.strings.pv_analytics, s.strings.pv_analytics_h, analytics, (v) => setState(() => analytics = v)),
            _toggle(s.strings.pv_research, s.strings.pv_research_h, research, (v) => setState(() => research = v), last: true),
          ]),
          _SectionHead(LucideIcons.lock, s.strings.pv_security, s: s),
          _listCard([
            _toggle(s.strings.pv_bio, s.strings.pv_bio_h, bioLock, (v) => setState(() => bioLock = v)),
            _toggle(s.strings.pv_pin, s.strings.pv_pin_h, pin, (v) => setState(() => pin = v), last: true),
          ]),
          _SectionHead(LucideIcons.database, s.strings.pv_yourdata, s: s),
          _listCard([
            _action(LucideIcons.download, s.strings.pv_export, s.strings.pv_export_h),
            _action(LucideIcons.folderHeart, s.strings.pv_download, s.strings.pv_download_h),
            _action(LucideIcons.appWindow, s.strings.pv_connected, s.strings.pv_connected_h, last: true),
          ]),
          _SectionHead(LucideIcons.alertTriangle, s.strings.pv_danger, s: s),
          _listCard([
            _action(LucideIcons.trash2, s.strings.pv_delete, s.strings.pv_delete_h, danger: true, last: true),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(LucideIcons.shieldCheck, size: 14, color: T.fg3),
              const SizedBox(width: 6),
              Text(s.strings.pv_encrypted, style: Typo.meta(ar: s.rtl)),
            ]),
          ),
        ],
      );

  Widget _listCard(List<Widget> rows) => PCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(borderRadius: BorderRadius.circular(T.rLg), child: Column(children: rows)),
      );

  Widget _row(List<Widget> children, bool last) => Container(
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: T.ink100))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: children),
      );

  Widget _toggle(String title, String desc, bool on, ValueChanged<bool> set, {bool last = false}) => _row([
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
          const SizedBox(height: 2),
          Text(desc, style: Typo.meta(ar: s.rtl)),
        ])),
        const SizedBox(width: 12),
        _PSwitch(on: on, accent: s.accent.main, onTap: () => set(!on)),
      ], last);

  Widget _action(IconData icon, String title, String desc, {bool danger = false, bool last = false}) => _row([
        Container(width: 38, height: 38, alignment: Alignment.center,
            decoration: BoxDecoration(color: danger ? T.dangerBg : T.ink50, borderRadius: BorderRadius.circular(T.rMd)),
            child: Icon(icon, size: 18, color: danger ? T.danger : T.fg2)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: danger ? T.danger : T.fg1)),
          const SizedBox(height: 2),
          Text(desc, style: Typo.meta(ar: s.rtl)),
        ])),
        Chevron(rtl: s.rtl),
      ], last);
}

/// Pill toggle switch.
class _PSwitch extends StatelessWidget {
  const _PSwitch({required this.on, required this.accent, required this.onTap});
  final bool on;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 46, height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: on ? accent : T.ink300, borderRadius: BorderRadius.circular(999)),
          alignment: on ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: T.shadowXs)),
        ),
      );
}

// ── Emergency numbers ────────────────────────────────────────
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key, required this.s});
  final PatientAppState s;

  static const _contacts = [
    ('em_ambulance', LucideIcons.heartPulse, '123', T.danger, T.dangerBg),
    ('em_police', LucideIcons.shield, '122', T.petalBlue, T.petalBlue50),
    ('em_fire', LucideIcons.flame, '180', Color(0xFFD97A20), Color(0xFFFBF0E2)),
    ('em_tourist', LucideIcons.compass, '126', T.petalViolet, T.petalViolet50),
  ];

  @override
  Widget build(BuildContext context) => _SubScreen(
        s: s,
        title: s.strings.p_emergency,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(LucideIcons.mapPin, size: 12, color: T.fg3),
          const SizedBox(width: 4),
          Text(s.strings.em_eg, style: Typo.meta(ar: s.rtl)),
        ]),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 16),
            child: Text(s.strings.em_intro, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2)),
          ),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 520 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.0,
              children: _contacts.map(_tile).toList(),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(LucideIcons.phoneCall, size: 15, color: T.fg3),
              const SizedBox(width: 6),
              Text(s.strings.em_tap_call, style: Typo.meta(ar: s.rtl)),
            ]),
          ),
        ],
      );

  // `.emergency-tile:active { transform: scale(0.98) }` — tap-to-call tile.
  Widget _tile((String, IconData, String, Color, Color) ct) => Pressable(
        onTap: () {},
        scale: 0.98,
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(T.rLg),
          border: Border.all(color: T.border), boxShadow: T.shadowSm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 44, height: 44, alignment: Alignment.center,
              decoration: BoxDecoration(color: ct.$5, borderRadius: BorderRadius.circular(T.rMd)),
              child: Icon(ct.$2, size: 22, color: ct.$4)),
          const Spacer(),
          Text(s.t(ct.$1), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
          const SizedBox(height: 2),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(ct.$3, style: Typo.num(size: FS.xl, weight: FontWeight.w800)),
            Icon(LucideIcons.phone, size: 13, color: ct.$4),
          ]),
        ]),
      ));
}
