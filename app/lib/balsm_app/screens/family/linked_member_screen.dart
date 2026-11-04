import 'package:core/core.dart';
import 'package:family/family.dart' show MemberAge;
import 'package:family_link/family_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../tokens.dart';
import 'family_kit.dart';
import 'family_link_kit.dart';
import 'member_card_screen.dart';

/// Opens the account linked over [linkId].
Future<void> openLinkedMember(BuildContext context, String linkId) =>
    pushFamilyScreen<void>(context, (_) => LinkedMemberScreen(linkId: linkId));

/// Someone with their own Balsm account, linked to this one (design
/// `m.readOnly`): their name and relation, the emergency card they chose to
/// share — read-only, opened on this phone — or "Not shared", this account's
/// own switch for sharing its card back, and Unlink. No other health tiles:
/// their records live on their phone.
class LinkedMemberScreen extends ConsumerWidget {
  const LinkedMemberScreen({super.key, required this.linkId});
  final String linkId;

  Future<void> _refresh(WidgetRef ref) async {
    await ref.read(familyLinksProvider.notifier).refresh();
    ref.invalidate(sharedCardProvider(linkId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final link = ref.watch(familyLinksProvider).valueOrNull?.byId(linkId);
    if (link == null || !link.isLinked) return const Scaffold(backgroundColor: Colors.white);
    final name = linkName(s, link);
    final sub = linkSubtitle(s, link);
    return FamilyScaffold(
      title: name,
      onRefresh: () => _refresh(ref),
      footer: PButton(
        f.link_unlink,
        icon: LucideIcons.unlink,
        variant: BtnVariant.secondary,
        large: true,
        block: true,
        ar: s.rtl,
        onTap: () => _unlink(context, ref, link),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Column(children: [
            LinkAvatar(link, size: 84),
            const SizedBox(height: 14),
            Text(name,
                textAlign: TextAlign.center, style: Typo.heading(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(sub, textAlign: TextAlign.center, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ],
            const SizedBox(height: 10),
            Pill(f.link_read_only, kind: PillKind.outline, icon: LucideIcons.lock, ar: s.rtl),
          ]),
        ),
        FamilySecHead(f.link_card_section),
        _SharedCard(link: link),
        const SizedBox(height: 8),
        _ShareSwitch(link: link),
      ],
    );
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref, FamilyLink link) async {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: s.dir,
        child: AlertDialog(
          title: Text(f.link_unlink_t(linkName(s, link))),
          content: Text(f.link_unlink_b),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.strings.common.cancel)),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(f.link_unlink, style: const TextStyle(color: T.danger)),
            ),
          ],
        ),
      ),
    );
    if (yes != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final result = await ref.read(familyLinksProvider.notifier).unlink(link.id);
    if (result.isSuccess) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(f.link_unlinked_toast)));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(linkFailureText(s, result.error))));
    }
  }
}

/// Their card for this account: the opened card with its "updated" day, "Not
/// shared", or — sealed for an older key of this account — a hint to ask them
/// to open Balsm, whose next pull re-seals it.
class _SharedCard extends ConsumerWidget {
  const _SharedCard({required this.link});
  final FamilyLink link;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final result = ref.watch(sharedCardProvider(link.id)).valueOrNull;
    if (result == null) return const SizedBox(height: 120);
    if (result.isFailure) {
      final stale = result.error is ValidationFailure;
      return _Note(
        icon: stale ? LucideIcons.refreshCw : LucideIcons.cloudOff,
        title: stale ? f.link_card_stale(s.gender) : linkFailureText(s, result.error),
      );
    }
    final shared = result.value;
    if (shared == null) {
      return _Note(icon: LucideIcons.eyeOff, title: f.link_card_not_shared, body: f.link_card_not_shared_b);
    }
    final card = shared.card;
    final dob = card.dateOfBirthDay;
    final age = dob == null ? null : MemberAge.between(dob, DateTime.now());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      EmergencyCardBody(
        name: (card.name ?? '').trim().isEmpty ? linkName(s, link) : card.name!.trim(),
        meta: [if (age != null) ageLabel(s, age), if (dob != null) f.born(formatDay(dob))].join(' · '),
        bloodType: card.bloodType,
        allergies: card.allergies,
        conditions: card.conditions,
        contacts: [for (final c in card.contacts) (name: c.name, phone: c.phone, relation: c.relation)],
      ),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 4, 0),
        child: Text(f.link_card_updated(formatDay(shared.updatedAt.toLocal())), style: Typo.meta(ar: s.rtl)),
      ),
    ]);
  }
}

/// This account's switch for sharing its own emergency card over the link.
class _ShareSwitch extends ConsumerStatefulWidget {
  const _ShareSwitch({required this.link});
  final FamilyLink link;
  @override
  ConsumerState<_ShareSwitch> createState() => _ShareSwitchState();
}

class _ShareSwitchState extends ConsumerState<_ShareSwitch> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final s = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final result =
        await ref.read(familyLinksProvider.notifier).setCardSharing(widget.link, on: !widget.link.cardSharing);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isFailure) messenger.showSnackBar(SnackBar(content: Text(s.strings.family.link_share_failed(s.gender))));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    return PCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child:
                Text(f.link_share_t, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
          ),
          Semantics(
            toggled: widget.link.cardSharing,
            label: f.link_share_t,
            child: PSwitch(on: widget.link.cardSharing, accent: s.accent.main, onTap: _toggle),
          ),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(LucideIcons.lock, size: 14, color: T.fg3)),
          const SizedBox(width: 8),
          Expanded(child: Text(f.link_share_b(s.gender), style: Typo.meta(ar: s.rtl).copyWith(height: 1.5))),
        ]),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.title, this.body});
  final IconData icon;
  final String title;
  final String? body;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PCard(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconSquare(icon, bg: T.ink50, fg: T.fg3, size: 38, iconSize: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            if (body != null) Text(body!, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ]),
        ),
      ]),
    );
  }
}
