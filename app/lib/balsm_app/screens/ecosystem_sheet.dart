import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import '../widgets/balsm_mark.dart';
import 'feedback_sheet.dart';

/// "Balsm is bigger than this app" — the ecosystem story plus concrete ways a
/// patient can help it spread.
///
/// One of the few brand moments where all five hues appear together.
Future<void> showEcosystemSheet(BuildContext context) => showAppSheet<void>(
      context,
      builder: (_) => const _EcosystemSheet(),
    );

/// Public landing pages the sheet links out to. None of these carry any
/// account or health data — they are the project's own marketing and code.
const _kDownloadUrl = 'https://balsm.health/download';
const _kProvidersUrl = 'https://balsm.health/providers';
const _kContributorsUrl = 'https://balsm.health/contributors';

/// The download URL as the design prints it in the share row — no scheme.
const _kDownloadLabel = 'balsm.health/download';

/// Social glyphs, drawn on Lucide's 24px grid at 1.9 stroke so they sit with
/// the rest of the icon set. `ecosystem.jsx` inlines these as SVG because
/// Lucide has no TikTok or Patreon mark; carrying the same path data keeps the
/// row visually identical to the prototype.
const _kSocial = <({String label, String url, String glyph})>[
  (
    label: 'balsm.health',
    url: 'https://balsm.health',
    glyph:
        '<circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/>',
  ),
  (
    label: 'LinkedIn',
    url: 'https://www.linkedin.com/company/balsm-health',
    glyph: '<path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-4 0v7h-4v-7a6 6 0 0 1 6-6z"/>'
        '<rect x="2" y="9" width="4" height="12"/><circle cx="4" cy="4" r="2"/>',
  ),
  (
    label: 'Facebook',
    url: 'https://www.facebook.com/balsm.health',
    glyph: '<path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z"/>',
  ),
  (
    label: 'Instagram',
    url: 'https://www.instagram.com/balsm.health',
    glyph: '<rect x="2" y="2" width="20" height="20" rx="5"/><circle cx="12" cy="12" r="4"/><path d="M17.5 6.5h.01"/>',
  ),
  (
    label: 'TikTok',
    url: 'https://www.tiktok.com/@balsm.health',
    glyph: '<path d="M13 3v12.5a3 3 0 1 1-3-3M13 3c.4 2.6 2.4 4.6 5 5"/>',
  ),
  (
    label: 'Patreon',
    url: 'https://www.patreon.com/balsm',
    glyph: '<circle cx="14.5" cy="9.5" r="6"/><path d="M4 3.5v17"/>',
  ),
  (
    label: 'GitHub',
    url: 'https://github.com/balsm-health',
    glyph:
        '<path d="M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 '
            '1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.4 5.4 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 '
            '1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4"/><path d="M9 18c-4.51 2-5-2-7-2"/>',
  ),
];

Future<void> _openExternal(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    await Clipboard.setData(ClipboardData(text: url));
  }
}

class _EcosystemSheet extends StatefulWidget {
  const _EcosystemSheet();

  @override
  State<_EcosystemSheet> createState() => _EcosystemSheetState();
}

class _EcosystemSheetState extends State<_EcosystemSheet> {
  /// Set only when the share sheet was unavailable and we fell back to the
  /// clipboard, so the row can say so. Cleared on the same 2.2s the design uses.
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _shareApp() async {
    final e = AppScope.of(context).strings.ecosystem;
    final text = '${e.eco_share_text} $_kDownloadUrl';
    final result = await SharePlus.instance.share(ShareParams(text: text, subject: 'Balsm'));
    if (result.status == ShareResultStatus.unavailable) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      setState(() => _copied = true);
      _copiedTimer?.cancel();
      _copiedTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final e = s.strings.ecosystem;

    final parts = <({IconData icon, Color fg, Color bg, String head, String body, bool roadmap})>[
      (icon: LucideIcons.smartphone, fg: T.hueBlue, bg: T.hueBlue50, head: e.eco_p1h, body: e.eco_p1b, roadmap: false),
      (icon: LucideIcons.building2, fg: T.hueAqua, bg: T.hueAqua50, head: e.eco_p2h, body: e.eco_p2b, roadmap: true),
    ];

    final actions = <({IconData icon, String head, String body, VoidCallback? onTap, _RowAffordance kind})>[
      (
        icon: LucideIcons.share2,
        head: e.eco_a1h,
        body: e.eco_a1b,
        onTap: _shareApp,
        kind: _RowAffordance.share,
      ),
      (
        icon: LucideIcons.messageSquare,
        head: e.eco_a2h,
        body: e.eco_a2b,
        onTap: () {
          Navigator.of(context).pop();
          showFeedbackSheet(context);
        },
        kind: _RowAffordance.chevron,
      ),
      (
        icon: LucideIcons.building2,
        head: e.eco_a3h,
        body: e.eco_a3b,
        onTap: () => _openExternal(_kProvidersUrl),
        kind: _RowAffordance.external,
      ),
      (
        icon: LucideIcons.code2,
        head: e.eco_a4h,
        body: e.eco_a4b,
        onTap: () => _openExternal(_kContributorsUrl),
        kind: _RowAffordance.external,
      ),
    ];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        const SheetGrab(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
          child: Row(children: [
            Expanded(child: Text(e.eco_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700))),
            RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 18, onTap: () => Navigator.of(context).pop()),
          ]),
        ),
        const Divider(height: 1, color: T.ink100),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 10, 20, sheetBottomInset(context, base: 32)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Brand moment — all five hues.
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
                _PartRow(icon: p.icon, fg: p.fg, bg: p.bg, head: p.head, body: p.body, roadmap: p.roadmap),
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
                      kind: a.kind,
                      first: i == 0,
                      copied: _copied,
                    ),
                ]),
              ),
              const SizedBox(height: 24),
              Text(e.eco_follow_t,
                  style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, fontSize: FS.md)),
              const SizedBox(height: 4),
              Text(e.eco_follow_sub, style: Typo.meta(ar: s.rtl)),
              const SizedBox(height: 12),
              const _SocialGrid(),
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
    this.roadmap = false,
  });
  final IconData icon;
  final Color fg;
  final Color bg;
  final String head;
  final String body;
  final bool roadmap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      // Was `var(--bg2)` — an undefined token that resolved to nothing. The
      // design now names the tint outright as `var(--balsm-ink-50)`, which
      // confirms the blank was an authoring slip rather than a white row.
      decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rMd)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconSquare(icon, bg: bg, fg: fg),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
              Text(head, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
              if (roadmap)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rPill)),
                  child: Text(s.strings.common.roadmap,
                      style: Typo.meta(ar: s.rtl)
                          .copyWith(fontSize: FS.xs2, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                ),
            ]),
            const SizedBox(height: 2),
            Text(body, style: Typo.meta(ar: s.rtl).copyWith(height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}

/// What a help row shows on its trailing edge — the design gives each kind of
/// destination its own mark rather than one generic chevron.
enum _RowAffordance { none, chevron, external, share }

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.head,
    required this.body,
    required this.onTap,
    required this.first,
    this.kind = _RowAffordance.none,
    this.copied = false,
  });
  final IconData icon;
  final String head;
  final String body;
  final VoidCallback? onTap;
  final bool first;
  final _RowAffordance kind;

  /// Share fell back to the clipboard — the row says so for 2.2s.
  final bool copied;

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
            if (kind == _RowAffordance.share) ...[
              const SizedBox(height: 6),
              // The URL is Latin either way, so it stays LTR in Arabic.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Align(
                  alignment: s.rtl ? Alignment.centerRight : Alignment.centerLeft,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(copied ? LucideIcons.check : LucideIcons.link,
                        size: 12, color: copied ? T.success : s.accent.d),
                    const SizedBox(width: 5),
                    // A long URL at a large text scale must ellipsize, not
                    // push the row past the card edge.
                    Flexible(
                      child: Text(
                        copied ? s.strings.ecosystem.eco_link_copied : _kDownloadLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Typo.meta(ar: s.rtl).copyWith(
                          fontSize: FS.xs,
                          fontWeight: FontWeight.w700,
                          color: copied ? T.success : s.accent.d,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ]),
        ),
        // Each destination gets the mark that matches where it goes.
        switch (kind) {
          _RowAffordance.chevron => Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Chevron(rtl: s.rtl),
            ),
          _RowAffordance.external => const Padding(
              padding: EdgeInsetsDirectional.only(start: 8),
              child: Icon(LucideIcons.externalLink, size: 16, color: T.fg3),
            ),
          _RowAffordance.share => const Padding(
              padding: EdgeInsetsDirectional.only(start: 8),
              child: Icon(LucideIcons.share, size: 16, color: T.fg3),
            ),
          _RowAffordance.none => const SizedBox.shrink(),
        },
      ]),
    );
    return onTap == null ? row : PressHighlight(onTap: onTap, child: row);
  }
}

/// Seven equal columns of 44px tiles, as the design's
/// `repeat(7, minmax(0, 1fr))` grid lays them out.
class _SocialGrid extends StatelessWidget {
  const _SocialGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 8.0;
      final tile = (c.maxWidth - gap * (_kSocial.length - 1)) / _kSocial.length;
      return Row(children: [
        for (final (i, x) in _kSocial.indexed) ...[
          if (i > 0) const SizedBox(width: gap),
          SizedBox(width: tile, child: _SocialTile(label: x.label, url: x.url, glyph: x.glyph)),
        ],
      ]);
    });
  }
}

class _SocialTile extends StatelessWidget {
  const _SocialTile({required this.label, required this.url, required this.glyph});
  final String label;
  final String url;
  final String glyph;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      link: true,
      child: Tooltip(
        message: label,
        child: Pressable(
          onTap: () => _openExternal(url),
          child: Container(
            height: 44,
            decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rMd)),
            alignment: Alignment.center,
            child: SvgPicture.string(
              '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" '
              'stroke="#000" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">$glyph</svg>',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(T.fg2, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
