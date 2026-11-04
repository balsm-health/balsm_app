import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:profile/profile.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../assets.dart';
import '../../kit.dart';
import '../../tokens.dart';
import '../profile_subscreens.dart';
import 'family_kit.dart';
import 'member_screen.dart';
import 'profile_bar.dart';

/// Opens member [id]'s emergency card (mother-child.jsx `MCCardScreen`).
Future<void> openMemberCard(BuildContext context, HealthProfileId id) =>
    pushFamilyScreen<void>(context, (_) => MemberCardScreen(id: id));

/// A member's emergency card, read from their own health profile, with their
/// medical details and contacts editable from here.
///
/// No scannable code: the emergency QR is minted for the signed-in account,
/// and a member has no account of their own, so this card is shown from the
/// phone. Neither save-as-image nor share is offered for the same reason.
class MemberCardScreen extends ConsumerWidget {
  const MemberCardScreen({super.key, required this.id});
  final HealthProfileId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final m =
        (ref.watch(familyMembersProvider).valueOrNull ?? const <FamilyMember>[]).where((x) => x.id == id).firstOrNull;
    final health = ref.watch(memberHealthProfileProvider(id)).valueOrNull;
    if (m == null) return const Scaffold(backgroundColor: Colors.white);
    final atMax = (health?.emergencyContacts.length ?? 0) >= AddEmergencyContactUseCase.maxContacts;
    return FamilyScaffold(
      title: f.tile_card,
      bar: const ProfileBar(),
      children: [
        MemberEmergencyCard(member: m, health: health),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 14),
          child: Text(f.card_note(s.gender), style: Typo.meta(ar: s.rtl).copyWith(height: 1.5)),
        ),
        Row(children: [
          Expanded(
            child: PButton(
              f.edit_medical,
              icon: LucideIcons.clipboardList,
              variant: BtnVariant.secondary,
              large: true,
              ar: s.rtl,
              onTap: () async {
                await openMemberMedical(context, m);
                ref.invalidate(memberHealthProfileProvider(id));
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PButton(
              f.add_contact,
              icon: LucideIcons.userPlus,
              large: true,
              accent: s.accent,
              ar: s.rtl,
              onTap: atMax ? null : () => _addContact(context, ref, m),
            ),
          ),
        ]),
      ],
    );
  }

  Future<void> _addContact(BuildContext context, WidgetRef ref, FamilyMember m) async {
    final s = AppScope.of(context);
    final first = ref.read(memberHealthProfileProvider(m.id)).valueOrNull?.emergencyContacts.isEmpty ?? true;
    final added = await showAppSheet<bool>(
      context,
      textDirection: s.dir,
      builder: (_) => _ContactSheet(member: m, primary: first),
    );
    if (added == true) ref.invalidate(memberHealthProfileProvider(m.id));
  }
}

/// The card itself (`MCEmergencyCard`): name and age, blood type, allergies,
/// chronic conditions and emergency contacts.
///
/// **Stage 4 hook:** the pregnancy-mode card passes its status ("Pregnant ·
/// week N", due date) as [banner] and the obstetrician contact as
/// [extraRows]; both render where the design puts them.
class MemberEmergencyCard extends StatelessWidget {
  const MemberEmergencyCard({
    super.key,
    required this.member,
    required this.health,
    this.banner,
    this.extraRows = const [],
  });
  final FamilyMember member;
  final HealthProfile? health;
  final Widget? banner;
  final List<Widget> extraRows;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final m = member;
    final age = m.ageOn(DateTime.now());
    return EmergencyCardBody(
      name: m.displayName,
      meta: [
        if (m.sex != null) m.sex == Sex.female ? f.sex_female : f.sex_male,
        if (age != null) ageLabel(s, age),
        if (m.dateOfBirth != null) f.born(formatDay(m.dateOfBirth!)),
      ].join(' · '),
      bloodType: (health?.bloodType ?? m.bloodType)?.code,
      allergies: [for (final a in health?.allergies ?? const <Allergy>[]) a.name],
      conditions: [for (final c in health?.conditions ?? const <ChronicCondition>[]) c.name],
      contacts: [
        for (final c in health?.emergencyContacts ?? const <EmergencyContact>[])
          (name: c.name, phone: c.phone, relation: c.relation),
      ],
      banner: banner,
      extraRows: extraRows,
    );
  }
}

/// One emergency contact as the card shows it.
typedef CardContactRow = ({String name, String phone, String? relation});

/// The emergency card's layout over plain values, so a member's own profile
/// and a card shared over a family link render the same.
class EmergencyCardBody extends StatelessWidget {
  const EmergencyCardBody({
    super.key,
    required this.name,
    required this.meta,
    required this.bloodType,
    required this.allergies,
    required this.conditions,
    required this.contacts,
    this.banner,
    this.extraRows = const [],
  });
  final String name;
  final String meta;
  final String? bloodType;
  final List<String> allergies;
  final List<String> conditions;
  final List<CardContactRow> contacts;
  final Widget? banner;
  final List<Widget> extraRows;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final blood = bloodType?.replaceAll('-', '−');
    final sep = s.rtl ? '، ' : ', ';
    const line = BorderSide(color: T.ink100);
    return PCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SvgPicture.asset(Assets.brand_icon, width: 16, height: 16),
              const SizedBox(width: 6),
              Text(f.card_brand, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Text(name, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
            if (meta.isNotEmpty) Text(meta, style: Typo.meta(ar: s.rtl)),
            const SizedBox(height: 12),
            Text(f.f_blood, style: Typo.meta(ar: s.rtl)),
            Text(blood ?? '—',
                textDirection: TextDirection.ltr,
                style: Typo.num(size: 32, weight: FontWeight.w800).copyWith(height: 1.05, color: T.fg1)),
          ]),
        ),
        if (banner != null) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: banner),
        ...extraRows,
        Container(
          decoration: const BoxDecoration(border: Border(top: line)),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _cell(s, f.card_allergies, allergies.isEmpty ? f.card_none : allergies.join(sep))),
              const VerticalDivider(width: 1, thickness: 1, color: T.ink100),
              Expanded(child: _cell(s, f.card_conditions, conditions.isEmpty ? f.card_none : conditions.join(sep))),
            ]),
          ),
        ),
        Container(
          decoration: const BoxDecoration(border: Border(top: line)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.card_contacts, style: Typo.meta(ar: s.rtl)),
            if (contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(f.card_no_contacts, style: Typo.body(ar: s.rtl).copyWith(color: T.fg3)),
              ),
            for (final c in contacts) _ContactRow(contact: c),
          ]),
        ),
      ]),
    );
  }

  Widget _cell(PatientAppState s, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Typo.meta(ar: s.rtl)),
          Text(value, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
        ]),
      );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact});
  final CardContactRow contact;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = contact;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: c.name),
                if (c.relation != null)
                  TextSpan(text: ' · ${c.relation}', style: const TextStyle(fontWeight: FontWeight.w400, color: T.fg3)),
              ]),
              style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1),
            ),
            Text(c.phone,
                textDirection: TextDirection.ltr,
                style: Typo.num(size: FS.sm, weight: FontWeight.w500).copyWith(color: T.fg2)),
          ]),
        ),
        RoundBtn(
          icon: LucideIcons.phone,
          semanticLabel: s.strings.family.a11y_call(c.name),
          bg: s.accent.bg,
          fg: s.accent.d,
          outlined: false,
          iconSize: 18,
          onTap: () => launchUrl(Uri(scheme: 'tel', path: c.phone.replaceAll(' ', ''))),
        ),
      ]),
    );
  }
}

/// Adds an emergency contact to the member's own profile.
class _ContactSheet extends ConsumerStatefulWidget {
  const _ContactSheet({required this.member, required this.primary});
  final FamilyMember member;

  /// The member's first contact becomes their primary one.
  final bool primary;
  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _saving) return;
    setState(() => _saving = true);
    final result = await ref.read(addEmergencyContactUseCaseProvider).execute(
          userId: userId,
          profileId: widget.member.id,
          name: _name.text,
          phone: _phone.text,
          isPrimary: widget.primary,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      Navigator.pop(context, true);
    } else {
      final s = AppScope.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.strings.family.save_failed(s.gender))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final ok = _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FamilySheet(title: f.add_contact, children: [
        TextField(
          controller: _name,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: f.contact_name),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: f.contact_phone),
        ),
        const SizedBox(height: 18),
        PButton(f.contact_add,
            large: true, block: true, accent: s.accent, ar: s.rtl, onTap: ok && !_saving ? _add : null),
      ]),
    );
  }
}
