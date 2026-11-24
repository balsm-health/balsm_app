import 'dart:async';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../shell.dart';
import '../storage_target.dart';
import '../widgets/data_loc_pill.dart';
import 'family/family_kit.dart' show BloodTypeGrid;

/// Profile sub-screens ported from `home.jsx`: Medical profile, Care team,
/// Privacy & data, Emergency numbers. Each opens as a pushed full-screen route
/// (mirrors `openPersonalDetails`) and width-caps its content for tablet/desktop.

/// Pushes a profile sub-screen as a full-screen route, inside the app's
/// directionality and the tablet/desktop [AdaptiveFrame].
void pushSubScreen(BuildContext context, Widget Function(PatientAppState s) build) {
  final s = AppScope.of(context);
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => Directionality(textDirection: s.dir, child: AdaptiveFrame(child: build(s))),
    ),
  );
}

void openMedicalProfile(BuildContext context) => pushSubScreen(context, (s) => MedicalProfileScreen(s: s));
void openPrivacyData(BuildContext context, {VoidCallback? onDeleteAccount}) =>
    pushSubScreen(context, (s) => PrivacyDataScreen(s: s, onDeleteAccount: onDeleteAccount));
void openEmergency(BuildContext context) => pushSubScreen(context, (s) => EmergencyScreen(s: s));

/// Shared scaffold: status-bar spacer + back app bar + width-capped scroll
/// body. Public so `care_team_screen.dart` can wear the same chrome.
class SubScreen extends StatelessWidget {
  const SubScreen({
    required this.s,
    required this.title,
    required this.children,
    super.key,
    this.trailing,
    this.maxWidth = 640,
    this.floating,
    this.onRefresh,
  });
  final PatientAppState s;
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final double maxWidth;

  /// A floating action pinned over the list, laid out like `.rec-fab`: 20 from
  /// the trailing edge, 24 above the home indicator. Leave null for the
  /// sub-screens that have no primary add.
  final Widget? floating;

  /// Pull-to-refresh handler. Null (the default) means no indicator at all, so
  /// every sub-screen that has nothing to refresh is untouched.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.white,
        body: Stack(
          children: [
            Column(
              children: [
                const PadTop(),
                AppBarRow(
                  leading: RoundBtn(
                    icon: backArrow(context),
                    semanticLabel: s.strings.common.a11y_back,
                    onTap: () => Navigator.pop(context),
                  ),
                  children: [
                    Expanded(child: Text(title, style: Typo.heading(ar: s.rtl).copyWith(fontSize: FontSizes.heading))),
                    if (trailing case final trailing?) trailing,
                  ],
                ),
                Expanded(
                  child: ContentColumn(
                    maxWidth: maxWidth,
                    child: _MaybeRefreshable(
                      onRefresh: onRefresh,
                      ListView(
                        // A refreshable list must always be draggable, even when it
                        // is short enough not to scroll, or the gesture never starts.
                        physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 28),
                        children: children,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (floating case final floating?)
              PositionedDirectional(
                end: 20,
                bottom:
                    (windowClassOf(context) == BalsmWindowClass.compact ? MediaQuery.paddingOf(context).bottom : 0) +
                        24,
                child: floating,
              ),
          ],
        ),
      );
}

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.icon, this.title, {required this.s});
  final IconData icon;
  final String title;
  final PatientAppState s;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(0, 18, 0, 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: s.accent.main),
            const SizedBox(width: 8),
            Text(
              title,
              style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}

// ── Medical profile ──────────────────────────────────────────

/// Reads the current user's on-device [HealthProfile] (SQLCipher-backed PHI).
/// Re-runs when the signed-in user changes; emits `null` when signed out.
/// Writes go through the profile use-cases, which invalidate this provider.
///
/// Shared with the profile tab, which shows the patient their own chronic
/// conditions as chips (home.jsx `profile-head`).
final FutureProvider<HealthProfile?> healthProfileProvider = FutureProvider.autoDispose<HealthProfile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(profileDataSourceProvider).getProfile(userId);
});

/// One member profile of the signed-in account by id (Mother & Child: the
/// member's emergency card and medical details). Null when signed out, or
/// when the profile is missing or closed. Child-collection writes do not
/// notify, so editors invalidate this after a change, as they do
/// [healthProfileProvider].
final FutureProviderFamily<HealthProfile?, HealthProfileId> memberHealthProfileProvider =
    FutureProvider.autoDispose.family<HealthProfile?, HealthProfileId>((ref, profileId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(profileDataSourceProvider).resolveProfile(userId, profileId: profileId);
});

class MedicalProfileScreen extends ConsumerStatefulWidget {
  const MedicalProfileScreen({required this.s, super.key, this.profileId, this.title});
  final PatientAppState s;

  /// Replaces the screen title — a member's screen names the member.
  final String? title;

  /// The member profile to edit (Mother & Child); null edits the account
  /// holder's own profile, as before.
  final HealthProfileId? profileId;
  @override
  ConsumerState<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends ConsumerState<MedicalProfileScreen> {
  PatientAppState get s => widget.s;

  /// Whose profile this screen reads: self, or the member it was opened for.
  FutureProvider<HealthProfile?> get _source => switch (widget.profileId) {
        final profileId? => memberHealthProfileProvider(profileId),
        _ => healthProfileProvider
      };
  final algInput = TextEditingController();
  // Measurements persist on-device with the health profile (SQLCipher).
  // Empty until the patient enters them — never pre-fill sample PHI.
  final weight = TextEditingController();
  final height = TextEditingController();
  bool saving = false;
  bool saved = false;
  bool _measurementsSeeded = false;

  /// The patient chose "Not sure" (the blood type is cleared): the choice shows, as an unset type would not.
  bool _bloodUnsure = false;

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
  /// Records [bt], or clears the blood type for "Not sure" (null). Tapping the
  /// type already recorded also clears it.
  Future<void> _setBloodType(BloodType? bt) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final current = ref.read(_source).value?.bloodType;
    final toClear = bt == null || current == bt;
    setState(() => _bloodUnsure = bt == null);
    final result = await ref.read(updateHealthProfileUseCaseProvider).execute(
          userId: userId,
          profileId: widget.profileId,
          bloodType: toClear ? null : bt,
          clearBloodType: toClear,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      ref.invalidate(_source);
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
          profileId: widget.profileId,
          name: name,
          severity: 'mild',
        );
    if (!mounted) return;
    if (result.isSuccess) {
      ref.invalidate(_source);
    } else {
      _snack(result.error.message);
    }
  }

  Future<void> _removeAllergy(AllergyId id) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final result = await ref
        .read(removeAllergyUseCaseProvider)
        .execute(userId: userId, profileId: widget.profileId, allergyId: id);
    if (!mounted) return;
    if (result.isSuccess) {
      ref.invalidate(_source);
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
          profileId: widget.profileId,
          name: name,
          icd10Code: icd10Code,
          onsetYear: onsetYear,
        );
    if (!mounted) return;
    if (result.isSuccess) {
      ref.invalidate(_source);
    } else {
      _snack(result.error.message);
    }
  }

  Future<void> _removeCondition(ChronicConditionId id) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final result = await ref
        .read(removeChronicConditionUseCaseProvider)
        .execute(userId: userId, profileId: widget.profileId, conditionId: id);
    if (!mounted) return;
    if (result.isSuccess) {
      ref.invalidate(_source);
    } else {
      _snack(result.error.message);
    }
  }

  void _seedMeasurements(HealthProfile? profile) {
    if (_measurementsSeeded || profile == null) return;
    _measurementsSeeded = true;
    if (profile.weightKg case final weightKg?) weight.text = _fmtMeasure(weightKg);
    if (profile.heightCm case final heightCm?) height.text = _fmtMeasure(heightCm);
  }

  String _fmtMeasure(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  Future<void> _save() async {
    if (saving) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final wText = weight.text.trim();
    final hText = height.text.trim();
    final w = wText.isEmpty ? null : double.tryParse(wText);
    final h = hText.isEmpty ? null : double.tryParse(hText);
    if (wText.isNotEmpty && w == null) {
      _snack(s.strings.profile.pd_number_invalid(s.gender));
      return;
    }
    if (hText.isNotEmpty && h == null) {
      _snack(s.strings.profile.pd_number_invalid(s.gender));
      return;
    }
    setState(() => saving = true);
    final result = await ref.read(updateHealthProfileUseCaseProvider).execute(
          userId: userId,
          profileId: widget.profileId,
          weightKg: w,
          clearWeight: wText.isEmpty,
          heightCm: h,
          clearHeight: hText.isEmpty,
        );
    if (!mounted) return;
    setState(() => saving = false);
    if (result.isSuccess) {
      ref.invalidate(_source);
      setState(() => saved = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => saved = false);
      });
    } else {
      _snack(result.error.message);
    }
  }

  /// Gauge scale — the visible span of the bar, not a clinical boundary.
  static const _gaugeMin = 15.0;
  static const _gaugeMax = 35.0;

  /// Presentation for the live BMI of whatever is currently typed.
  ///
  /// The number and its category come from [Bmi] in the profile domain; this
  /// only chooses a colour, a copy key and where the needle sits.
  ({String value, double pct, Color color, Color bg, String key})? get _bmi {
    final bmi = Bmi.fromMeasurements(
      weightKg: double.tryParse(weight.text),
      heightCm: double.tryParse(height.text),
    );
    if (bmi == null) return null;
    final (key, color, bg) = switch (bmi.category) {
      BmiCategory.underweight => ('profile.bmi_under', AppColors.hueBlue, AppColors.hueBlue50),
      BmiCategory.normal => ('profile.bmi_normal', AppColors.hueMint600, AppColors.hueMint50),
      BmiCategory.overweight => ('profile.bmi_over', AppColors.expiring, AppColors.expiringBackground),
      BmiCategory.obese => ('profile.bmi_obese', AppColors.danger, AppColors.dangerBackground),
    };
    final pct = ((bmi.value - _gaugeMin) / (_gaugeMax - _gaugeMin) * 100).clamp(2.0, 98.0);
    return (value: bmi.value.toStringAsFixed(1), pct: pct, color: color, bg: bg, key: key);
  }

  @override
  Widget build(BuildContext context) {
    final bmi = _bmi;
    // Real on-device PHI. `null` while loading or when signed out (empty state).
    final profile = ref.watch(_source).value;
    _seedMeasurements(profile);
    final allergyList = profile?.allergies ?? const <Allergy>[];
    final conditionList = profile?.conditions ?? const <ChronicCondition>[];
    final selectedBlood = profile?.bloodType;
    return SubScreen(
      s: s,
      title: widget.title ?? s.strings.profile.p_cond,
      maxWidth: 560,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DataLocPill(category: DataCategory.medical),
          if (saved) ...[
            const SizedBox(width: 8),
            Pill(s.strings.profile.pd_saved, kind: PillKind.success, ar: s.rtl),
          ],
        ],
      ),
      children: [
        _SectionHead(LucideIcons.clipboardList, s.strings.profile.pd_conditions, s: s),
        _ConditionEditor(
          s: s,
          conditions: conditionList,
          bg: s.accent.bg,
          fg: s.accent.d,
          onAdd: _addCondition,
          onRemove: _removeCondition,
        ),
        _SectionHead(LucideIcons.alertOctagon, s.strings.profile.pd_allergies, s: s),
        _ChipEditor(
          s: s,
          labels: allergyList.map((a) => a.name).toList(),
          ctrl: algInput,
          hint: s.strings.profile.pd_add_alg(s.gender),
          bg: AppColors.dangerBackground,
          fg: AppColors.danger,
          onAdd: _addAllergy,
          onRemoveAt: (i) => _removeAllergy(allergyList[i].id),
        ),
        _SectionHead(LucideIcons.droplet, s.strings.profile.pd_blood, s: s),
        PCard(
          padding: const EdgeInsets.all(12),
          child: BloodTypeGrid(value: selectedBlood, unsure: _bloodUnsure, onChanged: _setBloodType),
        ),
        _SectionHead(LucideIcons.ruler, s.strings.profile.pd_measurements, s: s),
        PCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _numField('${s.strings.profile.pd_weight} (${s.strings.profile.pd_kg})', weight)),
                  const SizedBox(width: 12),
                  Expanded(child: _numField('${s.strings.profile.pd_height} (${s.strings.profile.pd_cm})', height)),
                ],
              ),
              if (bmi != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: AppColors.ink100),
                ),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.strings.profile.bmi_label.toUpperCase(),
                          style: Typo.meta(ar: s.rtl).copyWith(
                            fontSize: FontSizes.eyebrow,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Text(bmi.value, style: Typo.display().copyWith(fontSize: FontSizes.title)),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration:
                                BoxDecoration(color: bmi.bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
                            child: Text(
                              s.t(bmi.key),
                              style: Typo.meta(ar: s.rtl)
                                  .copyWith(fontSize: FontSizes.eyebrow, fontWeight: FontWeight.w700, color: bmi.color),
                            ),
                          ),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, c) => Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(AppRadii.pill),
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.hueBlue,
                                        AppColors.hueMint,
                                        AppColors.expiring,
                                        AppColors.danger,
                                      ],
                                      stops: [0, 0.33, 0.66, 1],
                                    ),
                                  ),
                                ),
                                PositionedDirectional(
                                  start: (c.maxWidth * bmi.pct / 100) - 6,
                                  top: -3,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.textPrimary, width: 2.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        PButton(
          saving ? s.strings.profile.pd_saving : (saved ? s.strings.profile.pd_saved : s.strings.profile.pd_save),
          icon: saved ? LucideIcons.check : LucideIcons.save,
          large: true,
          block: true,
          accent: s.accent,
          ar: s.rtl,
          onTap: saving ? null : _save,
        ),
      ],
    );
  }

  Widget _numField(String label, TextEditingController c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Typo.meta(ar: s.rtl).copyWith(
              fontSize: FontSizes.eyebrow,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: c,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            style: Typo.num(size: FontSizes.subhead),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide(color: s.accent.main, width: 1.5),
              ),
            ),
          ),
        ],
      );
}

/// Chip list + single-line add field. Backed by real data: [labels] render the
/// current items, [onAdd] persists a new one, and [onRemoveAt] (when provided)
/// deletes item `i`. No local list mutation.
class _ChipEditor extends StatelessWidget {
  const _ChipEditor({
    required this.s,
    required this.labels,
    required this.ctrl,
    required this.hint,
    required this.bg,
    required this.fg,
    required this.onAdd,
    this.onRemoveAt,
  });
  final PatientAppState s;
  final List<String> labels;
  final TextEditingController ctrl;
  final String hint;
  final Color bg;
  final Color fg;
  final void Function(String value) onAdd;
  final void Function(int index)? onRemoveAt;
  void _add() {
    final v = ctrl.text.trim();
    if (v.isEmpty) return;
    ctrl.clear();
    onAdd(v);
  }

  @override
  Widget build(BuildContext context) => PCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (labels.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: labels.indexed
                      .map(
                        (e) => Container(
                          padding: onRemoveAt == null
                              ? const EdgeInsetsDirectional.only(start: 11, end: 11, top: 6, bottom: 6)
                              : const EdgeInsetsDirectional.only(start: 11, end: 6, top: 4, bottom: 4),
                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                e.$2,
                                style: Typo.body(ar: s.rtl)
                                    .copyWith(fontSize: FontSizes.meta, fontWeight: FontWeight.w600, color: fg),
                              ),
                              if (onRemoveAt case final onRemoveAt?) ...[
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => onRemoveAt(e.$1),
                                  child: Icon(LucideIcons.x, size: 13, color: fg),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    textDirection: s.dir,
                    onSubmitted: (_) => _add(),
                    style: Typo.body(ar: s.rtl).copyWith(fontSize: FontSizes.body, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: Typo.body(ar: s.rtl).copyWith(color: AppColors.textHint),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        borderSide: BorderSide(color: s.accent.main, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Pressable(
                  onTap: _add,
                  scale: 0.94,
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    child: const Icon(LucideIcons.plus, size: 18, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

/// Chronic-condition editor (G7). Renders existing conditions as chips showing
/// name + optional ICD-10 code + onset year, with × to remove (on-device only).
class _ConditionEditor extends StatefulWidget {
  const _ConditionEditor({
    required this.s,
    required this.conditions,
    required this.bg,
    required this.fg,
    required this.onAdd,
    required this.onRemove,
  });
  final PatientAppState s;
  final List<ChronicCondition> conditions;
  final Color bg;
  final Color fg;
  final Future<void> Function(String name, String? icd10Code, int? onsetYear) onAdd;
  final Future<void> Function(ChronicConditionId id) onRemove;
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
    unawaited(widget.onAdd(name, icd10.isEmpty ? null : icd10, year));
    _name.clear();
    _icd10.clear();
    _year.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => PCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.conditions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(spacing: 8, runSpacing: 8, children: widget.conditions.map(_chip).toList()),
              ),
            _field(_name, s.strings.profile.pd_add_cond(s.gender), s.dir),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field(_icd10, s.strings.checkin.cond_icd10_hint, TextDirection.ltr)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: _field(_year, s.strings.checkin.cond_onset_hint, TextDirection.ltr, number: true),
                ),
                const SizedBox(width: 8),
                Pressable(
                  onTap: _add,
                  scale: 0.94,
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    child: const Icon(LucideIcons.plus, size: 18, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _chip(ChronicCondition c) {
    final meta = [
      if (c.icd10Code case final icd10Code? when c.icd10Code!.isNotEmpty) icd10Code,
      if (c.onsetYear case final onsetYear?) onsetYear.toString(),
    ].join(' · ');
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 11, end: 6, top: 4, bottom: 4),
      decoration: BoxDecoration(color: widget.bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            c.name,
            style:
                Typo.body(ar: s.rtl).copyWith(fontSize: FontSizes.meta, fontWeight: FontWeight.w600, color: widget.fg),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              meta,
              textDirection: TextDirection.ltr,
              style: Typo.num(size: FontSizes.eyebrow, weight: FontWeight.w700, color: widget.fg),
            ),
          ],
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => widget.onRemove(c.id),
            child: Icon(LucideIcons.x, size: 13, color: widget.fg),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, TextDirection dir, {bool number = false}) => TextField(
        controller: c,
        textDirection: dir,
        onSubmitted: (_) => _add(),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: Typo.body(ar: s.rtl).copyWith(fontSize: FontSizes.body, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Typo.body(ar: s.rtl).copyWith(color: AppColors.textHint, fontSize: FontSizes.bodySm),
          isDense: true,
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
            borderSide: BorderSide(color: s.accent.main, width: 1.5),
          ),
        ),
      );
}

// ── Privacy & data ───────────────────────────────────────────
class PrivacyDataScreen extends ConsumerStatefulWidget {
  const PrivacyDataScreen({required this.s, super.key, this.onDeleteAccount});
  final PatientAppState s;
  final VoidCallback? onDeleteAccount;
  @override
  ConsumerState<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends ConsumerState<PrivacyDataScreen> {
  PatientAppState get s => widget.s;
  bool shareTeam = true;
  bool research = false;
  bool bioLock = true;
  bool pin = false;

  /// Product-analytics consent — the one toggle on this screen that is real.
  /// Persisted device-wide and pushed straight to whichever analytics backends
  /// the composition root registered, so switching it off stops collection now,
  /// not on the next launch. Which vendor that is, is not this screen's
  /// business. The rest are still design placeholders.
  void _setAnalytics(bool enabled) {
    final consent = ref.read(analyticsConsentProvider);
    // Order matters on the way OUT: consent lands first, so the event below is
    // already gated and a patient who just opted out sends nothing.
    unawaited(consent.set(enabled));
    ref.read(analyticsLoggerProvider).logEvent('analytics_consent_changed', props: {'enabled': enabled});
  }

  /// Screen-recording consent: opt-in, and only meaningful with analytics on
  /// — off analytics, the switch shows off and does nothing.
  void _setReplay(bool enabled) {
    if (!ref.read(analyticsConsentProvider).enabled) return;
    unawaited(ref.read(replayConsentProvider).set(enabled));
    ref.read(analyticsLoggerProvider).logEvent('replay_consent_changed', props: {'enabled': enabled});
  }

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(analyticsConsentProvider).enabled;
    final replayConsent = ref.watch(replayConsentProvider).enabled;
    final replay = analytics && replayConsent;
    return SubScreen(
      s: s,
      title: s.strings.profile.p_privacy,
      children: [
        _SectionHead(LucideIcons.share2, s.strings.privacy.pv_sharing, s: s),
        _ListCard([
          _toggle(
            s.strings.privacy.pv_share_team,
            s.strings.privacy.pv_share_team_h,
            shareTeam,
            (v) => setState(() => shareTeam = v),
          ),
          _toggle(s.strings.privacy.pv_analytics, s.strings.privacy.pv_analytics_h, analytics, _setAnalytics),
          _toggle(s.strings.privacy.pv_replay, s.strings.privacy.pv_replay_h, replay, _setReplay),
          _toggle(
            s.strings.privacy.pv_research,
            s.strings.privacy.pv_research_h,
            research,
            (v) => setState(() => research = v),
            last: true,
          ),
        ]),
        _SectionHead(LucideIcons.lock, s.strings.privacy.pv_security, s: s),
        _ListCard([
          _action(
            LucideIcons.mail,
            s.strings.emergency.em_label,
            s.authEmail.isEmpty ? '—' : s.authEmail,
            ltrDesc: true,
          ),
          _toggle(
            s.strings.privacy.pv_bio,
            s.strings.privacy.pv_bio_h(s.gender),
            bioLock,
            (v) => setState(() => bioLock = v),
          ),
          _toggle(
            s.strings.privacy.pv_pin,
            s.strings.privacy.pv_pin_h,
            pin,
            (v) => setState(() => pin = v),
            last: true,
          ),
        ]),
        _SectionHead(LucideIcons.database, s.strings.privacy.pv_yourdata, s: s),
        _ListCard([
          _action(LucideIcons.download, s.strings.privacy.pv_export, s.strings.privacy.pv_export_h),
          _action(LucideIcons.folderHeart, s.strings.privacy.pv_download, s.strings.privacy.pv_download_h),
          _action(LucideIcons.appWindow, s.strings.privacy.pv_connected, s.strings.privacy.pv_connected_h, last: true),
        ]),
        _SectionHead(LucideIcons.alertTriangle, s.strings.privacy.pv_danger, s: s),
        _ListCard([
          _action(
            LucideIcons.trash2,
            s.strings.privacy.pv_delete,
            s.strings.privacy.pv_delete_h,
            danger: true,
            last: true,
            onTap: widget.onDeleteAccount,
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(s.strings.privacy.pv_encrypted, style: Typo.meta(ar: s.rtl)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toggle(String title, String desc, bool on, ValueChanged<bool> set, {bool last = false}) => _Row(
        [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(desc, style: Typo.meta(ar: s.rtl)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PSwitch(on: on, accent: s.accent.main, onTap: () => set(!on)),
        ],
        last,
      );

  Widget _action(
    IconData icon,
    String title,
    String desc, {
    bool danger = false,
    bool last = false,
    bool ltrDesc = false,
    VoidCallback? onTap,
  }) {
    final row = _Row(
      [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: danger ? AppColors.dangerBackground : AppColors.ink50,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Icon(icon, size: 18, color: danger ? AppColors.danger : AppColors.textSecondary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Typo.body(ar: s.rtl)
                    .copyWith(fontWeight: FontWeight.w600, color: danger ? AppColors.danger : AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(desc, textDirection: ltrDesc ? TextDirection.ltr : null, style: Typo.meta(ar: s.rtl)),
            ],
          ),
        ),
        if (onTap != null) Chevron(rtl: s.rtl),
      ],
      last,
    );
    if (onTap == null) return row;
    return Pressable(onTap: onTap, scale: 0.99, child: row);
  }
}

// ── Emergency numbers ────────────────────────────────────────
/// One call target: label, icon, number, icon colour and its wash.
typedef _EmergencyLine = (String, IconData, String, Color, Color);

/// The emergency numbers of the country the patient is in ([PatientAppState.country]).
///
/// Egypt lists four services (the numbers below are Egypt's own); every other
/// country shows its national emergency number from [CountryCode.emergencyNumber],
/// and a country with none on file says so instead of showing a wrong number.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({required this.s, super.key});
  final PatientAppState s;

  List<_EmergencyLine> _lines() {
    final e = s.strings.emergency;
    final national = s.country.emergencyNumber;
    if (s.country == CountryCode.egypt) {
      return [
        (e.em_ambulance, LucideIcons.heartPulse, national, AppColors.danger, AppColors.dangerBackground),
        (e.em_police, LucideIcons.shield, '122', AppColors.hueBlue, AppColors.hueBlue50),
        (e.em_fire, LucideIcons.flame, '180', AppColors.expiring, AppColors.expiringBackground),
        (e.em_tourist, LucideIcons.compass, '126', AppColors.hueViolet, AppColors.hueViolet50),
      ];
    }
    return national.isEmpty
        ? const []
        : [(e.em_national, LucideIcons.siren, national, AppColors.danger, AppColors.dangerBackground)];
  }

  @override
  Widget build(BuildContext context) {
    final e = s.strings.emergency;
    final country = s.country.name(kCatalog, locale: s.lang.value);
    final lines = _lines();
    return SubScreen(
      s: s,
      title: s.strings.profile.p_emergency,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.mapPin, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(country, style: Typo.meta(ar: s.rtl)),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 2, 0, 16),
          child: Text(
            lines.isEmpty ? e.em_none(country, s.gender) : e.em_intro(country, s.gender),
            style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textSecondary),
          ),
        ),
        if (lines.isNotEmpty) ...[
          // `.emergency-grid` — two thumb-sized call targets per row on a
          // phone, `repeat(4, minmax(0, 1fr))` once the window reaches the
          // medium class and the four contacts fit on one line.
          LayoutBuilder(
            builder: (context, c) {
              const gap = 12.0;
              final columns = windowClassOf(context) == BalsmWindowClass.compact ? 2 : 4;
              final tileW = (c.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: lines.map((ct) => SizedBox(width: tileW, child: _tile(ct))).toList(),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.phoneCall, size: 15, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(e.em_tap_call(s.gender), style: Typo.meta(ar: s.rtl)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // `.emergency-tile:active { transform: scale(0.98) }` — tap-to-call tile.
  Widget _tile(_EmergencyLine ct) => Pressable(
        onTap: () => launchUrl(Uri(scheme: 'tel', path: ct.$3)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: ct.$5, borderRadius: BorderRadius.circular(AppRadii.md)),
                child: Icon(ct.$2, size: 23, color: ct.$4),
              ),
              const SizedBox(height: 12),
              Text(
                ct.$1,
                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ct.$3, style: Typo.num(size: FontSizes.title)),
                  Icon(LucideIcons.phone, size: 13, color: ct.$4),
                ],
              ),
            ],
          ),
        ),
      );
}

class _MaybeRefreshable extends StatelessWidget {
  const _MaybeRefreshable(this.list, {this.onRefresh});
  final Widget list;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) => switch (onRefresh) {
        final onRefreshValue? => RefreshIndicator(onRefresh: onRefreshValue, child: list),
        _ => list
      };
}

class _ListCard extends StatelessWidget {
  const _ListCard(this.rows);
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => PCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(borderRadius: BorderRadius.circular(AppRadii.lg), child: Column(children: rows)),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.children, this.last);
  final List<Widget> children;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: AppColors.ink100))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: children),
      );
}
