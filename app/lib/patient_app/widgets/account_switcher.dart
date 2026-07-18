import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:core/core.dart' show accountSummaryProvider;
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';

/// Account sheet (home.jsx AccountSwitcherSheet look).
///
/// P001 is a SINGLE-account app — multi-account / family members are a P002
/// concern — so this shows the one real signed-in account from
/// [accountSummaryProvider] (never fabricated family accounts). Signed-out or
/// still-loading renders a neutral empty state rather than crashing. There is
/// no "add member" affordance yet (that arrives with family accounts in P002).
Future<void> showAccountSwitcher(BuildContext context) {
  final s = AppScope.of(context);
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x5C2B2B25),
    builder: (ctx) => Directionality(
      textDirection: s.dir,
      child: _AccountSwitcherSheet(s),
    ),
  );
}

class _AccountSwitcherSheet extends ConsumerWidget {
  const _AccountSwitcherSheet(this.s);
  final PatientAppState s;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(accountSummaryProvider).valueOrNull;
    final displayName = (summary?.displayName ?? '').trim();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      padding: const EdgeInsets.only(bottom: 38),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(width: 38, height: 4, decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Expanded(child: Text(s.strings.your_accounts,
                style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700))),
            RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 17, onTap: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1, color: T.ink100),
        if (summary == null)
          _EmptyAccount(s)
        else
          _AccountRow(
            s,
            name: displayName,
            handle: summary.handle,
            onTap: () => Navigator.pop(context),
          ),
      ]),
    );
  }
}

/// The single, active, signed-in account row.
class _AccountRow extends StatelessWidget {
  const _AccountRow(this.s, {required this.name, required this.handle, required this.onTap});
  final PatientAppState s;
  final String name;
  final String? handle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final sub = (handle != null && handle!.isNotEmpty)
        ? '@$handle'
        : (s.strings.acc_active);
    return PressHighlight(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(children: [
          Avatar(initials: accountInitials(name), color: T.petalAqua, size: 48, ar: s.rtl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (name.isNotEmpty)
                Text(name, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
              const SizedBox(height: 3),
              Text(sub, textDirection: handle != null && handle!.isNotEmpty ? TextDirection.ltr : s.dir,
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ]),
          ),
          Icon(LucideIcons.checkCircle2, size: 22, color: s.accent.main),
        ]),
      ),
    );
  }
}

/// Signed-out / loading placeholder — no fabricated account.
class _EmptyAccount extends StatelessWidget {
  const _EmptyAccount(this.s);
  final PatientAppState s;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Row(children: [
          const Icon(LucideIcons.userCircle2, size: 22, color: T.fg3),
          const SizedBox(width: 12),
          Expanded(
            child: Text(s.strings.acc_not_signed_in,
                style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ),
        ]),
      );
}
