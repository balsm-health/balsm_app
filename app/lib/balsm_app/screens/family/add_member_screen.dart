import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../kit.dart';
import 'family_kit.dart';
import 'member_form.dart';
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
  late final MemberFormKey _key = (form: Object(), editing: widget.editing);
  int _step = 1;
  bool _saving = false;

  PatientAppState get s => AppScope.of(context);
  bool get _editing => widget.editing != null;

  @override
  void dispose() {
    _name.dispose();
    _newGroupName.dispose();
    super.dispose();
  }

  /// Editing keeps the blood type as stored now: it is changed on the
  /// medical profile, which may have been opened from this form.
  BloodType? _storedBlood(FamilyMember editing) {
    final live = (ref.read(familyMembersProvider).value ?? const <FamilyMember>[]).where((x) => x.id == editing.id);
    return live.isEmpty ? editing.bloodType : live.first.bloodType;
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _saving) return;
    setState(() => _saving = true);
    final use = ref.read(saveFamilyMemberUseCaseProvider);
    final now = DateTime.now();
    final editing = widget.editing;
    final form = ref.read(memberFormProvider(_key));
    final result = editing == null
        ? await use.add(form.toSave(editing: false), userId: userId, now: now)
        : await use.update(
            editing.id,
            form.toSave(editing: true, storedBlood: _storedBlood(editing)),
            userId: userId,
            now: now,
          );
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

  @override
  Widget build(BuildContext context) {
    final f = s.strings.family;
    final now = DateTime.now();
    final (ok, adult) = ref.watch(
      memberFormProvider(_key).select((m) => (m.canSave(now), m.needsConsent(now, editing: _editing))),
    );
    if (_step == 2) {
      return _ConsentStep(
        formKey: _key,
        saving: _saving,
        onBack: () => setState(() => _step = 1),
        onSave: _save,
      );
    }
    final editing = widget.editing;
    final relation = _Labeled(label: f.f_relation, child: _RelationChips(formKey: _key));
    final name = _Labeled(
      label: f.f_name,
      child: TextField(
        controller: _name,
        onChanged: (v) => ref.read(memberFormProvider(_key).notifier).setName(v),
        style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textPrimary, fontSize: FontSizes.subhead),
        decoration: _memberInputDecoration(s, f.f_name_ph(s.gender)),
      ),
    );
    return FamilyScaffold(
      title: _editing ? f.edit_title : f.add_member,
      footer: PButton(
        adult ? f.next : (_editing ? f.save_changes : f.save),
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: ok && !_saving ? (adult ? () => setState(() => _step = 2) : _save) : null,
      ),
      children: [
        if (editing == null) ...[_Steps(step: 1, two: adult), relation, name] else ...[name, relation],
        _Labeled(label: f.f_group, child: _GroupPicker(formKey: _key, newGroupName: _newGroupName)),
        _Labeled(label: f.f_dob, child: _DobField(formKey: _key)),
        _Labeled(label: f.f_sex, child: _SexField(formKey: _key)),
        if (editing == null)
          _Labeled(label: '${f.f_blood} · ${f.optional}', child: _BloodField(formKey: _key))
        else
          _MedicalRow(member: editing),
        if (editing != null)
          _CloseMemberButton(
            formKey: _key,
            member: editing,
            onTap: _saving ? null : () => _close(editing),
          ),
      ],
    );
  }
}

/// The edit form's "close profile" action, named with the first word of the
/// name as typed (else the member's stored short name).
class _CloseMemberButton extends ConsumerWidget {
  const _CloseMemberButton({required this.formKey, required this.member, required this.onTap});
  final MemberFormKey formKey;
  final FamilyMember member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final typed = ref.watch(memberFormProvider(formKey).select((m) => m.draft.displayName.trim().split(' ').first));
    return PButton(
      s.strings.family.close_member(typed.isEmpty ? member.shortName : typed),
      icon: LucideIcons.archive,
      variant: BtnVariant.ghost,
      block: true,
      ar: s.rtl,
      color: AppColors.danger,
      onTap: onTap,
    );
  }
}

/// The edit form's way to the member's medical profile (blood type,
/// allergies, long-term conditions), which used to be fields here.
class _MedicalRow extends StatelessWidget {
  const _MedicalRow({required this.member});
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Semantics(
        button: true,
        child: PCard(
          onTap: () => openMemberMedical(context, member),
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
}

/// A form field with its label above.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
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
  }
}

class _RelationChips extends ConsumerWidget {
  const _RelationChips({required this.formKey});
  final MemberFormKey formKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final selected = ref.watch(memberFormProvider(formKey).select((m) => _Rel.of(m.draft.relationship, m.draft.sex)));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _Rel.values
          .map(
            (r) => BChip(
              r.label(s),
              active: selected == r,
              accent: s.accent.main,
              ar: s.rtl,
              onTap: () =>
                  ref.read(memberFormProvider(formKey).notifier).pickRelation(r.relationship, impliedSex: r.sex),
            ),
          )
          .toList(),
    );
  }
}

/// The member's group: an existing one, or a new one named here.
class _GroupPicker extends ConsumerWidget {
  const _GroupPicker({required this.formKey, required this.newGroupName});
  final MemberFormKey formKey;
  final TextEditingController newGroupName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final groups = ref.watch(memberGroupsProvider).value ?? const <MemberGroup>[];
    final (groupId, newGroup) = ref.watch(memberFormProvider(formKey).select((m) => (m.draft.groupId, m.newGroup)));
    final fallback = groups.where((g) => g.defaultGroup == DefaultGroup.family).firstOrNull?.id;
    final current = groupId ?? fallback;
    MemberFormNotifier notifier() => ref.read(memberFormProvider(formKey).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...groups.map(
              (g) => BChip(
                groupLabel(s, g),
                active: !newGroup && current == g.id,
                accent: s.accent.main,
                ar: s.rtl,
                onTap: () => notifier().selectGroup(g.id),
              ),
            ),
            BChip(
              '+ ${f.new_group}',
              active: newGroup,
              accent: s.accent.main,
              ar: s.rtl,
              onTap: () => notifier().startNewGroup(newGroupName.text),
            ),
          ],
        ),
        if (newGroup) ...[
          const SizedBox(height: 10),
          TextField(
            controller: newGroupName,
            autofocus: true,
            maxLength: MemberGroup.maxNameLength,
            onChanged: (v) => notifier().setNewGroupName(v),
            style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textPrimary),
            decoration: _memberInputDecoration(s, f.new_group_ph).copyWith(counterText: ''),
          ),
        ],
      ],
    );
  }
}

/// Date of birth, with the age it gives (and, for an adult being added, that
/// a consent step follows).
class _DobField extends ConsumerWidget {
  const _DobField({required this.formKey});
  final MemberFormKey formKey;

  Future<void> _pick(BuildContext context, WidgetRef ref, DateTime? dob) async {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final picked = await showBalsmDatePicker(
      context,
      initial: dob ?? DateTime(now.year - 5, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      title: s.strings.family.f_dob,
      confirmLabel: s.strings.onboarding.dob_confirm,
      months: s.strings.settings.cal_months.split('|'),
      weekdays: s.strings.settings.cal_weekdays.split('|'),
      rtl: s.rtl,
      accent: s.accent.main,
    );
    if (picked != null && context.mounted) ref.read(memberFormProvider(formKey).notifier).setDob(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final now = DateTime.now();
    final (dob, adult) = ref.watch(
      memberFormProvider(formKey)
          .select((m) => (m.draft.dateOfBirth, m.needsConsent(now, editing: formKey.editing != null))),
    );
    final age = dob == null ? null : MemberAge.between(dob, now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _pick(context, ref, dob),
          child: InputDecorator(
            decoration: _memberInputDecoration(s, null),
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
          Text([ageLabel(s, age), if (adult) f.consent_next].join(' · '), style: Typo.meta(ar: s.rtl)),
        ],
      ],
    );
  }
}

class _SexField extends ConsumerWidget {
  const _SexField({required this.formKey});
  final MemberFormKey formKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = AppScope.of(context).strings.family;
    final sex = ref.watch(memberFormProvider(formKey).select((m) => m.draft.sex));
    return BalsmSegmented<Sex?>(
      options: const [Sex.female, Sex.male],
      labelOf: (x) => x == Sex.female ? f.sex_female : f.sex_male,
      selected: sex,
      onChanged: (x) {
        if (x != null) ref.read(memberFormProvider(formKey).notifier).setSex(x);
      },
    );
  }
}

class _BloodField extends ConsumerWidget {
  const _BloodField({required this.formKey});
  final MemberFormKey formKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (blood, unsure) = ref.watch(memberFormProvider(formKey).select((m) => (m.draft.bloodType, m.bloodUnsure)));
    return BloodTypeGrid(
      value: blood,
      unsure: unsure,
      onChanged: (b) => ref.read(memberFormProvider(formKey).notifier).setBlood(b),
    );
  }
}

/// Step two for an adult: the account holder confirms the member's consent.
class _ConsentStep extends ConsumerWidget {
  const _ConsentStep({
    required this.formKey,
    required this.saving,
    required this.onBack,
    required this.onSave,
  });
  final MemberFormKey formKey;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final (first, consent, female) = ref.watch(
      memberFormProvider(formKey)
          .select((m) => (m.draft.displayName.trim().split(' ').first, m.consent, m.draft.sex == Sex.female)),
    );
    return FamilyScaffold(
      title: f.add_member,
      onBack: onBack,
      footer: PButton(
        f.add_cta(first),
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: consent && !saving ? onSave : null,
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
        ...[f.consent_stays, f.consent_close(s.gender)].map(
          (line) => Padding(
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
                checked: consent,
                accent: s.accent,
                ar: s.rtl,
                onTap: () => ref.read(memberFormProvider(formKey).notifier).toggleConsent(),
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
}

InputDecoration _memberInputDecoration(PatientAppState s, String? hint) => InputDecoration(
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
