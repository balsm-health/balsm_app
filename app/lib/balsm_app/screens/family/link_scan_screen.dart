import 'package:family_link/family_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../tokens.dart';
import '../../widgets/family_qr_scan.dart';
import 'add_member_screen.dart';
import 'family_kit.dart';
import 'family_link_kit.dart';

/// Opens the scan-to-link flow (mother-child.jsx `MCAddMemberScreen`, mode
/// `scan`).
Future<void> openLinkScan(BuildContext context) => pushFamilyScreen<void>(context, (_) => const LinkScanScreen());

/// Scan their profile QR → confirm who it is and the relation → send the link
/// request. The scanned name and date of birth were decrypted on this phone
/// from the code itself; they stay here and are never sent.
class LinkScanScreen extends ConsumerStatefulWidget {
  const LinkScanScreen({super.key});
  @override
  ConsumerState<LinkScanScreen> createState() => _LinkScanScreenState();
}

class _LinkScanScreenState extends ConsumerState<LinkScanScreen> {
  ScannedProfile? _found;
  LinkRelation? _relation;
  bool _sending = false;

  PatientAppState get s => AppScope.of(context);

  Future<void> _send() async {
    final found = _found;
    final relation = _relation;
    if (found == null || relation == null || _sending) return;
    setState(() => _sending = true);
    final result = await ref.read(familyLinksProvider.notifier).request(
          jti: found.jti,
          relation: relation,
          scanned: ScannedIdentity(name: found.payload.name, dateOfBirth: found.payload.dateOfBirth),
        );
    if (!mounted) return;
    setState(() => _sending = false);
    final messenger = ScaffoldMessenger.of(context);
    if (result.isSuccess) {
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(s.strings.family.link_sent(s.gender))));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(linkFailureText(s, result.error, sending: true))));
    }
  }

  void _manual() {
    Navigator.pop(context);
    openAddMember(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = s.strings.common;
    final found = _found;
    if (found == null) {
      return FamilyScaffold(
        title: c.fam_scan_title,
        children: [
          FamilyQrScanView(
            onFound: (p) => setState(() => _found = p),
            onManual: _manual,
          ),
        ],
      );
    }
    final name = (found.payload.name ?? '').trim();
    return FamilyScaffold(
      title: c.fam_confirm_title,
      onBack: () => setState(() => _found = null),
      footer: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PButton(
          c.fam_send_request,
          large: true,
          block: true,
          accent: s.accent,
          ar: s.rtl,
          onTap: _relation != null && !_sending ? _send : null,
        ),
        const SizedBox(height: 8),
        PButton(
          c.fam_scan_other,
          variant: BtnVariant.ghost,
          block: true,
          ar: s.rtl,
          onTap: () => setState(() {
            _found = null;
            _relation = null;
          }),
        ),
      ]),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: T.hueMint50,
            borderRadius: BorderRadius.circular(T.rLg),
            border: Border.all(color: T.border),
          ),
          child: Row(children: [
            Avatar(
              initials: name.isEmpty ? '' : name.characters.first.toUpperCase(),
              color: T.hueMint600,
              size: 48,
              fontSize: 16,
              ar: s.rtl,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(name.isEmpty ? s.strings.family.link_someone : name,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
            ),
            const Icon(LucideIcons.badgeCheck, size: 22, color: T.hueMint600),
          ]),
        ),
        const SizedBox(height: 18),
        Text(s.strings.family.f_relation,
            style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in LinkRelation.values)
            BChip(
              linkRelationPick(s, r),
              active: _relation == r,
              accent: s.accent.main,
              ar: s.rtl,
              onTap: () => setState(() => _relation = r),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 16, 2, 0),
          child: Text(c.fam_approval_note, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2)),
        ),
      ],
    );
  }
}
