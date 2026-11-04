import 'package:core/core.dart';
import 'package:family_link/family_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../tokens.dart';
import 'family_kit.dart';
import 'family_link_kit.dart';
import 'linked_member_screen.dart';

/// The Family screen's family-link sections: requests waiting for this
/// account's answer, then the accounts it is linked with or waiting on
/// (`m.linkStatus === 'pending'` → "Waiting for approval", `m.readOnly` →
/// "Read-only"). Nothing when there are none.
class FamilyLinkSections extends ConsumerWidget {
  const FamilyLinkSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final links = ref.watch(familyLinksProvider).valueOrNull ?? FamilyLinks.empty;
    final requests = links.awaitingMe;
    final people = [...links.waiting, ...links.linked];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (requests.isNotEmpty) ...[
        GroupHead(label: f.link_requests, count: requests.length),
        _card([for (final (i, l) in requests.indexed) _RequestRow(link: l, divider: i > 0)]),
      ],
      if (people.isNotEmpty) ...[
        GroupHead(label: f.link_section, count: people.length),
        _card([for (final (i, l) in people.indexed) _LinkRow(link: l, divider: i > 0)]),
      ],
    ]);
  }

  Widget _card(List<Widget> rows) => PCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(borderRadius: BorderRadius.circular(T.rLg), child: Column(children: rows)),
      );
}

Future<void> _act(
  BuildContext context,
  Future<AppResult<void>> Function() action, {
  String? done,
}) async {
  final s = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final result = await action();
  if (result.isSuccess) {
    if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
  } else {
    messenger.showSnackBar(SnackBar(content: Text(linkFailureText(s, result.error))));
  }
}

/// An incoming request: who asks, as what, and Approve / Decline.
class _RequestRow extends ConsumerStatefulWidget {
  const _RequestRow({required this.link, required this.divider});
  final FamilyLink link;
  final bool divider;
  @override
  ConsumerState<_RequestRow> createState() => _RequestRowState();
}

class _RequestRowState extends ConsumerState<_RequestRow> {
  bool _busy = false;

  Future<void> _run(Future<AppResult<void>> Function() action, {String? done}) async {
    setState(() => _busy = true);
    await _act(context, action, done: done);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final l = widget.link;
    final notifier = ref.read(familyLinksProvider.notifier);
    final handle = l.otherHandle;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: widget.divider ? const BoxDecoration(border: Border(top: BorderSide(color: T.ink100))) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          LinkAvatar(l, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(linkName(s, l), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              if (handle != null && handle.isNotEmpty)
                Text('@$handle',
                    textDirection: TextDirection.ltr, style: Typo.meta(ar: s.rtl).copyWith(color: s.accent.main)),
              Text(f.link_asks(linkRelationPick(s, l.relation)), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: PButton(
              s.strings.common.fam_decline,
              variant: BtnVariant.secondary,
              ar: s.rtl,
              onTap: _busy ? null : () => _run(() => notifier.decline(l.id)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PButton(
              s.strings.common.fam_approve,
              accent: s.accent,
              ar: s.rtl,
              onTap: _busy
                  ? null
                  : () => _run(() => notifier.approve(l.id), done: f.link_linked_toast(linkName(s, l), s.gender)),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// A request this account sent (waiting, with Cancel) or a link (read-only,
/// opens the linked member).
class _LinkRow extends ConsumerWidget {
  const _LinkRow({required this.link, required this.divider});
  final FamilyLink link;
  final bool divider;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final l = link;
    final sub = linkSubtitle(s, l);
    return PressHighlight(
      onTap: l.isLinked ? () => openLinkedMember(context, l.id) : null,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 10, 12),
        decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: T.ink100))) : null,
        child: Row(children: [
          LinkAvatar(l),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(linkName(s, l), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              if (sub.isNotEmpty) Text(sub, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
              const SizedBox(height: 4),
              Pill(
                l.isPending ? f.link_waiting : f.link_read_only,
                kind: PillKind.outline,
                icon: l.isPending ? LucideIcons.clock : LucideIcons.lock,
                small: true,
                ar: s.rtl,
              ),
            ]),
          ),
          if (l.canCancel)
            PButton(
              s.strings.common.fam_cancel_request,
              variant: BtnVariant.ghost,
              ar: s.rtl,
              onTap: () => _act(context, () => ref.read(familyLinksProvider.notifier).cancel(l.id)),
            )
          else
            Chevron(rtl: s.rtl),
        ]),
      ),
    );
  }
}
