import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pregnancy/pregnancy.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../family/family_kit.dart';
import '../family/member_card_screen.dart';
import '../profile_subscreens.dart';
import 'pregnancy_kit.dart';

/// Opens the emergency card in pregnancy mode — the account holder's, or
/// family member [mother]'s.
Future<void> openPregnancyCard(BuildContext context, {HealthProfileId? mother}) =>
    pushFamilyScreen<void>(context, (_) => PregnancyCardScreen(mother: mother));

/// The account holder's own emergency card in pregnancy mode (design
/// `MCCardScreen` for self): the shared [MemberEmergencyCard] with the
/// pregnancy status, due date and Rh factor as its banner and the
/// obstetrician as an extra contact row. Shown on the phone; the scannable
/// card stays the one in Profile. For a family member's pregnancy it is her
/// card, read from her own profile.
class PregnancyCardScreen extends ConsumerWidget {
  const PregnancyCardScreen({super.key, this.mother});

  /// Whose pregnancy (null = the account holder's own).
  final HealthProfileId? mother;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final preg = ref.watch(activePregnancyOfProvider(mother));
    final owner = pregnancyOwner(ref, mother);
    final self = ref.watch(selfProfileIdProvider).value;
    final health =
        owner == null ? ref.watch(healthProfileProvider).value : ref.watch(memberHealthProfileProvider(owner.id)).value;
    final name = (ref.watch(accountSummaryProvider).value?.displayName ?? '').trim();
    if (preg == null || self == null) return const Scaffold(backgroundColor: AppColors.white);
    final blood = health?.bloodType;
    final me = owner ?? FamilyMember(id: self, kind: ProfileKind.self, displayName: name, bloodType: blood);
    final ob = preg.obName;
    return FamilyScaffold(
      title: s.strings.family.tile_card,
      children: [
        MemberEmergencyCard(
          member: me,
          health: health,
          banner: PregnancyCardBanner(pregnancy: preg, bloodType: blood),
          extraRows: [
            if (ob != null) PregnancyObRow(name: ob, phone: preg.obPhone),
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

/// The card's pregnancy banner (design `MCEmergencyCard` `preg`): the
/// pregnancy type and week, the due date, and the Rh factor when the blood
/// type is known.
class PregnancyCardBanner extends ConsumerWidget {
  const PregnancyCardBanner({required this.pregnancy, required this.bloodType, super.key});
  final Pregnancy pregnancy;
  final BloodType? bloodType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final babies = ref.watch(pregnancyBabiesProvider(pregnancy.id)).value ?? const <PregnancyBaby>[];
    final info = pregnancy.infoOn(DateTime.now());
    final status = [pregnancyTypeLabel(s, babies.length) ?? p.pregnant, p.week_lower(info.week)].join(' · ');
    final blood = bloodType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: babyWash, borderRadius: BorderRadius.circular(AppRadii.control)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(p.card_due(formatDay(pregnancy.dueDate)), style: Typo.bodySm(ar: s.rtl)),
          if (blood != null && blood != BloodType.bombay)
            Text(
              blood.code.contains('-') ? p.rh_neg : p.rh_pos,
              style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

/// The obstetrician, with a call button when there is a phone number.
class PregnancyObRow extends StatelessWidget {
  const PregnancyObRow({required this.name, required this.phone, super.key});
  final String name;
  final String? phone;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tel = phone;
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.ink100))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.strings.pregnancy.ob, style: Typo.meta(ar: s.rtl)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    if (tel != null)
                      Text(
                        tel,
                        textDirection: TextDirection.ltr,
                        style: Typo.num(size: FontSizes.bodySm, weight: FontWeight.w500)
                            .copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
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
            ],
          ),
        ],
      ),
    );
  }
}
