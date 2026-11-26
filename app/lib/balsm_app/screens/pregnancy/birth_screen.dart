import 'dart:async';

import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pregnancy/pregnancy.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../shell.dart';
import '../family/family_kit.dart';
import '../family/member_screen.dart';
import 'pregnancy_drafts.dart';
import 'pregnancy_kit.dart';

/// Opens the birth flow.
Future<void> openBirth(BuildContext context, {HealthProfileId? mother}) =>
    pushFamilyScreen<void>(context, (_) => BirthScreen(mother: mother));

/// A baby has arrived (mother-child.jsx `MCBirthScreen`) — one baby at a
/// time, since births may be minutes or days apart. Sex is first asked here.
/// The baby's own profile becomes the child's (same id); the records about
/// this baby that stay ticked move with it, the others stay on the pregnancy.
class BirthScreen extends ConsumerStatefulWidget {
  const BirthScreen({super.key, this.mother});

  /// Whose pregnancy (null = the account holder's own).
  final HealthProfileId? mother;
  @override
  ConsumerState<BirthScreen> createState() => _BirthScreenState();
}

class _BirthScreenState extends ConsumerState<BirthScreen> {
  final _name = TextEditingController();
  late final BirthDraftKey _key = (form: Object(), mother: widget.mother);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Choosing a baby (by tap, or by itself when only one is followed) seeds
    // the name field with the name given during the pregnancy.
    ref.listenManual(
      birthDraftProvider(_key).select((d) => d.babyId),
      (_, __) => _name.text = ref.read(birthDraftProvider(_key)).name,
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// The child's relationship to the account holder (mother-child.jsx
  /// `MCBirthScreen`): their child when the mother is the account holder or
  /// their spouse or partner; otherwise a relative (core has no grandchild).
  Future<Relationship> _relationship() async {
    final mother = widget.mother;
    final owner =
        mother == null ? null : (await ref.read(familyMembersProvider.future)).where((m) => m.id == mother).firstOrNull;
    return switch (owner?.relationship) {
      null || Relationship.spouse || Relationship.partner => Relationship.child,
      _ => Relationship.relative,
    };
  }

  Future<void> _save(Pregnancy preg) async {
    if (_saving || ref.read(birthDraftProvider(_key)).babyId == null) return;
    setState(() => _saving = true);
    final relationship = await _relationship();
    if (!mounted) return;
    final details = ref.read(birthDraftProvider(_key)).details(relationship: relationship);
    if (details == null) {
      setState(() => _saving = false);
      return;
    }
    final id = details.babyId;
    final r = await ref.read(recordBirthUseCaseProvider)(
      preg.id,
      details,
      motherId: preg.motherId,
      now: DateTime.now(),
    );
    if (!mounted) return;
    if (r.isFailure) {
      setState(() => _saving = false);
      final s = AppScope.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.strings.family.save_failed(s.gender))));
      return;
    }
    // The design makes the newborn the active profile and opens their home;
    // the pregnancy stays underneath while other babies are still followed.
    await ref.read(activeProfileSwitcherProvider).select(id);
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    final dir = AppScope.of(context).dir;
    if (r.value.isActive) {
      nav.pop();
    } else {
      nav.popUntil((route) => route.isFirst);
    }
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => Directionality(textDirection: dir, child: AdaptiveFrame(child: MemberScreen(id: id))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final f = s.strings.family;
    // `_relationship` awaits the family members when Create is tapped. Riverpod 3 pauses a stream provider that
    // nothing listens to (a `ref.read` does not count), so keep it subscribed while this screen is open.
    ref.watch(familyMembersProvider);
    final preg = ref.watch(activePregnancyOfProvider(widget.mother));
    if (preg == null) return const Scaffold(backgroundColor: AppColors.white);
    final all = ref.watch(pregnancyBabiesProvider(preg.id)).value ?? const <PregnancyBaby>[];
    final items = ref.watch(pregnancyItemsProvider(preg.itemsKey)).value ?? const <PregnancyItem>[];
    final active = all.where((b) => b.isActive).toList();
    final now = DateTime.now();
    final (babyId, valid) = ref.watch(birthDraftProvider(_key).select((d) => (d.babyId, d.valid(now))));
    final b = active.where((x) => x.id == babyId).firstOrNull;
    final multi = all.length > 1;
    final its = b == null ? const <PregnancyItem>[] : items.where((i) => i.isAbout(b.id)).toList();
    final ok = b != null && valid;
    BirthDraftNotifier draft() => ref.read(birthDraftProvider(_key).notifier);

    return FamilyScaffold(
      title: b != null && multi ? p.birth_title(babyLabel(s, b, all)) : p.birth_title_one,
      footer: PButton(
        p.create_cta,
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: ok && !_saving ? () => _save(preg) : null,
      ),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: babyWash, borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.arrived_t,
                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Text(multi ? p.arrived_b_multi : p.arrived_b, style: Typo.bodySm(ar: s.rtl)),
            ],
          ),
        ),
        if (active.length > 1)
          LabelledField(
            label: p.which,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: active
                  .map(
                    (x) => BChip(
                      babyLabel(s, x, all),
                      active: x.id == babyId,
                      accent: s.accent.main,
                      ar: s.rtl,
                      onTap: () => draft().choose(x, items),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (b != null) ...[
          LabelledField(
            label: f.f_name,
            child: TextField(
              controller: _name,
              maxLength: BirthDetails.maxNameLength,
              onChanged: (v) => draft().setName(v),
              decoration: fieldDecoration(s, null).copyWith(counterText: ''),
            ),
          ),
          LabelledField(label: f.f_sex, child: _BirthSexField(draftKey: _key)),
          LabelledField(label: f.f_dob, child: _BirthDobField(draftKey: _key)),
          LabelledField(label: '${f.f_blood} · ${p.blood_if_known}', child: _BirthBloodField(draftKey: _key)),
          LabelledField(
            label: p.moves,
            help: p.me_stay,
            child: its.isEmpty
                ? Text(p.no_records, style: Typo.meta(ar: s.rtl))
                : _KeepRecords(draftKey: _key, items: its),
          ),
        ],
      ],
    );
  }
}

class _BirthSexField extends ConsumerWidget {
  const _BirthSexField({required this.draftKey});
  final BirthDraftKey draftKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = AppScope.of(context).strings.family;
    return BalsmSegmented<Sex?>(
      options: const [Sex.female, Sex.male],
      labelOf: (x) => x == Sex.female ? f.sex_female : f.sex_male,
      selected: ref.watch(birthDraftProvider(draftKey).select((d) => d.sex)),
      onChanged: (x) {
        if (x != null) ref.read(birthDraftProvider(draftKey).notifier).setSex(x);
      },
    );
  }
}

/// The date of birth: within the last year, not after today.
class _BirthDobField extends ConsumerWidget {
  const _BirthDobField({required this.draftKey});
  final BirthDraftKey draftKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final dob = ref.watch(birthDraftProvider(draftKey).select((d) => d.dob));
    return DayField(
      value: dob,
      placeholder: s.strings.pregnancy.pick_date,
      onTap: () async {
        final now = DateTime.now();
        final picked = await pickDay(
          context,
          title: s.strings.family.f_dob,
          initial: dob ?? now,
          first: now.subtract(const Duration(days: 365)),
          last: now,
        );
        if (picked != null && context.mounted) ref.read(birthDraftProvider(draftKey).notifier).setDob(picked);
      },
    );
  }
}

class _BirthBloodField extends ConsumerWidget {
  const _BirthBloodField({required this.draftKey});
  final BirthDraftKey draftKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (blood, unsure) = ref.watch(birthDraftProvider(draftKey).select((d) => (d.blood, d.bloodUnsure)));
    return BloodTypeGrid(
      value: blood,
      unsure: unsure,
      onChanged: (b) => ref.read(birthDraftProvider(draftKey).notifier).setBlood(b),
    );
  }
}

/// The records about this baby, each ticked to move with it.
class _KeepRecords extends ConsumerWidget {
  const _KeepRecords({required this.draftKey, required this.items});
  final BirthDraftKey draftKey;
  final List<PregnancyItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final keep = ref.watch(birthDraftProvider(draftKey).select((d) => d.keep));
    return RowsCard(
      children: items
          .map(
            (it) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: BCheck(
                label: [
                  it.title ?? itemKindLabel(s, it.kind),
                  '${itemKindLabel(s, it.kind)} · ${formatDay(it.recordedOn)}${it.isShared ? ' · ${p.shared}' : ''}',
                ].join('\n'),
                checked: keep.contains(it.id),
                accent: s.accent,
                ar: s.rtl,
                onTap: () => ref.read(birthDraftProvider(draftKey).notifier).toggleKeep(it.id),
              ),
            ),
          )
          .toList(),
    );
  }
}
