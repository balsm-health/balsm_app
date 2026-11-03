import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pregnancy/pregnancy.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../tokens.dart';
import '../family/family_kit.dart';
import '../family/member_card_screen.dart';
import '../profile_subscreens.dart';
import 'pregnancy_kit.dart';

/// Opens the account holder's emergency card in pregnancy mode.
Future<void> openPregnancyCard(BuildContext context) =>
    pushFamilyScreen<void>(context, (_) => const PregnancyCardScreen());

/// The account holder's own emergency card in pregnancy mode (design
/// `MCCardScreen` for self): the shared [MemberEmergencyCard] with the
/// pregnancy status, due date and Rh factor as its banner and the
/// obstetrician as an extra contact row. Shown on the phone; the scannable
/// card stays the one in Profile.
class PregnancyCardScreen extends ConsumerWidget {
  const PregnancyCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final preg = ref.watch(activePregnancyProvider);
    final self = ref.watch(selfProfileIdProvider).valueOrNull;
    final health = ref.watch(healthProfileProvider).valueOrNull;
    final name = (ref.watch(accountSummaryProvider).valueOrNull?.displayName ?? '').trim();
    if (preg == null || self == null) return const Scaffold(backgroundColor: Colors.white);
    final babies = ref.watch(pregnancyBabiesProvider(preg.id)).valueOrNull ?? const <PregnancyBaby>[];
    final info = preg.infoOn(DateTime.now());
    final blood = health?.bloodType;
    final status = [pregnancyTypeLabel(s, babies.length) ?? p.pregnant, p.week_lower(info.week)].join(' · ');
    final me = FamilyMember(id: self, kind: ProfileKind.self, displayName: name, bloodType: blood);
    final ob = preg.obName;
    return FamilyScaffold(
      title: s.strings.family.tile_card,
      children: [
        MemberEmergencyCard(
          member: me,
          health: health,
          banner: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: babyWash, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(status, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              Text(p.card_due(formatDay(preg.dueDate)), style: Typo.bodySm(ar: s.rtl)),
              if (blood != null && blood != BloodType.bombay)
                Text(blood.code.contains('-') ? p.rh_neg : p.rh_pos,
                    style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
          extraRows: [
            if (ob != null) _ObRow(name: ob, phone: preg.obPhone),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 14),
          child: Text(p.card_note, style: Typo.meta(ar: s.rtl).copyWith(height: 1.5)),
        ),
      ],
    );
  }
}

/// The obstetrician, with a call button when there is a phone number.
class _ObRow extends StatelessWidget {
  const _ObRow({required this.name, required this.phone});
  final String name;
  final String? phone;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tel = phone;
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: T.ink100))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.strings.pregnancy.ob, style: Typo.meta(ar: s.rtl)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              if (tel != null)
                Text(tel,
                    textDirection: TextDirection.ltr,
                    style: Typo.num(size: FS.sm, weight: FontWeight.w500).copyWith(color: T.fg2)),
            ]),
          ),
          if (tel != null)
            RoundBtn(
              icon: LucideIcons.phone,
              semanticLabel: s.strings.family.a11y_call(name),
              bg: s.accent.bg,
              fg: s.accent.d,
              outlined: false,
              iconSize: 18,
              onTap: () => launchUrl(Uri(scheme: 'tel', path: tel.replaceAll(' ', ''))),
            ),
        ]),
      ]),
    );
  }
}
