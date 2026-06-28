import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../data.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import 'personal_details.dart';

/// Profile tab (home.jsx ProfileScreen) — main screen + language/country sheets.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final curLang = kLanguages.firstWhere((l) => l.code == s.lang, orElse: () => kLanguages[1]);
    final storageCfg = _storageCfg('icloud'); // demo: primary backup
    final rows = <(IconData, String, VoidCallback?)>[
      (LucideIcons.user, 'p_personal', () => openPersonalDetails(context)),
      (LucideIcons.clipboardList, 'p_cond', null),
      (LucideIcons.calendar, 'appts', () => s.setTab('appts')),
      (LucideIcons.stethoscope, 'p_care', null),
      (LucideIcons.bell, 'p_notif', null),
      (LucideIcons.shieldCheck, 'p_privacy', null),
      (LucideIcons.lifeBuoy, 'p_help', null),
    ];
    return ContentColumn(maxWidth: 720, child: ListView(padding: EdgeInsets.zero, children: [
      const PadTop(),
      AppBarRow(children: [
        Expanded(child: Text(s.t('profile'), style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl))),
      ]),

      // Profile head
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        child: Column(children: [
          Avatar(initials: s.account.initials, color: s.account.color, size: 84, ar: s.rtl),
          const SizedBox(height: 14),
          Text(s.account.name.of(s.lang), style: Typo.title(ar: s.rtl).copyWith(fontSize: FS.xl2)),
          const SizedBox(height: 2),
          Text('${s.t('since')} ${s.account.since.of(s.lang)}', style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          if (s.account.conditions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
              for (final c in s.account.conditions)
                Pill(c.of(s.lang), kind: PillKind.neutral, dot: false, ar: s.rtl),
            ]),
          ],
        ]),
      ),

      // Language + country
      _ListCard(children: [
        _ListRow(icon: LucideIcons.languages, label: s.t('p_lang'), trailing: curLang.native,
            first: true, onTap: () => _showLanguageSheet(context)),
        _ListRow(icon: s.country.home ? LucideIcons.mapPin : LucideIcons.plane, label: s.t('p_country'),
            trailing: s.country.name.of(s.lang),
            iconBg: s.country.home ? null : T.sun500, iconFg: s.country.home ? null : Colors.white,
            onTap: () => _showCountrySheet(context)),
      ]),

      // Storage
      _ListCard(children: [
        _ListRow(icon: storageCfg.icon, label: s.t('storage'), iconBg: storageCfg.bg, iconFg: storageCfg.color,
            trailingWidget: Pill(s.t('store_backed'), kind: PillKind.info, ar: s.rtl), first: true, onTap: () {}),
      ]),

      // Menu
      _ListCard(children: [
        for (var i = 0; i < rows.length; i++)
          _ListRow(icon: rows[i].$1, label: s.t(rows[i].$2), first: i == 0, onTap: rows[i].$3 ?? () {}),
      ]),

      // Sign out
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: PButton(s.t('p_signout'), icon: LucideIcons.logOut, variant: BtnVariant.secondary,
            block: true, ar: s.rtl, color: T.danger),
      ),
    ]));
  }
}

({IconData icon, Color bg, Color color}) _storageCfg(String which) => switch (which) {
      'icloud' => (icon: LucideIcons.cloud, bg: T.petalBlue50, color: T.petalBlue),
      'gdrive' => (icon: LucideIcons.cloud, bg: T.petalMint50, color: T.petalMint600),
      _ => (icon: LucideIcons.smartphone, bg: T.ink100, color: T.ink700),
    };

class _ListCard extends StatelessWidget {
  const _ListCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => PCard(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(T.rLg),
          child: Column(children: children),
        ),
      );
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.icon, required this.label, this.trailing, this.trailingWidget, this.onTap, this.iconBg, this.iconFg, this.first = false});
  final IconData icon;
  final String label;
  final String? trailing;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
  final Color? iconBg;
  final Color? iconFg;
  final bool first;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: T.ink100))),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(children: [
          IconSquare(icon, bg: iconBg ?? s.accent.bg, fg: iconFg ?? s.accent.d, size: 34, iconSize: 19, radius: T.rSm),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w500, color: T.fg1))),
          if (trailingWidget != null) trailingWidget!,
          if (trailing != null)
            Padding(padding: const EdgeInsets.only(right: 8, left: 8),
                child: Text(trailing!, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3))),
          Chevron(rtl: s.rtl),
        ]),
      ),
    );
  }
}

// ── Language sheet ───────────────────────────────────────────
void _showLanguageSheet(BuildContext context) {
  final s = AppScope.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x5C2B2B25),
    builder: (ctx) => Directionality(
      textDirection: s.dir,
      child: _SheetShell(title: s.t('choose_lang'), children: [
        for (final l in kLanguages)
          _SelectRow(
            label: l.native, sub: l.en, selected: l.code == s.lang,
            badge: l.full ? s.t('lang_full') : s.t('lang_beta'), badgeOk: l.full,
            enabled: l.full,
            onTap: l.full ? () { s.setLang(l.code); Navigator.pop(ctx); } : null,
          ),
      ]),
    ),
  );
}

void _showCountrySheet(BuildContext context) {
  final s = AppScope.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x5C2B2B25),
    builder: (ctx) => Directionality(
      textDirection: s.dir,
      child: _SheetShell(title: s.t('choose_country'), subtitle: s.t('travel_help'), children: [
        for (final c in kCountries)
          _SelectRow(
            label: c.name.of(s.lang), sub: '${s.t('emergency')} ${c.emergency}',
            selected: c.code == s.countryCode,
            badge: c.home ? s.t('home_country') : null, badgeOk: true,
            onTap: () { s.setCountry(c.code); Navigator.pop(ctx); },
          ),
      ]),
    ),
  );
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, this.subtitle, required this.children});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
      padding: const EdgeInsets.only(bottom: 38),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(width: 38, height: 4, decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [Expanded(child: Text(title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)))])),
        if (subtitle != null)
          Padding(padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Align(alignment: AlignmentDirectional.centerStart, child: Text(subtitle!, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)))),
        const SizedBox(height: 8),
        Flexible(child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(horizontal: 12), children: children)),
      ]),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({required this.label, this.sub, this.selected = false, this.badge, this.badgeOk = true, this.enabled = true, this.onTap});
  final String label;
  final String? sub;
  final bool selected;
  final String? badge;
  final bool badgeOk;
  final bool enabled;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                if (sub != null) Text(sub!, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
              ]),
            ),
            if (badge != null) Padding(
              padding: const EdgeInsets.only(right: 8, left: 8),
              child: Pill(badge!, kind: badgeOk ? PillKind.success : PillKind.warn, dot: false, ar: s.rtl),
            ),
            if (selected) Icon(LucideIcons.checkCircle2, size: 22, color: s.accent.main),
          ]),
        ),
      ),
    );
  }
}
