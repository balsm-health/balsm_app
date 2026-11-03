import 'dart:async';

import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pregnancy/pregnancy.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../shell.dart';
import '../../tokens.dart';
import '../family/family_kit.dart';
import '../family/member_screen.dart';
import 'pregnancy_kit.dart';

/// Opens the birth flow.
Future<void> openBirth(BuildContext context) => pushFamilyScreen<void>(context, (_) => const BirthScreen());

/// A baby has arrived (mother-child.jsx `MCBirthScreen`) — one baby at a
/// time, since births may be minutes or days apart. Sex is first asked here.
/// The baby's own profile becomes the child's (same id); the records about
/// this baby that stay ticked move with it, the others stay on the pregnancy.
class BirthScreen extends ConsumerStatefulWidget {
  const BirthScreen({super.key});
  @override
  ConsumerState<BirthScreen> createState() => _BirthScreenState();
}

class _BirthScreenState extends ConsumerState<BirthScreen> {
  HealthProfileId? _babyId;
  final _name = TextEditingController();
  Sex? _sex;
  DateTime? _dob = DateTime.now();
  BloodType? _blood;
  bool _bloodUnsure = false;

  /// Ticked records; null until the baby is chosen (then all of its records).
  Set<PregnancyItemId>? _keep;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _choose(PregnancyBaby b, List<PregnancyItem> items) {
    _babyId = b.id;
    _name.text = b.givenName ?? '';
    _sex = null;
    _blood = null;
    _bloodUnsure = false;
    _keep = {
      for (final i in items)
        if (i.isAbout(b.id)) i.id
    };
  }

  Future<void> _save(Pregnancy preg) async {
    final id = _babyId;
    if (id == null || _saving) return;
    setState(() => _saving = true);
    final r = await ref.read(recordBirthUseCaseProvider)(
      preg.id,
      BirthDetails(
        babyId: id,
        name: _name.text,
        sex: _sex,
        dateOfBirth: _dob,
        bloodType: _bloodUnsure ? null : _blood,
        keepItemIds: _keep ?? const {},
      ),
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
    unawaited(nav.push(MaterialPageRoute<void>(
      builder: (_) => Directionality(textDirection: dir, child: AdaptiveFrame(child: MemberScreen(id: id))),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final f = s.strings.family;
    final preg = ref.watch(activePregnancyProvider);
    if (preg == null) return const Scaffold(backgroundColor: Colors.white);
    final all = ref.watch(pregnancyBabiesProvider(preg.id)).valueOrNull ?? const <PregnancyBaby>[];
    final items = ref.watch(pregnancyItemsProvider(preg.id)).valueOrNull ?? const <PregnancyItem>[];
    final active = all.where((b) => b.isActive).toList();
    if (_babyId == null && active.length == 1) _choose(active.single, items);
    final b = active.where((x) => x.id == _babyId).firstOrNull;
    final multi = all.length > 1;
    final its = b == null ? const <PregnancyItem>[] : items.where((i) => i.isAbout(b.id)).toList();
    final keep = _keep ?? const <PregnancyItemId>{};
    final ok = b != null &&
        BirthDetails(babyId: b.id, name: _name.text, sex: _sex, dateOfBirth: _dob).violations(DateTime.now()).isEmpty;

    return FamilyScaffold(
      title: b != null && multi ? p.birth_title(babyLabel(s, b, all)) : p.birth_title_one,
      footer: PButton(p.create_cta,
          large: true, block: true, accent: s.accent, ar: s.rtl, onTap: ok && !_saving ? () => _save(preg) : null),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: babyWash, borderRadius: BorderRadius.circular(T.rLg)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.arrived_t, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
            Text(multi ? p.arrived_b_multi : p.arrived_b, style: Typo.bodySm(ar: s.rtl)),
          ]),
        ),
        if (active.length > 1)
          LabelledField(
            label: p.which,
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in active)
                BChip(
                  babyLabel(s, x, all),
                  active: x.id == _babyId,
                  accent: s.accent.main,
                  ar: s.rtl,
                  onTap: () => setState(() => _choose(x, items)),
                ),
            ]),
          ),
        if (b != null) ...[
          LabelledField(
            label: f.f_name,
            child: TextField(
              controller: _name,
              maxLength: BirthDetails.maxNameLength,
              onChanged: (_) => setState(() {}),
              decoration: fieldDecoration(s, null).copyWith(counterText: ''),
            ),
          ),
          LabelledField(
            label: f.f_sex,
            child: BalsmSegmented<Sex?>(
              options: const [Sex.female, Sex.male],
              labelOf: (x) => x == Sex.female ? f.sex_female : f.sex_male,
              selected: _sex,
              onChanged: (x) => setState(() => _sex = x),
            ),
          ),
          LabelledField(
            label: f.f_dob,
            child: DayField(
              value: _dob,
              placeholder: p.pick_date,
              onTap: () async {
                final now = DateTime.now();
                final picked = await pickDay(context,
                    title: f.f_dob, initial: _dob ?? now, first: now.subtract(const Duration(days: 365)), last: now);
                if (picked != null && mounted) setState(() => _dob = picked);
              },
            ),
          ),
          LabelledField(label: '${f.f_blood} · ${p.blood_if_known}', child: _bloodGrid(s)),
          LabelledField(
            label: p.moves,
            help: p.me_stay,
            child: its.isEmpty
                ? Text(p.no_records, style: Typo.meta(ar: s.rtl))
                : RowsCard(children: [
                    for (final it in its)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: BCheck(
                          label: [
                            it.title ?? itemKindLabel(s, it.kind),
                            '${itemKindLabel(s, it.kind)} · ${formatDay(it.recordedOn)}'
                                '${it.isShared ? ' · ${p.shared}' : ''}',
                          ].join('\n'),
                          checked: keep.contains(it.id),
                          accent: s.accent,
                          ar: s.rtl,
                          onTap: () => setState(() {
                            final k = _keep ??= {};
                            k.contains(it.id) ? k.remove(it.id) : k.add(it.id);
                          }),
                        ),
                      ),
                  ]),
          ),
        ],
      ],
    );
  }

  Widget _bloodGrid(PatientAppState s) {
    final types = BloodType.values.where((b) => b != BloodType.bombay).toList();
    return LayoutBuilder(builder: (context, c) {
      const gap = 8.0;
      final w = (c.maxWidth - gap * 3) / 4;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final b in types)
          SizedBox(
            width: w,
            child: BChip(
              b.code.replaceAll('-', '−'),
              active: !_bloodUnsure && _blood == b,
              accent: s.accent.main,
              ar: s.rtl,
              onTap: () => setState(() {
                _blood = b;
                _bloodUnsure = false;
              }),
            ),
          ),
        SizedBox(
          width: c.maxWidth,
          child: BChip(
            s.strings.family.blood_unsure,
            active: _bloodUnsure,
            accent: s.accent.main,
            ar: s.rtl,
            onTap: () => setState(() {
              _bloodUnsure = true;
              _blood = null;
            }),
          ),
        ),
      ]);
    });
  }
}
