import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../tokens.dart';
import 'family_kit.dart';

/// Opens the add-member form, or the same form to edit [editing]'s details.
Future<void> openAddMember(BuildContext context, {FamilyMember? editing}) =>
    pushFamilyScreen<void>(context, (_) => AddMemberScreen(editing: editing));

/// The design's relation chips (`MC_RELS` picks). A child or parent chip also
/// sets the member's sex; the stored relationship is the core
/// [Relationship], so a son is a child whose sex is male.
enum _Rel {
  son(Relationship.child, Sex.male),
  daughter(Relationship.child, Sex.female),
  mother(Relationship.parent, Sex.female),
  father(Relationship.parent, Sex.male),
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
/// same form rewrites an existing member's details, without the consent step.
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
        bloodType: _bloodUnsure ? null : _blood,
        groupId: _groupId,
        newGroupName: _newGroup ? _newGroupName.text : null,
      );

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
    if (mounted) Navigator.pop(context);
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
    return FamilyScaffold(
      title: _editing ? f.edit_details : f.add_member,
      footer: PButton(
        _adult ? f.next : f.save,
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: ok && !_saving ? (_adult ? () => setState(() => _step = 2) : _save) : null,
      ),
      children: [
        _Steps(step: 1, two: _adult),
        _field(f.f_relation, _chips()),
        _field(
          f.f_name,
          TextField(
            controller: _name,
            onChanged: (_) => setState(() {}),
            style: Typo.body(ar: s.rtl).copyWith(color: T.fg1, fontSize: FS.lg),
            decoration: _dec(f.f_name_ph(s.gender)),
          ),
        ),
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
        _field('${f.f_blood} · ${f.optional}', _bloodGrid()),
      ],
    );
  }

  Widget _field(String label, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
          const SizedBox(height: 8),
          child,
        ]),
      );

  Widget _chips() {
    final selected = _Rel.of(_relationship, _sex);
    return Wrap(spacing: 8, runSpacing: 8, children: [
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
    ]);
  }

  Widget _groups() {
    final f = s.strings.family;
    final groups = ref.watch(memberGroupsProvider).valueOrNull ?? const <MemberGroup>[];
    final fallback = groups.where((g) => g.defaultGroup == DefaultGroup.family).firstOrNull?.id;
    final current = _groupId ?? fallback;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
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
      ]),
      if (_newGroup) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _newGroupName,
          autofocus: true,
          maxLength: MemberGroup.maxNameLength,
          onChanged: (_) => setState(() {}),
          style: Typo.body(ar: s.rtl).copyWith(color: T.fg1),
          decoration: _dec(f.new_group_ph).copyWith(counterText: ''),
        ),
      ],
    ]);
  }

  Widget _dobField() {
    final f = s.strings.family;
    final dob = _dob;
    final age = dob == null ? null : MemberAge.between(dob, DateTime.now());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: _pickDob,
        child: InputDecorator(
          decoration: _dec(null),
          child: Row(children: [
            const Icon(LucideIcons.calendar, size: 17, color: T.fg3),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                dob == null ? f.f_dob_ph : formatDay(dob),
                textDirection: TextDirection.ltr,
                textAlign: s.rtl ? TextAlign.right : TextAlign.left,
                style: Typo.body(ar: s.rtl).copyWith(color: dob == null ? T.fg3 : T.fg1),
              ),
            ),
            const Icon(LucideIcons.chevronDown, size: 15, color: T.fg3),
          ]),
        ),
      ),
      if (age != null) ...[
        const SizedBox(height: 6),
        Text([ageLabel(s, age), if (_adult) f.consent_next].join(' · '), style: Typo.meta(ar: s.rtl)),
      ],
    ]);
  }

  Widget _bloodGrid() {
    final f = s.strings.family;
    final types = BloodType.values.where((b) => b != BloodType.bombay).toList();
    return LayoutBuilder(builder: (context, c) {
      const gap = 8.0;
      final w = (c.maxWidth - gap * 3) / 4;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final b in types)
          SizedBox(
            width: w,
            child: _GridChip(
              label: b.code.replaceAll('-', '−'),
              ltr: true,
              active: !_bloodUnsure && _blood == b,
              onTap: () => setState(() {
                _blood = b;
                _bloodUnsure = false;
              }),
            ),
          ),
        SizedBox(
          width: c.maxWidth,
          child: _GridChip(
            label: f.blood_unsure,
            active: _bloodUnsure,
            onTap: () => setState(() {
              _bloodUnsure = true;
              _blood = null;
            }),
          ),
        ),
      ]);
    });
  }

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
        Text(female ? f.consent_body_f(first, s.gender) : f.consent_body_m(first, s.gender),
            style: Typo.body(ar: s.rtl).copyWith(color: T.fg2)),
        const SizedBox(height: 16),
        for (final line in [f.consent_stays, f.consent_close(s.gender)])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(LucideIcons.check, size: 18, color: T.hueEmerald),
              const SizedBox(width: 10),
              Expanded(child: Text(line, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2))),
            ]),
          ),
        const SizedBox(height: 8),
        PCard(
          flat: true,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          ]),
        ),
      ],
    );
  }

  InputDecoration _dec(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (final (i, n) in (two ? [1, 2] : [1]).indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: n <= step ? s.accent.main : T.ink100,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Text(step == 2 ? f.step_2_of_2 : (two ? f.step_1_of_2 : f.step_basic), style: Typo.meta(ar: s.rtl)),
      ]),
    );
  }
}

/// A square-ish selectable chip for the blood-type grid.
class _GridChip extends StatelessWidget {
  const _GridChip({required this.label, required this.active, required this.onTap, this.ltr = false});
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool ltr;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Semantics(
      button: true,
      selected: active,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? s.accent.main : Colors.white,
            borderRadius: BorderRadius.circular(T.rPill),
            border: Border.all(color: active ? s.accent.main : T.border, width: 1.5),
          ),
          child: Text(
            label,
            textDirection: ltr ? TextDirection.ltr : null,
            style: (ltr ? Typo.num(size: FS.md, weight: FontWeight.w700) : Typo.bodySm(ar: s.rtl))
                .copyWith(fontWeight: FontWeight.w600, color: active ? T.onFill(s.accent.main) : T.fg2),
          ),
        ),
      ),
    );
  }
}
