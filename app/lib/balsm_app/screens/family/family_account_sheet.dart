import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../tokens.dart';
import 'family_kit.dart';
import 'family_screen.dart';

/// The account sheet while Mother & Child is on (mother-child.jsx
/// `MCAccountSwitcherSheet`): accounts only, with a pointer to Family —
/// family profiles are people, not accounts. Replaces the session-only
/// switcher's family rows.
///
/// The design's "Sign in to another account" is not offered: one account is
/// signed in on a device in this release.
Future<void> showFamilyAccountSheet(BuildContext context) {
  final s = AppScope.of(context);
  return showAppSheet<void>(context, textDirection: s.dir, builder: (_) => const _AccountSheet());
}

class _AccountSheet extends ConsumerWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.family;
    final summary = ref.watch(accountSummaryProvider).valueOrNull;
    final name = (summary?.displayName ?? '').trim();
    return FamilySheet(title: s.strings.common.your_accounts, sub: f.acc_sub, children: [
      PCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: summary == null
            ? Row(children: [
                const Icon(LucideIcons.userCircle2, size: 22, color: T.fg3),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s.strings.common.acc_not_signed_in, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                ),
              ])
            : Row(children: [
                const SelfAvatar(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (name.isNotEmpty)
                      Text(name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                    Text(f.acc_signed_in, style: Typo.meta(ar: s.rtl)),
                  ]),
                ),
                Icon(LucideIcons.checkCircle2, size: 22, color: s.accent.main),
              ]),
      ),
      const SizedBox(height: 14),
      Semantics(
        button: true,
        child: Pressable(
          onTap: () {
            Navigator.pop(context);
            openFamily(context);
          },
          scale: 0.99,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.ink50,
              borderRadius: BorderRadius.circular(T.rLg),
              border: Border.all(color: T.border),
            ),
            child: Row(children: [
              const IconSquare(LucideIcons.users, bg: T.hueEmerald50, fg: T.hueEmeraldInk, size: 38, iconSize: 19),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.acc_family_t(s.gender),
                      style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                  Text(f.acc_family_b(s.gender), style: Typo.meta(ar: s.rtl)),
                ]),
              ),
              Chevron(rtl: s.rtl),
            ]),
          ),
        ),
      ),
    ]);
  }
}
