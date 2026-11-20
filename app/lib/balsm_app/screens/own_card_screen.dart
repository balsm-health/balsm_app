import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pregnancy/pregnancy.dart';

import '../app_state.dart';
import '../kit.dart';
import 'family/family_kit.dart';
import 'family/member_card_screen.dart';
import 'pregnancy/pregnancy_card_screen.dart';
import 'profile_subscreens.dart';

/// Opens the account holder's own emergency card, read from the phone.
Future<void> openOwnCard(BuildContext context) => pushFamilyScreen<void>(context, (_) => const OwnCardScreen());

/// The account holder's own emergency card (mother-child.jsx `MCCardScreen`
/// for `self`), drawn from the encrypted on-device profile so it works with
/// no connection — during a maintenance block, or offline. While she is
/// pregnant it carries the same banner and obstetrician row as
/// [PregnancyCardScreen].
///
/// No scannable code here: that card is minted by the server (Profile → QR).
class OwnCardScreen extends ConsumerWidget {
  const OwnCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final self = ref.watch(selfProfileIdProvider).valueOrNull;
    final health = ref.watch(healthProfileProvider).valueOrNull;
    final preg = ref.watch(activePregnancyOfProvider(null));
    final name = (ref.watch(accountSummaryProvider).valueOrNull?.displayName ?? health?.displayName ?? '').trim();
    if (self == null) return const Scaffold(backgroundColor: Colors.white);
    final me = FamilyMember(
      id: self,
      kind: ProfileKind.self,
      displayName: name,
      dateOfBirth: health?.dateOfBirth,
      sex: health?.sex,
      bloodType: health?.bloodType,
    );
    final ob = preg?.obName;
    return FamilyScaffold(
      title: s.strings.family.tile_card,
      children: [
        MemberEmergencyCard(
          member: me,
          health: health,
          banner: preg == null ? null : PregnancyCardBanner(pregnancy: preg, bloodType: health?.bloodType),
          extraRows: [
            if (preg != null && ob != null) PregnancyObRow(name: ob, phone: preg.obPhone),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 14),
          child: Text(s.strings.family.own_card_note, style: Typo.meta(ar: s.rtl).copyWith(height: 1.5)),
        ),
      ],
    );
  }
}
