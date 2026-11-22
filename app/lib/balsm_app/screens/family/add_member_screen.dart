import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../kit.dart';
import 'family_kit.dart';
import 'member_medical_screen.dart';

// Half the 4pt step bar height, so its ends are round.
const _stepBarRadius = 2.0;

/// Opens the add-member form, or the same form to edit [editing]'s details.
/// True when the edit form closed [editing]'s profile.
Future<bool> openAddMember(BuildContext context, {FamilyMember? editing}) async =>
    await pushFamilyScreen<bool>(context, (_) => AddMemberScreen(editing: editing)) ?? false;

/// The design's relation chips (`MC_RELS` picks). A child or parent chip also
/// sets the member's sex; the stored relationship is the core
/// [Relationship], so a son is a child whose sex is male.
enum _Rel {
  son(Relationship.child, Sex.male),
  daughter(Relationship.child, Sex.female),
  mother(Relationship.parent, Sex.female),
  father(Relationship.parent, Sex.male),
  sister(Relationship.sibling, Sex.female),
  brother(Relationship.sibling, Sex.male),
  spouse(Relationship.spouse, null),
  neighbour(Relationship.neighbour, null),
  friend(Relationship.friend, null),
  other(Relationship.other, null);

  const _Rel(this.relationship, this.sex);
  final Relationship relationship;
  final Sex? sex;

  String label(PatientAppState s) {
    final f = s.strings.family;
    return switch (this) {
      _Rel.son => f.pick_son,
      _Rel.daughter => f.pick_daughter,
      _Rel.mother => f.pick_mother,
      _Rel.father => f.pick_father,
      _Rel.sister => f.pick_sister,
      _Rel.brother => f.pick_brother,
      _Rel.spouse => f.pick_spouse,
      _Rel.neighbour => f.pick_neighbour,
      _Rel.friend => f.pick_friend,
      _Rel.other => f.pick_other,
    };
  }

  /// The chip showing for a stored relationship and sex.
  static _Rel? of(Relationship? rel, Sex? sex) {
    for (final r in values) {
      if (r.relationship == rel && (r.sex == null || r.sex == sex)) return r;
    }
    return rel == null ? null : _Rel.other;
  }
}

/// Add family member (mother-child.jsx `MCAddMemberScreen`, manual mode):
/// relation, name, group, date of birth, sex and an optional blood type; an
/// adult gets a second step confirming their consent. With [editing] the
/// same form is the design's `MCEditMemberScreen`: "Edit profile", name
/// first, "Save changes", and a close-profile action under the fields (the
/// design deletes; the app soft-closes and keeps the records). Pops `true`
/// when the profile was closed.
class AddMemberScreen extends ConsumerStatefulWidget {
  const AddMemberScreen({super.key, this.editing});
  final FamilyMember? editing;
  @override
  ConsumerState<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends ConsumerState<AddMemberScreen> {
  late final _name = TextEditingController(text: widget.editing?.displayName ?? '');
  final _newGroupName = TextEditingController();
  late Relationship? _relationship = widget.editing?.relationship;
  late Sex? _sex = widget.editing?.sex;
  late DateTime? _dob = widget.editing?.dateOfBirth;
  late BloodType? _blood = widget.editing?.bloodType;
  bool _bloodUnsure = false;
  late MemberGroupId? _groupId = widget.editing?.groupId;
  bool _newGroup = false;
  int _step = 1;
  bool _consent = false;
  bool _saving = false;

  PatientAppState get s => AppScope.of(context);
  bool get _editing => widget.editing != null;

  @override
  void dispose() {
    _name.dispose();
    _newGroupName.dispose();
    super.dispose();
  }

  MemberDraft get _draft => MemberDraft(
        displayName: _name.text,
        relationship: _relationship,
        dateOfBirth: _dob,
        sex: _sex,
        bloodType: _editing ? _storedBlood : (_bloodUnsure ? null : _blood),
        groupId: _groupId,
        newGroupName: _newGroup ? _newGroupName.text : null,
      );

  /// Editing keeps the blood type as stored now: it is changed on the
  /// medical profile, which may have been opened from this form.
  BloodType? get _storedBlood {
    final id = widget.editing!.id;
    final live = (ref.read(familyMembersProvider).value ?? const <FamilyMember>[]).where((x) => x.id == id);
    return live.isEmpty ? widget.editing!.bloodType : live.first.bloodType;
  }

  bool get _adult => !_editing && _draft.needsConsentOn(DateTime.now());

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _saving) return;
    setState(() => _saving = true);
    final use = ref.read(saveFamilyMemberUseCaseProvider);
    final now = DateTime.now();
    final editing = widget.editing;
    final result = editing == null
        ? await use.add(_draft, userId: userId, now: now)
        : await use.update(editing.id, _draft, userId: userId, now: now);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.strings.family.save_failed(s.gender))));
      return;
    }
    // The design makes a newly added member the active profile.
    if (editing == null) await ref.read(activeProfileSwitcherProvider).select(result.value.id);
    if (mounted) Navigator.pop(context, false);
  }

  Future<void> _close(FamilyMember m) async {
    if (await confirmCloseMember(context, ref, m) && mounted) Navigator.pop(context, true);
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showBalsmDatePicker(
      context,
      initial: _dob ?? DateTime(now.year - 5, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      title: s.strings.family.f_dob,
      confirmLabel: s.strings.onboarding.dob_confirm,
      months: s.strings.settings.cal_months.split('|'),
      weekdays: s.strings.settings.cal_weekdays.split('|'),
      rtl: s.rtl,
      accent: s.accent.main,
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    final f = s.strings.family;
    final ok = _draft.violations(DateTime.now()).isEmpty;
    if (_step == 2) return _consentStep();
    final editing = widget.editing;
    final relation = _field(f.f_relation, _chips());
    final name = _field(
      f.f_name,
      TextField(
        controller: _name,
        onChanged: (_) => setState(() {}),
        style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textPrimary, fontSize: FontSizes.subhead),
        decoration: _dec(f.f_name_ph(s.gender)),
      ),
    );
    return FamilyScaffold(
      title: _editing ? f.edit_title : f.add_member,
      footer: PButton(
        _adult ? f.next : (_editing ? f.save_changes : f.save),
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: ok && !_saving ? (_adult ? () => setState(() => _step = 2) : _save) : null,
      ),
      children: [
        if (editing == null) ...[_Steps(step: 1, two: _adult), relation, name] else ...[name, relation],
        _field(f.f_group, _groups()),
        _field(f.f_dob, _dobField()),
        _field(
          f.f_sex,
          BalsmSegmented<Sex?>(
            options: const [Sex.female, Sex.male],
            labelOf: (x) => x == Sex.female ? f.sex_female : f.sex_male,
            selected: _sex,
            onChanged: (x) => setState(() => _sex = x),
          ),
        ),
        if (editing == null) _field('${f.f_blood} · ${f.optional}', _bloodGrid()) else _medicalRow(editing),
        if (editing != null)
          PButton(
            f.close_member(_firstName(editing)),
            icon: LucideIcons.archive,
            variant: BtnVariant.ghost,
            block: true,
            ar: s.rtl,
            color: AppColors.danger,
            onTap: _saving ? null : () => _close(editing),
          ),
      ],
    );
  }

  /// The edit form's way to the member's medical profile (blood type,
  /// allergies, long-term conditions), which used to be fields here.
  Widget _medicalRow(FamilyMember m) {
    final f = s.strings.family;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Semantics(
        button: true,
        child: PCard(
          onTap: () => openMemberMedical(context, m),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(LucideIcons.clipboardList, size: 18, color: s.accent.main),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.tile_medical,
                      style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    Text(f.medical_row_sub, style: Typo.meta(ar: s.rtl)),
                  ],
                ),
              ),
              Icon(forwardChevron(context), size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  /// The first word of the name as typed, else the member's stored short name.
  String _firstName(FamilyMember m) {
    final typed = _name.text.trim().split(' ').first;
    return typed.isEmpty ? m.shortName : typed;
  }

  Widget _field(String label, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _chips() {
    final selected = _Rel.of(_relationship, _sex);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final r in _Rel.values)
          BChip(
            r.label(s),
            active: selected == r,
            accent: s.accent.main,
            ar: s.rtl,
            onTap: () => setState(() {
              _relationship = r.relationship;
              if (r.sex != null) _sex = r.sex;
            }),
          ),
      ],
    );
  }

  Widget _groups() {
    final f = s.strings.family;
    final groups = ref.watch(memberGroupsProvider).value ?? const <MemberGroup>[];
    final fallback = groups.where((g) => g.defaultGroup == DefaultGroup.family).firstOrNull?.id;
    final current = _groupId ?? fallback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in groups)
              BChip(
                groupLabel(s, g),
                active: !_newGroup && current == g.id,
                accent: s.accent.main,
                ar: s.rtl,
                onTap: () => setState(() {
                  _groupId = g.id;
                  _newGroup = false;
                }),
              ),
            BChip(
              '+ ${f.new_group}',
              active: _newGroup,
              accent: s.accent.main,
              ar: s.rtl,
              onTap: () => setState(() => _newGroup = true),
            ),
          ],
        ),
        if (_newGroup) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _newGroupName,
            autofocus: true,
            maxLength: MemberGroup.maxNameLength,
            onChanged: (_) => setState(() {}),
            style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textPrimary),
            decoration: _dec(f.new_group_ph).copyWith(counterText: ''),
          ),
        ],
      ],
    );
  }

  Widget _dobField() {
    final f = s.strings.family;
    final dob = _dob;
    final age = dob == null ? null : MemberAge.between(dob, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickDob,
          child: InputDecorator(
            decoration: _dec(null),
            child: Row(
              children: [
                const Icon(LucideIcons.calendar, size: 17, color: AppColors.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dob == null ? f.f_dob_ph : formatDay(dob),
                    textDirection: TextDirection.ltr,
                    textAlign: s.rtl ? TextAlign.right : TextAlign.left,
                    style: Typo.body(ar: s.rtl)
                        .copyWith(color: dob == null ? AppColors.textTertiary : AppColors.textPrimary),
                  ),
                ),
                const Icon(LucideIcons.chevronDown, size: 15, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
        if (age != null) ...[
          const SizedBox(height: 6),
          Text([ageLabel(s, age), if (_adult) f.consent_next].join(' · '), style: Typo.meta(ar: s.rtl)),
        ],
      ],
    );
  }

  Widget _bloodGrid() => BloodTypeGrid(
        value: _blood,
        unsure: _bloodUnsure,
        onChanged: (b) => setState(() {
          _blood = b;
          _bloodUnsure = b == null;
        }),
      );

  Widget _consentStep() {
    final f = s.strings.family;
    final first = _name.text.trim().split(' ').first;
    final female = _sex == Sex.female;
    return FamilyScaffold(
      title: f.add_member,
      onBack: () => setState(() => _step = 1),
      footer: PButton(
        f.add_cta(first),
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: _consent && !_saving ? _save : null,
      ),
      children: [
        const _Steps(step: 2, two: true),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child:
              IconSquare(LucideIcons.shieldCheck, bg: s.accent.bg, fg: s.accent.d, size: 52, iconSize: 26, radius: 16),
        ),
        const SizedBox(height: 16),
        Text(f.consent_title(first, s.gender), style: Typo.heading(ar: s.rtl)),
        const SizedBox(height: 8),
        Text(
          female ? f.consent_body_f(first, s.gender) : f.consent_body_m(first, s.gender),
          style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        for (final line in [f.consent_stays, f.consent_close(s.gender)])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.check, size: 18, color: AppColors.hueEmerald),
                const SizedBox(width: 10),
                Expanded(child: Text(line, style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textSecondary))),
              ],
            ),
          ),
        const SizedBox(height: 8),
        PCard(
          flat: true,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BCheck(
                label: female ? f.consent_check_f(first) : f.consent_check_m(first),
                checked: _consent,
                accent: s.accent,
                ar: s.rtl,
                onTap: () => setState(() => _consent = !_consent),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 32, top: 4),
                child: Text(f.consent_hint, style: Typo.meta(ar: s.rtl)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _dec(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: Typo.body(ar: s.rtl).copyWith(color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: s.accent.main, width: 1.5),
        ),
      );
}

/// Step indicator: one bar for a child, two once the member is an adult.
class _Steps extends StatelessWidget {
  const _Steps({required this.step, required this.two});
  final int step;
  final bool two;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final (i, n) in (two ? [1, 2] : [1]).indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: n <= step ? s.accent.main : AppColors.ink100,
                      borderRadius: BorderRadius.circular(_stepBarRadius),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(step == 2 ? f.step_2_of_2 : (two ? f.step_1_of_2 : f.step_basic), style: Typo.meta(ar: s.rtl)),
        ],
      ),
    );
  }
}
