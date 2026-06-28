import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'tokens.dart';

// ── Font scale (app.css --pt-* at scale 1) ───────────────────
class FS {
  FS._();
  static const xs2 = 11.0;
  static const xs = 12.0;
  static const sm = 13.0;
  static const base = 15.0;
  static const md = 16.0;
  static const lg = 18.0;
  static const xl = 21.0;
  static const xl2 = 26.0;
  static const xl3 = 32.0;
  static const xl4 = 40.0;
}

/// Typography helpers. `ar` switches the family to IBM Plex Sans Arabic.
class Typo {
  Typo._();

  static TextStyle _display(bool ar) =>
      ar ? GoogleFonts.ibmPlexSansArabic() : GoogleFonts.montserrat();
  static TextStyle _body(bool ar) =>
      ar ? GoogleFonts.ibmPlexSansArabic() : GoogleFonts.ibmPlexSans();
  static TextStyle mono() => GoogleFonts.ibmPlexMono();

  static TextStyle display({bool ar = false}) => _display(ar).copyWith(
      fontWeight: FontWeight.w800, fontSize: FS.xl3, height: 1.1, letterSpacing: -0.64, color: T.fg1);
  static TextStyle title({bool ar = false}) => _display(ar).copyWith(
      fontWeight: FontWeight.w700, fontSize: FS.xl2, height: 1.18, letterSpacing: -0.4, color: T.fg1);
  static TextStyle heading({bool ar = false}) => _display(ar).copyWith(
      fontWeight: FontWeight.w700, fontSize: FS.xl, height: 1.25, letterSpacing: -0.21, color: T.fg1);
  static TextStyle subhead({bool ar = false}) => _display(ar).copyWith(
      fontWeight: FontWeight.w600, fontSize: FS.lg, height: 1.3, color: T.fg1);
  static TextStyle body({bool ar = false}) =>
      _body(ar).copyWith(fontSize: FS.md, height: 1.55, color: T.fg2);
  static TextStyle bodySm({bool ar = false}) =>
      _body(ar).copyWith(fontSize: FS.sm, height: 1.5, color: T.fg2);
  static TextStyle meta({bool ar = false}) =>
      _body(ar).copyWith(fontSize: FS.xs, height: 1.4, color: T.fg3);
  static TextStyle eyebrow(Color color, {bool ar = false}) => _body(ar).copyWith(
      fontSize: FS.xs2, fontWeight: FontWeight.w700,
      letterSpacing: ar ? 0 : 1.76, color: color);
  static TextStyle num({double size = FS.md, FontWeight weight = FontWeight.w600, Color color = T.fg1}) =>
      mono().copyWith(fontSize: size, fontWeight: weight, color: color);
}

/// Lucide icon shorthand.
class LIcon extends StatelessWidget {
  const LIcon(this.icon, {super.key, this.size = 20, this.color, this.stroke = 1.9});
  final IconData icon;
  final double size;
  final Color? color;
  final double stroke; // visual hint only
  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: size, color: color ?? T.fg2);
}

// ── Status-bar / home-indicator spacers ──────────────────────
/// Clears the status bar / dynamic island. Adapts to the real top inset
/// (framed device mode injects a synthetic inset) with a sensible minimum.
class PadTop extends StatelessWidget {
  const PadTop({super.key});
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return SizedBox(height: (top > 0 ? top + 6 : 24).clamp(24, 80).toDouble());
  }
}

// ── App bar row (.appbar) ────────────────────────────────────
class AppBarRow extends StatelessWidget {
  const AppBarRow({super.key, this.leading, required this.children});
  final Widget? leading;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          ...children,
        ]),
      );
}

/// 44px round icon button (.round-btn).
class RoundBtn extends StatelessWidget {
  const RoundBtn({super.key, required this.icon, this.onTap, this.bg, this.fg, this.ghost = false, this.iconSize = 21});
  final IconData icon;
  final VoidCallback? onTap;
  final Color? bg;
  final Color? fg;
  final bool ghost;
  final double iconSize;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: ghost ? Colors.transparent : (bg ?? T.ink50),
            shape: BoxShape.circle,
            border: ghost ? null : Border.all(color: T.border),
          ),
          child: Icon(icon, size: iconSize, color: fg ?? T.ink700),
        ),
      );
}

/// Colored initials avatar (.avatar).
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.initials, required this.color, this.size = 44, this.ar = false, this.child});
  final String initials;
  final Color color;
  final double size;
  final bool ar;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: child ??
            Text(initials,
                style: Typo._display(ar).copyWith(
                    fontWeight: FontWeight.w700, fontSize: size * 0.36, color: Colors.white)),
      );
}

/// White rounded card (.card).
class PCard extends StatelessWidget {
  const PCard({super.key, required this.child, this.margin, this.padding, this.flat = false, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool flat;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(T.rLg),
        border: Border.all(color: T.border),
        boxShadow: flat ? null : T.shadowSm,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card);
  }
}

enum PillKind { success, info, warn, danger, violet, neutral }

/// Status pill (.pill) with leading dot.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.kind = PillKind.neutral, this.dot = true, this.ar = false, this.padding});
  final String label;
  final PillKind kind;
  final bool dot;
  final bool ar;
  final EdgeInsetsGeometry? padding;

  ({Color bg, Color fg, Color dot}) get _c => switch (kind) {
        PillKind.success => (bg: T.petalMint50, fg: const Color(0xFF1F6A36), dot: T.petalMint),
        PillKind.info => (bg: T.petalBlue50, fg: const Color(0xFF08407A), dot: T.petalBlue),
        PillKind.warn => (bg: const Color(0xFFFDF5DC), fg: const Color(0xFF7A5A0F), dot: T.warning),
        PillKind.danger => (bg: const Color(0xFFFBEBE7), fg: const Color(0xFF7A2A20), dot: T.danger),
        PillKind.violet => (bg: T.petalViolet50, fg: const Color(0xFF3D2872), dot: T.petalViolet),
        PillKind.neutral => (bg: T.ink100, fg: T.ink700, dot: T.ink500),
      };

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(T.rPill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c.dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Text(label, style: Typo._body(ar).copyWith(fontSize: FS.xs, fontWeight: FontWeight.w600, color: c.fg)),
      ]),
    );
  }
}

enum BtnVariant { primary, secondary, ghost, soft }

/// Button (.btn) with variants + sizes.
class PButton extends StatelessWidget {
  const PButton(this.label,
      {super.key, this.icon, this.onTap, this.variant = BtnVariant.primary,
      this.large = false, this.block = false, this.accent, this.ar = false, this.color});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final BtnVariant variant;
  final bool large;
  final bool block;
  final Accent? accent;
  final bool ar;
  final Color? color; // text-color override

  @override
  Widget build(BuildContext context) {
    final a = accent ?? Accent.blue;
    Color bg, fg;
    Border? border;
    List<BoxShadow>? shadow;
    switch (variant) {
      case BtnVariant.primary:
        bg = a.main; fg = Colors.white; shadow = a.boxShadow;
        break;
      case BtnVariant.secondary:
        bg = Colors.white; fg = color ?? T.fg1; border = Border.all(color: T.borderStrong);
        break;
      case BtnVariant.ghost:
        bg = Colors.transparent; fg = color ?? a.main;
        break;
      case BtnVariant.soft:
        bg = a.bg; fg = a.d;
        break;
    }
    final child = Container(
      height: large ? 56 : 52,
      width: block ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(large ? T.rLg : T.rMd),
        border: border,
        boxShadow: shadow,
      ),
      child: Row(
        mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 9)],
          Text(label, style: Typo._body(ar).copyWith(
              fontSize: large ? FS.lg : FS.md, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
    return GestureDetector(onTap: onTap, child: child);
  }
}

/// Section header row (.row-head): bold title + optional trailing action.
class RowHead extends StatelessWidget {
  const RowHead(this.title, {super.key, this.action, this.onAction, this.ar = false, this.margin})
      : leadingIcon = null,
        fontSize = FS.lg;
  const RowHead.icon(this.title, {super.key, required IconData icon, this.ar = false})
      : action = null,
        onAction = null,
        leadingIcon = icon,
        fontSize = FS.md,
        margin = const EdgeInsets.fromLTRB(20, 18, 20, 10);
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final bool ar;
  final EdgeInsetsGeometry? margin;
  final IconData? leadingIcon;
  final double fontSize;
  @override
  Widget build(BuildContext context) => Padding(
        padding: margin ?? const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 18, color: T.fg3),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(title,
              style: Typo._display(ar).copyWith(fontWeight: FontWeight.w700, fontSize: fontSize, color: T.fg1))),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: Typo._body(ar).copyWith(fontSize: FS.sm, fontWeight: FontWeight.w600, color: Accent.blue.main)),
            ),
        ]),
      );
}

/// Circular progress ring (streak / adherence).
class RingProgress extends StatelessWidget {
  const RingProgress({super.key, required this.progress, required this.color, this.label, this.size = 56, this.labelStyle});
  final double progress; // 0..1
  final Color color;
  final String? label;
  final double size;
  final TextStyle? labelStyle;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size, height: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: Size(size, size), painter: _RingPainter(progress, color)),
          if (label != null)
            Text(label!, style: labelStyle ?? Typo.display().copyWith(fontSize: FS.md, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final c = size.center(Offset.zero);
    final r = (size.width - stroke) / 2;
    final track = Paint()..color = T.ink100..style = PaintingStyle.stroke..strokeWidth = stroke;
    final arc = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

/// Small leading icon square used in shortcut/list rows.
class IconSquare extends StatelessWidget {
  const IconSquare(this.icon, {super.key, required this.bg, required this.fg, this.size = 38, this.iconSize = 19, this.radius = T.rMd});
  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;
  final double iconSize;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
        child: Icon(icon, size: iconSize, color: fg),
      );
}

/// Directional chevron (flips in RTL).
class Chevron extends StatelessWidget {
  const Chevron({super.key, this.rtl = false, this.size = 18, this.color});
  final bool rtl;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Transform.flip(
        flipX: rtl,
        child: Icon(LucideIcons.chevronRight, size: size, color: color ?? T.fg4),
      );
}
