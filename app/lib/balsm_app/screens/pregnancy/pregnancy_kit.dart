import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pregnancy/pregnancy.dart';

import '../../app_state.dart';
import '../../i18n/strings.i69n.dart';
import '../../kit.dart';
import '../../tokens.dart';
import '../../widgets/vault_file_viewer.dart';
import '../family/family_kit.dart';

/// Shared pieces of the pregnancy screens (mother-child.jsx `MC_KINDS`,
/// `mcBabyLabel`, `mcPregType`, `MCItemRow`).

/// `mcBabyLabel` — the name the mother gave, "Baby" for an only baby, or
/// "Baby A"… ("الطفل الأول"…) by position among every baby of the pregnancy.
String babyLabel(PatientAppState s, PregnancyBaby baby, List<PregnancyBaby> all) {
  final p = s.strings.pregnancy;
  return switch (BabyLabel.of(baby, all)) {
    NamedBaby(:final name) => name,
    OnlyBaby() => p.baby,
    LetteredBaby(:final index) => p.baby_lettered(_letter(p, index)),
  };
}

String _letter(PregnancyStrings p, int index) {
  final letters = p.baby_letters.split('|');
  return index < letters.length ? letters[index] : '${index + 1}';
}

/// "First trimester"… for trimester [n] (1–3).
String trimesterLabel(PatientAppState s, int n) {
  final p = s.strings.pregnancy;
  return switch (n) { 1 => p.tri_1, 2 => p.tri_2, _ => p.tri_3 };
}

/// `mcPregType` — "Twin pregnancy"…, or null for a single baby.
String? pregnancyTypeLabel(PatientAppState s, int babies) {
  final p = s.strings.pregnancy;
  return switch (babies) {
    <= 1 => null,
    2 => p.type_2,
    3 => p.type_3,
    4 => p.type_4,
    _ => p.type_n(babies),
  };
}

/// `MC_KINDS` — label and icon of an item kind.
String itemKindLabel(PatientAppState s, ItemKind kind) {
  final p = s.strings.pregnancy;
  return switch (kind) { ItemKind.scan => p.kind_scan, ItemKind.measure => p.kind_measure, ItemKind.doc => p.kind_doc };
}

IconData itemKindIcon(ItemKind kind) => switch (kind) {
      ItemKind.scan => LucideIcons.scanLine,
      ItemKind.measure => LucideIcons.ruler,
      ItemKind.doc => LucideIcons.fileText,
    };

/// The aqua wash and ink of everything about a baby.
const babyWash = T.hueAqua50;
const babyInk = T.hueAquaInk;

/// Picks a calendar day with the app's date sheet.
Future<DateTime?> pickDay(
  BuildContext context, {
  required String title,
  required DateTime first,
  required DateTime last,
  DateTime? initial,
}) {
  final s = AppScope.of(context);
  return showBalsmDatePicker(
    context,
    initial: initial,
    firstDate: first,
    lastDate: last,
    title: title,
    confirmLabel: s.strings.onboarding.dob_confirm,
    months: s.strings.settings.cal_months.split('|'),
    weekdays: s.strings.settings.cal_weekdays.split('|'),
    rtl: s.rtl,
    accent: s.accent.main,
  );
}

/// A tappable field showing a picked day (or [placeholder]).
class DayField extends StatelessWidget {
  const DayField({super.key, required this.value, required this.placeholder, required this.onTap});
  final DateTime? value;
  final String placeholder;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final v = value;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: InputDecorator(
          decoration: fieldDecoration(s, null),
          child: Row(children: [
            const Icon(LucideIcons.calendar, size: 17, color: T.fg3),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                v == null ? placeholder : formatDay(v),
                textDirection: TextDirection.ltr,
                textAlign: s.rtl ? TextAlign.right : TextAlign.left,
                style: Typo.body(ar: s.rtl).copyWith(color: v == null ? T.fg3 : T.fg1),
              ),
            ),
            const Icon(LucideIcons.chevronDown, size: 15, color: T.fg3),
          ]),
        ),
      ),
    );
  }
}

/// The outlined input look of the family forms.
InputDecoration fieldDecoration(PatientAppState s, String? hint) => InputDecoration(
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

/// A labelled form field.
class LabelledField extends StatelessWidget {
  const LabelledField({super.key, required this.label, required this.child, this.help});
  final String label;
  final Widget child;
  final String? help;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
        const SizedBox(height: 8),
        child,
        if (help != null) ...[
          const SizedBox(height: 6),
          Text(help!, style: Typo.meta(ar: s.rtl)),
        ],
      ]),
    );
  }
}

/// `MCItemRow` — one pregnancy item: kind icon, title, date and week, the
/// values as entered, and badges for a shared report and an attached file.
class PregnancyItemRow extends StatelessWidget {
  const PregnancyItemRow({super.key, required this.item, required this.pregnancy, required this.babies});
  final PregnancyItem item;
  final Pregnancy pregnancy;
  final List<PregnancyBaby> babies;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final it = item;
    final me = it.about == ItemAbout.me;
    final week = PregnancyInfo.weekAt(pregnancy.dueDate, it.recordedOn);
    final strong = Typo.num(size: FS.sm, weight: FontWeight.w700);
    final values = <InlineSpan>[
      if (it.fetalHeartRateBpm != null)
        TextSpan(children: [
          TextSpan(text: '${p.hr} '),
          TextSpan(text: '${it.fetalHeartRateBpm}', style: strong),
          TextSpan(text: ' ${p.bpm}'),
        ]),
      if (it.estimatedFetalWeightG != null)
        TextSpan(children: [
          TextSpan(text: '${p.efw} '),
          TextSpan(text: '${it.estimatedFetalWeightG}', style: strong),
          TextSpan(text: ' ${p.grams}'),
        ]),
      if (it.otherLabel != null && it.otherValue != null)
        TextSpan(children: [
          TextSpan(text: '${it.otherLabel} '),
          TextSpan(text: it.otherValue, style: const TextStyle(fontWeight: FontWeight.w700, color: T.fg1)),
        ]),
    ];
    final shared = it.isShared;
    final ref = it.attachmentRef;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconSquare(itemKindIcon(it.kind),
            bg: me ? s.accent.bg : babyWash, fg: me ? s.accent.d : babyInk, size: 38, iconSize: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it.title ?? itemKindLabel(s, it.kind),
                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            Text('${formatDay(it.recordedOn)} · ${p.week_lower(week)}', style: Typo.meta(ar: s.rtl)),
            if (values.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(spacing: 10, runSpacing: 2, children: [
                  for (final v in values) Text.rich(v, style: Typo.bodySm(ar: s.rtl)),
                ]),
              ),
            if (shared || ref != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  if (shared) _Badge(icon: LucideIcons.link2, label: _sharedLabel(s, it)),
                  if (ref != null)
                    _Badge(
                      icon: LucideIcons.paperclip,
                      label: p.file_attached,
                      outlined: true,
                      onTap: () => VaultFileViewer.open(context, path: ref, title: it.title),
                    ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  String _sharedLabel(PatientAppState s, PregnancyItem it) {
    final p = s.strings.pregnancy;
    if (it.babyIds.length == babies.length) return p.shared_all;
    return [
      for (final id in it.babyIds)
        if (babies.where((b) => b.id == id).firstOrNull case final b?) babyLabel(s, b, babies)
    ].join(p.list_sep);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, this.outlined = false, this.onTap});
  final IconData icon;
  final String label;
  final bool outlined;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: outlined ? Colors.white : T.neutralBg,
        borderRadius: BorderRadius.circular(T.rPill),
        border: outlined ? Border.all(color: T.border) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: T.fg2),
        const SizedBox(width: 5),
        Flexible(child: Text(label, style: Typo.meta(ar: s.rtl).copyWith(color: T.fg2, fontWeight: FontWeight.w600))),
      ]),
    );
    if (onTap == null) return badge;
    return Semantics(button: true, child: Pressable(onTap: onTap, child: badge));
  }
}

/// A white card holding rows separated by hairlines.
class RowsCard extends StatelessWidget {
  const RowsCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => PCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: T.ink100),
            c,
          ],
        ]),
      );
}

/// A tappable list row with a chevron (`list-row` + `rchev`).
class ChevronRow extends StatelessWidget {
  const ChevronRow({super.key, required this.label, required this.onTap, this.icon, this.danger = false});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            if (icon != null) ...[
              IconSquare(icon!, bg: T.ink50, fg: T.fg2, size: 34, iconSize: 18),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(label,
                  style: Typo.body(ar: s.rtl).copyWith(color: danger ? T.danger : T.fg1, fontWeight: FontWeight.w500)),
            ),
            Icon(s.rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight, size: 18, color: T.fg4),
          ]),
        ),
      ),
    );
  }
}
