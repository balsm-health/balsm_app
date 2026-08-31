import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import '../widgets/balsm_flower.dart';
import 'feedback_sheet.dart';

/// "Balsm is bigger than this app" — the ecosystem story plus concrete ways a
/// patient can help it spread.
///
/// One of the few brand moments where all five petals appear together.
Future<void> showEcosystemSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EcosystemSheet(),
    );

class _EcosystemSheet extends StatelessWidget {
  const _EcosystemSheet();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final e = s.strings.ecosystem;

    final parts = <({IconData icon, Color fg, Color bg, String head, String body})>[
      (icon: LucideIcons.smartphone, fg: T.petalBlue, bg: T.petalBlue50, head: e.eco_p1h, body: e.eco_p1b),
      (icon: LucideIcons.pill, fg: T.petalAqua, bg: T.petalAqua50, head: e.eco_p2h, body: e.eco_p2b),
      (icon: LucideIcons.stethoscope, fg: T.petalEmerald, bg: T.petalEmerald50, head: e.eco_p3h, body: e.eco_p3b),
    ];

    final actions = <({IconData icon, String head, String body, VoidCallback? onTap})>[
      (icon: LucideIcons.share2, head: e.eco_a1h, body: e.eco_a1b, onTap: null),
      (
        icon: LucideIcons.messageSquare,
        head: e.eco_a2h,
        body: e.eco_a2b,
        onTap: () {
          Navigator.of(context).pop();
          showFeedbackSheet(context);
        }
      ),
      (icon: LucideIcons.building2, head: e.eco_a3h, body: e.eco_a3b, onTap: null),
      (icon: LucideIcons.code2, head: e.eco_a4h, body: e.eco_a4b, onTap: null),
    ];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
          child: Row(children: [
            Expanded(child: Text(e.eco_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700))),
            RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 18, onTap: () => Navigator.of(context).pop()),
          ]),
        ),
        const Divider(height: 1, color: T.ink100),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Brand moment — all five petals.
              Column(children: [
                const BalsmFlower(size: 54),
                const SizedBox(height: 12),
                Text(e.eco_hero, textAlign: TextAlign.center, style: Typo.heading(ar: s.rtl).copyWith(height: 1.3)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(e.eco_sub, textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
                ),
              ]),
              const SizedBox(height: 18),
              for (final p in parts) ...[
                _PartRow(icon: p.icon, fg: p.fg, bg: p.bg, head: p.head, body: p.body),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 14),
              Text(e.eco_help_t, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, fontSize: FS.md)),
              const SizedBox(height: 4),
              Text(e.eco_help_sub, style: Typo.meta(ar: s.rtl)),
              const SizedBox(height: 12),
              PCard(
                child: Column(children: [
                  for (final (i, a) in actions.indexed)
                    _ActionRow(
                      icon: a.icon,
                      head: a.head,
                      body: a.body,
                      onTap: a.onTap,
                      first: i == 0,
                    ),
                ]),
              ),
              const SizedBox(height: 20),
              Text(
                e.eco_tagline,
                textAlign: TextAlign.center,
                style: Typo.eyebrow(T.fg3, ar: s.rtl),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.icon,
    required this.fg,
    required this.bg,
    required this.head,
    required this.body,
  });
  final IconData icon;
  final Color fg;
  final Color bg;
  final String head;
  final String body;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rMd)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconSquare(icon, bg: bg, fg: fg),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(head, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
            const SizedBox(height: 2),
            Text(body, style: Typo.meta(ar: s.rtl).copyWith(height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.head,
    required this.body,
    required this.onTap,
    required this.first,
  });
  final IconData icon;
  final String head;
  final String body;
  final VoidCallback? onTap;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final row = Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: T.ink100))),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconSquare(icon, bg: s.accent.bg, fg: s.accent.d),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(head, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            const SizedBox(height: 2),
            Text(body, style: Typo.meta(ar: s.rtl).copyWith(height: 1.5)),
          ]),
        ),
        // Only the row that actually goes somewhere gets an affordance.
        if (onTap != null) ...[const SizedBox(width: 8), Chevron(rtl: s.rtl)],
      ]),
    );
    return onTap == null ? row : PressHighlight(onTap: onTap, child: row);
  }
}
