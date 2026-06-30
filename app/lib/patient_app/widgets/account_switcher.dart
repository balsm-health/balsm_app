import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../data.dart';
import '../kit.dart';
import '../tokens.dart';

/// Bottom sheet to switch between family accounts (home.jsx AccountSwitcherSheet).
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

class _AccountSwitcherSheet extends StatelessWidget {
  const _AccountSwitcherSheet(this.s);
  final PatientAppState s;
  @override
  Widget build(BuildContext context) {
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
            Expanded(child: Text(s.t('your_accounts'),
                style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700))),
            RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 17, onTap: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1, color: T.ink100),
        for (var i = 0; i < kFamilyAccounts.length; i++)
          _AccountRow(s, kFamilyAccounts[i], last: i == kFamilyAccounts.length - 1, onTap: () {
            s.switchAccount(kFamilyAccounts[i].id);
            Navigator.pop(context);
          }),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: PButton(s.t('add_member'), icon: LucideIcons.userPlus, variant: BtnVariant.secondary, block: true, ar: s.rtl),
        ),
      ]),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow(this.s, this.acc, {required this.last, required this.onTap});
  final PatientAppState s;
  final FamilyAccount acc;
  final bool last;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final active = acc.id == s.activeAccountId;
    final sub = StringBuffer('${acc.relation.of(s.lang)} · ${acc.age} ${s.rtl ? 'سنة' : 'yrs'}');
    if (acc.conditions.isNotEmpty) sub.write(' · ${acc.conditions.first.of(s.lang)}');
    return PressHighlight(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: T.ink50))),
        child: Row(children: [
          Avatar(
            initials: acc.initials, color: acc.color, size: 48, ar: s.rtl,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(acc.name.of(s.lang), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
              const SizedBox(height: 3),
              Text(sub.toString(), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ]),
          ),
          if (active) Icon(LucideIcons.checkCircle2, size: 22, color: s.accent.main),
        ]),
      ),
    );
  }
}
