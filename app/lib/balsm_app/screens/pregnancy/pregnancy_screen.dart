import 'dart:async';

import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pregnancy/pregnancy.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../family/family_kit.dart';
import '../family/member_screen.dart';
import 'baby_screen.dart';
import 'birth_screen.dart';
import 'pregnancy_add_screen.dart';
import 'pregnancy_card_screen.dart';
import 'pregnancy_guidance.dart';
import 'pregnancy_kit.dart';
import 'pregnancy_start_screen.dart';

/// Opens the pregnancy — the tracker when one is active, otherwise the start
/// screen. A pregnancy lives on the mother's own profile: the account
/// holder's, or with [mother] a family member's whose profile they manage
/// (design `MCPregWho`); hers is made the active profile first (design
/// `MCPregScreen`). Weekly guidance is asked for again on every opening.
Future<void> openPregnancy(BuildContext context, WidgetRef ref, {HealthProfileId? mother}) async {
  ref.invalidate(pregnancyGuidanceProvider);
  final switcher = ref.read(activeProfileSwitcherProvider);
  await (mother == null ? switcher.selectSelf() : switcher.select(mother));
  final all = await ref.read(pregnanciesOfProvider(mother).future);
  if (!context.mounted) return;
  final active = all.any((p) => p.isActive);
  await pushFamilyScreen<void>(
    context,
    (_) => active ? PregnancyScreen(mother: mother) : PregnancyStartScreen(mother: mother),
  );
}

/// Leaves the pregnancy once it has closed: back to the tab bar, or for a
/// family member's pregnancy back to her screen.
void leavePregnancy(BuildContext context, {HealthProfileId? mother}) {
  Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  if (mother != null) unawaited(openMember(context, mother));
}

/// The pregnancy tracker (mother-child.jsx `MCPregScreen`): week hero and
/// trimester bar, next visit, this week's guidance, the babies, the mother's
/// own records, the pregnancy-mode emergency card, and birth / end. With
/// [mother] it is a family member's pregnancy, titled with her name.
class PregnancyScreen extends ConsumerWidget {
  const PregnancyScreen({super.key, this.mother});

  /// Whose pregnancy (null = the account holder's own).
  final HealthProfileId? mother;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final preg = ref.watch(activePregnancyOfProvider(mother));
    final owner = pregnancyOwner(ref, mother);
    if (preg == null) return const Scaffold(backgroundColor: AppColors.white);
    final babies = ref.watch(pregnancyBabiesProvider(preg.id)).value ?? const <PregnancyBaby>[];
    final items = ref.watch(pregnancyItemsProvider(preg.itemsKey)).value ?? const <PregnancyItem>[];
    final active = babies.where((b) => b.isActive).toList();
    final born = babies.where((b) => b.isBorn).toList();
    final multi = babies.length > 1;
    final mine = items.where((i) => i.about == ItemAbout.me).toList();

    return FamilyScaffold(
      title: owner == null ? p.title : p.title_of(owner.shortName),
      children: [
        _Hero(pregnancy: preg),
        const SizedBox(height: 12),
        _NextVisitCard(pregnancy: preg),
        PregnancyGuidanceCard(week: preg.infoOn(DateTime.now()).week, multiples: multi, mother: mother),
        Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  multi ? p.babies : p.baby,
                  style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _LinkButton(
                icon: LucideIcons.paperclip,
                label: p.attach,
                onTap: () => openPregnancyAdd(context, mother: mother),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            const gap = 10.0;
            final w = active.length > 1 ? (c.maxWidth - gap) / 2 : c.maxWidth;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final b in active)
                  SizedBox(
                    width: w,
                    child: _BabyCard(pregnancy: preg, baby: b, babies: babies, items: items, mother: mother),
                  ),
              ],
            );
          },
        ),
        if (born.isNotEmpty) ...[
          const SizedBox(height: 10),
          RowsCard(children: [for (final b in born) _BornRow(baby: b)]),
        ],
        // The domain refuses a baby past the limit; hiding the button keeps
        // that from ever looking like a failed tap.
        if (babies.length < Pregnancy.maxBabies)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _LinkButton(icon: LucideIcons.plus, label: p.add_baby, onTap: () => _addBaby(context, ref, preg)),
            ),
          ),
        FamilySecHead(owner == null ? p.my_records : p.records_of(owner.shortName)),
        if (mine.isEmpty)
          Text(owner == null ? p.my_records_empty : p.records_of_empty, style: Typo.bodySm(ar: s.rtl))
        else
          RowsCard(children: [for (final it in mine) PregnancyItemRow(item: it, pregnancy: preg, babies: babies)]),
        const SizedBox(height: 12),
        RowsCard(
          children: [
            ChevronRow(
              icon: LucideIcons.idCard,
              label: p.card_row,
              onTap: () => openPregnancyCard(context, mother: mother),
            ),
          ],
        ),
        FamilySecHead(p.birth_sec),
        RowsCard(
          children: [
            if (active.isNotEmpty)
              ChevronRow(
                label: multi ? p.arrived_multi : p.arrived_one,
                onTap: () => openBirth(context, mother: mother),
              ),
            ChevronRow(label: p.end_t, onTap: () => _confirmEnd(context, ref, preg)),
          ],
        ),
      ],
    );
  }

  Future<void> _addBaby(BuildContext context, WidgetRef ref, Pregnancy preg) async {
    final self = preg.motherId;
    final r = await ref.read(pregnancyBabiesUseCaseProvider).add(preg.id, motherId: self, now: DateTime.now());
    if (r.isFailure && context.mounted) _failed(context);
  }

  Future<void> _confirmEnd(BuildContext context, WidgetRef ref, Pregnancy preg) async {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final yes = await _confirmSheet(context, title: p.end_t, body: p.end_b, cta: p.end_cta);
    if (yes != true || !context.mounted) return;
    final r = await ref.read(endPregnancyUseCaseProvider)(preg.id, motherId: preg.motherId, now: DateTime.now());
    if (!context.mounted) return;
    r.isSuccess ? leavePregnancy(context, mother: mother) : _failed(context);
  }
}

void _failed(BuildContext context) {
  final s = AppScope.of(context);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.strings.family.save_failed(s.gender))));
}

/// A confirmation sheet with a secondary action and "Go back"; pops true.
Future<bool?> _confirmSheet(BuildContext context, {required String title, required String body, required String cta}) {
  final s = AppScope.of(context);
  return showAppSheet<bool>(
    context,
    textDirection: s.dir,
    builder: (ctx) => FamilySheet(
      title: title,
      children: [
        Text(body, style: Typo.body(ar: s.rtl)),
        const SizedBox(height: 18),
        PButton(
          cta,
          large: true,
          block: true,
          variant: BtnVariant.secondary,
          ar: s.rtl,
          onTap: () => Navigator.pop(ctx, true),
        ),
        const SizedBox(height: 8),
        PButton(
          s.strings.pregnancy.go_back,
          large: true,
          block: true,
          variant: BtnVariant.ghost,
          ar: s.rtl,
          onTap: () => Navigator.pop(ctx, false),
        ),
      ],
    ),
  );
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: s.accent.d),
              const SizedBox(width: 6),
              Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: s.accent.d)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Week number, day and trimester, the trimester bar, days left and due date.
class _Hero extends StatelessWidget {
  const _Hero({required this.pregnancy});
  final Pregnancy pregnancy;
  static const _flex = [13, 14, 13];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final info = pregnancy.infoOn(DateTime.now());
    final w = info.week;
    final fill = [
      (w / 13).clamp(0.0, 1.0),
      ((w - 13) / 14).clamp(0.0, 1.0),
      ((w - 27) / 13).clamp(0.0, 1.0),
    ];
    final shorts = [p.tri_short_1, p.tri_short_2, p.tri_short_3];
    Widget tile(String big, String small, {bool large = true}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadii.control)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  big,
                  textDirection: TextDirection.ltr,
                  style: large
                      ? Typo.num(size: FontSizes.heading, weight: FontWeight.w800)
                      : Typo.num().copyWith(height: 1.6),
                ),
                Text(small, style: Typo.meta(ar: s.rtl)),
              ],
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: babyWash, borderRadius: BorderRadius.circular(AppRadii.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.week, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: babyInk)),
                  Text('$w', style: Typo.num(size: 56, weight: FontWeight.w800).copyWith(height: 1)),
                ],
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${p.day_n(info.day)} · ${trimesterLabel(s, info.trimester)}',
                    style: Typo.bodySm(ar: s.rtl),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  flex: _flex[i],
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: Container(
                      height: 6,
                      color: AppColors.white,
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: fill[i],
                        child: Container(color: AppColors.hueAqua),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  flex: _flex[i],
                  child: Text(
                    shorts[i],
                    style: Typo.meta(ar: s.rtl).copyWith(
                      fontSize: FontSizes.eyebrow,
                      color: i + 1 == info.trimester ? AppColors.textPrimary : AppColors.textTertiary,
                      fontWeight: i + 1 == info.trimester ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Past the due date the count goes up again, labelled as such.
              tile('${info.daysLeft.abs()}', info.daysLeft < 0 ? p.days_past_due_label : p.days_to_due),
              const SizedBox(width: 8),
              tile(formatDay(pregnancy.dueDate), p.due_date, large: false),
            ],
          ),
        ],
      ),
    );
  }
}

/// The next antenatal visit, or a row to add one. Either opens the visit sheet.
class _NextVisitCard extends ConsumerWidget {
  const _NextVisitCard({required this.pregnancy});
  final Pregnancy pregnancy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final v = pregnancy.nextVisit;
    void edit() => showAppSheet<void>(context, textDirection: s.dir, builder: (_) => _VisitSheet(pregnancy: pregnancy));
    if (v == null) return RowsCard(children: [ChevronRow(icon: LucideIcons.calendar, label: p.add_visit, onTap: edit)]);
    final when = [formatDay(v.date), if (v.time case final time?) time].join(' · ');
    final who = [if (pregnancy.obName case final obName?) obName, if (v.clinic case final clinic?) clinic].join(' · ');
    return Semantics(
      button: true,
      child: PCard(
        onTap: edit,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconSquare(LucideIcons.calendar, bg: s.accent.bg, fg: s.accent.d, size: 42, iconSize: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.next_visit_t, style: Typo.meta(ar: s.rtl)),
                  Text(
                    when,
                    textDirection: TextDirection.ltr,
                    textAlign: s.rtl ? TextAlign.right : TextAlign.left,
                    style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  if (who.isNotEmpty) Text(who, style: Typo.meta(ar: s.rtl)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitSheet extends ConsumerStatefulWidget {
  const _VisitSheet({required this.pregnancy});
  final Pregnancy pregnancy;
  @override
  ConsumerState<_VisitSheet> createState() => _VisitSheetState();
}

class _VisitSheetState extends ConsumerState<_VisitSheet> {
  late DateTime? _date = widget.pregnancy.nextVisit?.date;
  late final _time = TextEditingController(text: widget.pregnancy.nextVisit?.time ?? '');
  late final _clinic = TextEditingController(text: widget.pregnancy.nextVisit?.clinic ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _time.dispose();
    _clinic.dispose();
    super.dispose();
  }

  Future<void> _save(NextVisit? visit) async {
    if (_saving) return;
    setState(() => _saving = true);
    final r = await ref
        .read(pregnancyRecordsUseCaseProvider)
        .setNextVisit(widget.pregnancy.id, visit, motherId: widget.pregnancy.motherId, now: DateTime.now());
    if (!mounted) return;
    setState(() => _saving = false);
    r.isSuccess ? Navigator.pop(context) : _failed(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final now = DateTime.now();
    final date = _date;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FamilySheet(
        title: p.next_visit_t,
        children: [
          LabelledField(
            label: p.visit_date,
            child: DayField(
              value: date,
              placeholder: p.pick_date,
              onTap: () async {
                final picked = await pickDay(
                  context,
                  title: p.visit_date,
                  initial: date ?? now,
                  first: now,
                  last: now.add(const Duration(days: 300)),
                );
                if (picked != null && mounted) setState(() => _date = picked);
              },
            ),
          ),
          LabelledField(
            label: p.visit_time,
            child: TextField(
              controller: _time,
              keyboardType: TextInputType.datetime,
              textDirection: TextDirection.ltr,
              decoration: fieldDecoration(s, p.visit_time_ph),
            ),
          ),
          LabelledField(
            label: p.visit_clinic,
            child: TextField(controller: _clinic, decoration: fieldDecoration(s, null)),
          ),
          PButton(
            s.strings.family.save,
            large: true,
            block: true,
            accent: s.accent,
            ar: s.rtl,
            onTap: date == null || _saving
                ? null
                : () => _save(NextVisit(date: date, time: _time.text, clinic: _clinic.text)),
          ),
          if (widget.pregnancy.nextVisit != null) ...[
            const SizedBox(height: 8),
            PButton(
              p.visit_remove,
              large: true,
              block: true,
              variant: BtnVariant.ghost,
              ar: s.rtl,
              onTap: _saving ? null : () => _save(null),
            ),
          ],
        ],
      ),
    );
  }
}

/// `MCBabyCard` — label, record count, menu, and the last measurement.
class _BabyCard extends ConsumerWidget {
  const _BabyCard({
    required this.pregnancy,
    required this.baby,
    required this.babies,
    required this.items,
    required this.mother,
  });
  final Pregnancy pregnancy;
  final HealthProfileId? mother;
  final PregnancyBaby baby;
  final List<PregnancyBaby> babies;
  final List<PregnancyItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final its = items.where((i) => i.isAbout(baby.id)).toList();
    final last = its.where((i) => i.kind == ItemKind.measure).firstOrNull;
    final label = babyLabel(s, baby, babies);
    final strong = Typo.num(size: FontSizes.bodySm, weight: FontWeight.w700);
    return Semantics(
      button: true,
      child: PCard(
        onTap: () => openBaby(context, baby.id, mother: mother),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon and menu on top, the name and count below at the card's
            // full width: two cards share a phone row, too narrow for all
            // four side by side.
            Row(
              children: [
                const IconSquare(LucideIcons.sprout, bg: babyWash, fg: babyInk),
                const Spacer(),
                RoundBtn(
                  icon: LucideIcons.ellipsis,
                  semanticLabel: p.options,
                  ghost: true,
                  iconSize: 18,
                  onTap: () => _babyMenu(context, ref, pregnancy, baby, label, mother),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            Text(
              s.strings.family.records_n(its.length),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Typo.meta(ar: s.rtl),
            ),
            if (last != null) ...[
              const SizedBox(height: 10),
              Text('${p.last_measure} · ${formatDay(last.recordedOn)}', style: Typo.meta(ar: s.rtl)),
              if (last.fetalHeartRateBpm != null)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${p.hr} '),
                      TextSpan(text: '${last.fetalHeartRateBpm}', style: strong),
                      TextSpan(text: ' ${p.bpm}'),
                    ],
                  ),
                  style: Typo.bodySm(ar: s.rtl),
                ),
              if (last.estimatedFetalWeightG != null)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${p.efw} '),
                      TextSpan(text: '${last.estimatedFetalWeightG}', style: strong),
                      TextSpan(text: ' ${p.grams}'),
                    ],
                  ),
                  style: Typo.bodySm(ar: s.rtl),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rename · Stop following this baby.
Future<void> _babyMenu(
  BuildContext context,
  WidgetRef ref,
  Pregnancy preg,
  PregnancyBaby baby,
  String label,
  HealthProfileId? mother,
) {
  final s = AppScope.of(context);
  final p = s.strings.pregnancy;
  return showAppSheet<void>(
    context,
    textDirection: s.dir,
    builder: (ctx) => FamilySheet(
      title: label,
      children: [
        for (final (icon, text, action) in [
          (LucideIcons.pencil, p.rename, () => openBaby(context, baby.id, rename: true, mother: mother)),
          (LucideIcons.archive, p.stop_t, () => _stopFollowing(context, ref, preg, baby, mother)),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: AppColors.textSecondary),
            title: Text(text, style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              unawaited(action());
            },
          ),
      ],
    ),
  );
}

Future<void> _stopFollowing(
  BuildContext context,
  WidgetRef ref,
  Pregnancy preg,
  PregnancyBaby baby,
  HealthProfileId? mother,
) async {
  final s = AppScope.of(context);
  final p = s.strings.pregnancy;
  final yes = await _confirmSheet(context, title: p.stop_t, body: p.stop_b, cta: p.stop_cta);
  if (yes != true || !context.mounted) return;
  final r = await ref
      .read(pregnancyBabiesUseCaseProvider)
      .stopFollowing(preg.id, baby.id, motherId: preg.motherId, now: DateTime.now());
  if (!context.mounted) return;
  if (r.isFailure) return _failed(context);
  if (!r.value.isActive) leavePregnancy(context, mother: mother);
}

/// A born baby: now a family member; opens their home.
class _BornRow extends ConsumerWidget {
  const _BornRow({required this.baby});
  final PregnancyBaby baby;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final name = baby.givenName ?? '';
    final dob = baby.dateOfBirth;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () async {
          await ref.read(activeProfileSwitcherProvider).select(baby.id);
          if (context.mounted) await openMember(context, baby.id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Avatar(
                initials: name.isEmpty ? '' : name.characters.first.toUpperCase(),
                color: toneColors(MemberTone.tryFromWire(baby.tone)).c,
                size: 34,
                fontSize: FontSizes.description,
                ar: s.rtl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    if (dob != null) Text(s.strings.pregnancy.born_on(formatDay(dob)), style: Typo.meta(ar: s.rtl)),
                  ],
                ),
              ),
              Icon(forwardChevron(context), size: 18, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
