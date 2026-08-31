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

  static TextStyle _display(bool ar) => ar ? GoogleFonts.ibmPlexSansArabic() : GoogleFonts.montserrat();
  static TextStyle _body(bool ar) => ar ? GoogleFonts.ibmPlexSansArabic() : GoogleFonts.ibmPlexSans();
  static TextStyle mono() => GoogleFonts.ibmPlexMono();

  static TextStyle display({bool ar = false}) => _display(ar)
      .copyWith(fontWeight: FontWeight.w800, fontSize: FS.xl3, height: 1.1, letterSpacing: -0.64, color: T.fg1);
  static TextStyle title({bool ar = false}) => _display(ar)
      .copyWith(fontWeight: FontWeight.w700, fontSize: FS.xl2, height: 1.18, letterSpacing: -0.4, color: T.fg1);
  static TextStyle heading({bool ar = false}) => _display(ar)
      .copyWith(fontWeight: FontWeight.w700, fontSize: FS.xl, height: 1.25, letterSpacing: -0.21, color: T.fg1);
  static TextStyle subhead({bool ar = false}) =>
      _display(ar).copyWith(fontWeight: FontWeight.w600, fontSize: FS.lg, height: 1.3, color: T.fg1);
  static TextStyle body({bool ar = false}) => _body(ar).copyWith(fontSize: FS.md, height: 1.55, color: T.fg2);
  static TextStyle bodySm({bool ar = false}) => _body(ar).copyWith(fontSize: FS.sm, height: 1.5, color: T.fg2);
  static TextStyle meta({bool ar = false}) => _body(ar).copyWith(fontSize: FS.xs, height: 1.4, color: T.fg3);
  static TextStyle eyebrow(Color color, {bool ar = false}) =>
      _body(ar).copyWith(fontSize: FS.xs2, fontWeight: FontWeight.w700, letterSpacing: ar ? 0 : 1.76, color: color);
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
  Widget build(BuildContext context) => Icon(icon, size: size, color: color ?? T.fg2);
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

/// 44px round icon button (.round-btn). Background darkens on press
/// (`:active { background: ink100 }`) over `--dur-base`.
class RoundBtn extends StatefulWidget {
  const RoundBtn({super.key, required this.icon, this.onTap, this.bg, this.fg, this.ghost = false, this.iconSize = 21});
  final IconData icon;
  final VoidCallback? onTap;
  final Color? bg;
  final Color? fg;
  final bool ghost;
  final double iconSize;
  @override
  State<RoundBtn> createState() => _RoundBtnState();
}

class _RoundBtnState extends State<RoundBtn> {
  bool _down = false;
  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final rest = widget.ghost ? Colors.transparent : (widget.bg ?? T.ink50);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.easeOut,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _down ? T.ink100 : rest,
          shape: BoxShape.circle,
          border: widget.ghost ? null : Border.all(color: T.border),
        ),
        child: Icon(widget.icon, size: widget.iconSize, color: widget.fg ?? T.ink700),
      ),
    );
  }
}

/// Back-navigation arrow that points the correct way for the ambient text
/// direction — left in LTR, right in RTL (Arabic). Lucide glyphs don't
/// auto-mirror, so the "back" vs "forward" direction is picked explicitly.
IconData backArrow(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl ? LucideIcons.arrowRight : LucideIcons.arrowLeft;

/// Forward/progression arrow — the mirror of [backArrow]. Points right in LTR,
/// left in RTL (Arabic), so it follows reading order in both directions.
IconData forwardArrow(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl ? LucideIcons.arrowLeft : LucideIcons.arrowRight;

/// Colored initials avatar (.avatar).
class Avatar extends StatelessWidget {
  const Avatar(
      {super.key,
      required this.initials,
      required this.color,
      this.size = 44,
      this.fontSize,
      this.ar = false,
      this.child});
  final String initials;
  final Color color;
  final double size;

  /// Initials size. The design sets this per use rather than by ratio — 16 at
  /// 44px (`.avatar`), 32 at 84px (`.profile-head .avatar`) — so the 0.36
  /// fallback only approximates. Pass it explicitly to match a spec exactly.
  final double? fontSize;
  final bool ar;
  final Widget? child;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: child ??
            Text(initials,
                style: Typo._display(ar)
                    .copyWith(fontWeight: FontWeight.w700, fontSize: fontSize ?? size * 0.36, color: Colors.white)),
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
    // Gentle press feedback on tappable cards.
    return Pressable(onTap: onTap, scale: 0.99, child: card);
  }
}

/// Clinical status variants — DS `.b-badge--*`. [violet] is the DS
/// `--controlled` flag (Schedule II/III); [brand] is solid accent with no dot.
enum PillKind { success, info, warn, danger, violet, expiring, emerald, neutral, brand, outline }

/// Status pill (.b-badge) with leading dot.
class Pill extends StatelessWidget {
  const Pill(this.label,
      {super.key, this.kind = PillKind.neutral, this.dot = true, this.ar = false, this.padding, this.small = false});
  final String label;
  final PillKind kind;
  final bool dot;
  final bool ar;
  final EdgeInsetsGeometry? padding;

  /// `.b-badge--sm` — tighter padding and 11px text for dense rows.
  final bool small;

  ({Color bg, Color fg, Color dot, Color? border}) get _c => switch (kind) {
        PillKind.success => (bg: T.petalMint50, fg: const Color(0xFF1F6A36), dot: T.petalMint, border: null),
        PillKind.info => (bg: T.petalBlue50, fg: const Color(0xFF08407A), dot: T.petalBlue, border: null),
        PillKind.warn => (bg: T.warningBg, fg: const Color(0xFF7A5A0F), dot: T.warning, border: null),
        PillKind.danger => (bg: T.dangerBg, fg: const Color(0xFF7A2A20), dot: T.danger, border: null),
        PillKind.violet => (bg: T.petalViolet50, fg: const Color(0xFF3D2872), dot: T.petalViolet, border: null),
        PillKind.expiring => (bg: T.expiringBg, fg: const Color(0xFF7A4310), dot: T.expiring, border: null),
        PillKind.emerald => (bg: T.petalEmerald50, fg: const Color(0xFF015A47), dot: T.petalEmerald, border: null),
        PillKind.neutral => (bg: T.ink100, fg: T.ink700, dot: T.ink500, border: null),
        PillKind.brand => (bg: T.petalBlue, fg: Colors.white, dot: Colors.white, border: null),
        PillKind.outline => (bg: T.surface, fg: T.ink700, dot: T.ink500, border: T.border),
      };

  @override
  Widget build(BuildContext context) {
    final c = _c;
    // The DS defines no dot for `--brand`; it reads as a solid tag, not a state.
    final showDot = dot && kind != PillKind.brand;
    return Container(
      padding: padding ??
          (small
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
              : const EdgeInsets.symmetric(horizontal: 11, vertical: 4)),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(T.rPill),
        border: c.border == null ? null : Border.all(color: c.border!),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (showDot) ...[
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c.dot, shape: BoxShape.circle)),
          SizedBox(width: small ? 4 : 6),
        ],
        Text(label,
            style: Typo._body(ar).copyWith(fontSize: small ? FS.xs2 : FS.xs, fontWeight: FontWeight.w600, color: c.fg)),
      ]),
    );
  }
}

/// Filter chip (`.b-chip`). Active fills the session accent; inactive is an
/// outlined pill. At least one chip in a set should stay on — the caller
/// enforces that.
class BChip extends StatelessWidget {
  const BChip(
    this.label, {
    super.key,
    required this.active,
    required this.onTap,
    required this.accent,
    this.ar = false,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color accent;
  final bool ar;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? accent : Colors.white,
          borderRadius: BorderRadius.circular(T.rPill),
          border: Border.all(color: active ? accent : T.border, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (active) ...[
            const Icon(LucideIcons.check, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: Typo._body(ar)
                  .copyWith(fontSize: FS.sm, fontWeight: FontWeight.w600, color: active ? Colors.white : T.fg2)),
        ]),
      ),
    );
  }
}

enum BtnVariant { primary, secondary, ghost, soft, danger, link }

/// Touch-density sizes — app.css retunes the DS `--btn-h-*` for a thumb-first
/// surface (DS is 30/38/46; the app is 40/52/56).
enum BtnSize { sm, md, lg }

/// Button (.b-btn) with variants + sizes.
class PButton extends StatelessWidget {
  const PButton(this.label,
      {super.key,
      this.icon,
      this.onTap,
      this.variant = BtnVariant.primary,
      this.large = false,
      this.size,
      this.block = false,
      this.accent,
      this.ar = false,
      this.color,
      this.gradient = false});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final BtnVariant variant;

  /// Shorthand for `size: BtnSize.lg`, kept for existing call sites.
  final bool large;

  /// Explicit size; wins over [large].
  final BtnSize? size;
  final bool block;
  final Accent? accent;
  final bool ar;
  final Color? color; // text-color override
  /// Horizontal accent wash on primary (welcome CTA in the live Claude Design).
  final bool gradient;

  BtnSize get _size => size ?? (large ? BtnSize.lg : BtnSize.md);

  double get _height => switch (_size) { BtnSize.sm => 40, BtnSize.md => 52, BtnSize.lg => 56 };
  double get _padX => switch (_size) { BtnSize.sm => 14, BtnSize.md => 20, BtnSize.lg => 24 };
  double get _fontSize => switch (_size) { BtnSize.sm => FS.sm, BtnSize.md => FS.md, BtnSize.lg => FS.lg };
  double get _radius => switch (_size) { BtnSize.sm => T.rSm, BtnSize.md => T.rMd, BtnSize.lg => T.rLg };
  double get _gap => switch (_size) { BtnSize.sm => 6, BtnSize.md => 9, BtnSize.lg => 10 };

  @override
  Widget build(BuildContext context) {
    final a = accent ?? Accent.blue;
    // `.b-btn:disabled { opacity: .4; pointer-events: none }`
    final enabled = onTap != null;
    Color bg, fg;
    Border? border;
    List<BoxShadow>? shadow;
    switch (variant) {
      case BtnVariant.primary:
        bg = a.main;
        fg = Colors.white;
        shadow = a.boxShadow;
        break;
      case BtnVariant.secondary:
        bg = Colors.white;
        fg = color ?? T.fg1;
        border = Border.all(color: T.border);
        break;
      case BtnVariant.ghost:
        bg = Colors.transparent;
        fg = color ?? a.main;
        break;
      case BtnVariant.soft:
        bg = a.bg;
        fg = a.d;
        break;
      case BtnVariant.danger:
        bg = T.danger;
        fg = Colors.white;
        break;
      case BtnVariant.link:
        bg = Colors.transparent;
        fg = color ?? a.main;
        break;
    }

    // `.b-btn-link` is text, not a slab: auto height, underlined, 2px inset.
    if (variant == BtnVariant.link) {
      return Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Pressable(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(label,
                style: Typo._body(ar).copyWith(
                  fontSize: _fontSize,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  decoration: TextDecoration.underline,
                  decorationColor: fg,
                )),
          ),
        ),
      );
    }

    final useGrad = gradient && variant == BtnVariant.primary;
    final child = Container(
      height: _height,
      width: block ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: _padX),
      decoration: BoxDecoration(
        color: useGrad ? null : bg,
        gradient: useGrad
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                // Live Claude Design: lighter wash on the left, accent on the right.
                colors: [Color.lerp(a.main, Colors.white, 0.28)!, a.main],
              )
            : null,
        borderRadius: BorderRadius.circular(_radius),
        border: border,
        // A shadow under a faded button reads as an enabled control.
        boxShadow: enabled ? shadow : null,
      ),
      child: Row(
        mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: fg), SizedBox(width: _gap)],
          Text(label, style: Typo._body(ar).copyWith(fontSize: _fontSize, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
    // .b-btn:active { transform: scale(0.98) } — press feedback.
    return Opacity(opacity: enabled ? 1 : 0.4, child: Pressable(onTap: onTap, child: child));
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
        child: Row(
            // `.row-head { align-items: baseline }` — the 13px action sits on the
            // same baseline as the 18px title. The icon variant has no text to
            // align against, so it centers instead.
            crossAxisAlignment: leadingIcon == null ? CrossAxisAlignment.baseline : CrossAxisAlignment.center,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 18, color: T.fg3),
                const SizedBox(width: 8),
              ],
              Expanded(
                  child: Text(title,
                      style:
                          Typo._display(ar).copyWith(fontWeight: FontWeight.w700, fontSize: fontSize, color: T.fg1))),
              if (action != null)
                GestureDetector(
                  onTap: onAction,
                  child: Text(action!,
                      style: Typo._body(ar)
                          .copyWith(fontSize: FS.sm, fontWeight: FontWeight.w600, color: Accent.blue.main)),
                ),
            ]),
      );
}

/// Circular progress ring (streak / adherence).
class RingProgress extends StatelessWidget {
  const RingProgress(
      {super.key, required this.progress, required this.color, this.label, this.size = 56, this.labelStyle});
  final double progress; // 0..1
  final Color color;
  final String? label;
  final double size;
  final TextStyle? labelStyle;
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        // Animate the arc sweep from 0 → progress (`.b-progress-ring__fill`
        // stroke-dashoffset transition over --dur-slow ease-out).
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
          duration: reduce ? Duration.zero : Motion.slow,
          curve: Motion.easeOut,
          builder: (_, v, __) => CustomPaint(size: Size(size, size), painter: _RingPainter(v, color)),
        ),
        if (label != null)
          // `.ring .rtxt` — display family, weight 800, 16px. (The DS's own
          // `.b-progress-ring__center` is mono; the app's streak ring is not.)
          Text(label!,
              style: labelStyle ??
                  Typo._display(false).copyWith(fontWeight: FontWeight.w800, fontSize: FS.md, color: T.fg1)),
      ]),
    );
  }
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
    final track = Paint()
      ..color = T.ink100
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

/// Small leading icon square used in shortcut/list rows.
class IconSquare extends StatelessWidget {
  const IconSquare(this.icon,
      {super.key, required this.bg, required this.fg, this.size = 38, this.iconSize = 19, this.radius = T.rMd});
  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;
  final double iconSize;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
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

// ════════════════════════════════════════════════════════════════
//  Motion primitives — ported from app.css / ds-loaders.css.
//  Every one honors MediaQuery.disableAnimations (prefers-reduced-motion).
// ════════════════════════════════════════════════════════════════

/// Press-to-scale feedback wrapper. Matches `.btn:active { transform:
/// scale(0.98) }` with `transform var(--dur-fast) var(--ease-out)`.
/// Pass a smaller [scale] for FABs (0.93) / keypad (0.97).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.98,
    this.behavior = HitTestBehavior.opaque,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final target = (_down && !reduce) ? widget.scale : 1.0;
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: target,
        duration: Motion.fast,
        curve: Motion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Tap row that flashes a background tint while held (`.list-row:active`,
/// `.history-row:active` → `background: ink50`) over `--dur-base`. Use for
/// list/history rows that change background rather than scale on press.
class PressHighlight extends StatefulWidget {
  const PressHighlight({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 0,
    this.color,
    this.border,
    this.behavior = HitTestBehavior.opaque,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;

  /// Outline kept through the press, for tiles that read as cards.
  final BoxBorder? border;
  final HitTestBehavior behavior;
  @override
  State<PressHighlight> createState() => _PressHighlightState();
}

class _PressHighlightState extends State<PressHighlight> {
  bool _down = false;
  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : Motion.base,
        curve: Motion.easeOut,
        decoration: BoxDecoration(
          color: _down ? (widget.color ?? T.ink50) : Colors.transparent,
          border: widget.border,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Entrance motion — `.fade-in` (`@keyframes fadeIn`): rises 7px → 0 over
/// `--dur-slow`. Transform-only (content is never hidden if throttled), with
/// an optional [delay] for staggering list/grid items (~40ms each).
class RiseIn extends StatefulWidget {
  const RiseIn({super.key, required this.child, this.delay = Duration.zero, this.dy = 7});
  final Widget child;
  final Duration delay;
  final double dy;
  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.slow);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Motion.easeOut);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) return widget.child;
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, widget.dy * (1 - _a.value)),
        child: Opacity(opacity: _a.value, child: child),
      ),
      child: widget.child,
    );
  }
}

/// Linear progress bar (`.b-progress__track` + `__fill`): 8px pill track
/// (`--balsm-ink-100`), fill whose width animates over `--dur-slow` ease-out.
/// [value] is 0..1. Set [indeterminate] for the unknown-duration loader — a
/// 42%-wide segment slides through the track (`b-prog-slide 1.5s ease-in-out`).
class LinearProgress extends StatefulWidget {
  const LinearProgress({
    super.key,
    this.value = 0,
    this.indeterminate = false,
    this.color,
    this.height = 7,
    this.track,
  });
  final double value;
  final bool indeterminate;
  final Color? color;
  final double height;
  final Color? track;
  @override
  State<LinearProgress> createState() => _LinearProgressState();
}

class _LinearProgressState extends State<LinearProgress> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.indeterminate && !reduce) {
      _c ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final fill = widget.color ?? Accent.blue.main;
    final pill = BorderRadius.circular(T.rPill);

    Widget fillWidget;
    if (widget.indeterminate && _c != null) {
      // 42%-wide segment travels off-left → off-right over the first 60% of the
      // cycle, then holds (matches the `b-prog-slide` keyframe hold).
      fillWidget = AnimatedBuilder(
        animation: _c!,
        builder: (_, __) => LayoutBuilder(
          builder: (_, c) {
            final w = c.maxWidth;
            final e = Motion.easeInOut.transform((_c!.value / 0.6).clamp(0.0, 1.0));
            return Stack(children: [
              PositionedDirectional(
                start: (-0.42 + 1.42 * e) * w,
                top: 0,
                bottom: 0,
                width: 0.42 * w,
                child: DecoratedBox(decoration: BoxDecoration(color: fill, borderRadius: pill)),
              ),
            ]);
          },
        ),
      );
    } else {
      fillWidget = Align(
        alignment: AlignmentDirectional.centerStart,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: widget.value.clamp(0.0, 1.0)),
          duration: reduce ? Duration.zero : Motion.slow,
          curve: Motion.easeOut,
          builder: (_, v, __) => FractionallySizedBox(
            widthFactor: widget.indeterminate ? 1 : v, // reduced-motion indeterminate = full bar
            child: DecoratedBox(decoration: BoxDecoration(color: fill, borderRadius: pill)),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: pill,
      child: Container(
        height: widget.height,
        color: widget.track ?? T.ink100,
        child: fillWidget,
      ),
    );
  }
}

/// Shimmering skeleton placeholder (`.b-skeleton` — `b-shimmer 1.5s
/// ease-in-out infinite`). Sized by the caller.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.width, this.height = 12, this.radius = T.rXs, this.circle = false});
  final double? width;
  final double height;
  final double radius;
  final bool circle;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shape = BoxDecoration(
      borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
      shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
    );
    if (reduce) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: shape.copyWith(color: T.ink200),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        // 280% background swept by b-shimmer 180% → -180% on an ease-in-out clock.
        final e = Motion.easeInOut.transform(_c.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: shape.copyWith(
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - e), 0),
              end: Alignment(1 + 2 * e, 0),
              colors: const [T.ink200, T.ink100, T.ink200],
              stops: const [0.25, 0.37, 0.63],
            ),
          ),
        );
      },
    );
  }
}

/// Ring spinner (`.b-ring-spinner`): a single-hue conic comet — a transparent
/// tail sweeping to a solid head — rotating at `b-spin 0.85s linear infinite`.
/// The inline workhorse loader. Pass [color] for the hue variants (accent /
/// success / violet / ink map to a petal/ink color). Keeps spinning under
/// reduced motion — a loading indicator that freezes reads as hung.
class Spinner extends StatefulWidget {
  const Spinner({super.key, this.size = 28, this.color, this.stroke = 3});
  final double size;
  final Color? color;
  final double stroke;
  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 850))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Accent.blue.main;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Transform.rotate(
            angle: _c.value * 2 * math.pi,
            child: CustomPaint(painter: _RingSpinnerPainter(color, widget.stroke)),
          ),
        ),
      ),
    );
  }
}

class _RingSpinnerPainter extends CustomPainter {
  _RingSpinnerPainter(this.color, this.stroke);
  final Color color;
  final double stroke;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = (size.shortestSide - stroke) / 2;
    // conic-gradient(from 90deg, transparent, color) — transparent tail → solid
    // head. Flutter's SweepGradient starts at +x (= CSS `from 90deg`), so the
    // seam sits at the 3-o'clock position; rotation makes its origin moot.
    final shader = SweepGradient(
      colors: [color.withValues(alpha: 0), color],
      stops: const [0, 1],
    ).createShader(Offset.zero & size);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingSpinnerPainter old) => old.color != color || old.stroke != stroke;
}

/// Full-surface loading overlay (`.b-overlay`): fades in over `--dur-base`,
/// centers a [Spinner] + optional message above a cream/scrim backdrop.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, this.message, this.scrim = false, this.ar = false});
  final String? message;
  final bool scrim;
  final bool ar;
  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final inner = Column(mainAxisSize: MainAxisSize.min, children: [
      Spinner(color: scrim ? Colors.white : Accent.blue.main),
      if (message != null) ...[
        const SizedBox(height: 18),
        Text(message!,
            textAlign: TextAlign.center,
            style: Typo.subhead(ar: ar).copyWith(color: scrim ? Colors.white : T.fg1, fontSize: 17)),
      ],
    ]);
    final body = Container(
      color: scrim ? const Color(0x8C14202B) : T.cream50,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: inner,
    );
    if (reduce) return body;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base,
      curve: Motion.easeOut,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: body,
    );
  }
}

/// Top navigation loading bar (`.b-toploader--indeterminate`): a glowing accent
/// segment slides left→right while [loading], fading out when it clears.
/// Sits flush to the top of the screen surface (shown on tab change).
class TopLoadingBar extends StatefulWidget {
  const TopLoadingBar({super.key, required this.loading, this.color, this.height = 3});
  final bool loading;
  final Color? color;
  final double height;
  @override
  State<TopLoadingBar> createState() => _TopLoadingBarState();
}

class _TopLoadingBarState extends State<TopLoadingBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1150))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final color = widget.color ?? Accent.blue.main;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.loading ? 1 : 0,
        duration: Motion.slow,
        curve: Motion.easeOut,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: (widget.loading && !reduce)
              ? LayoutBuilder(builder: (_, c) {
                  final barW = c.maxWidth * 0.32;
                  return AnimatedBuilder(
                    animation: _c,
                    builder: (_, __) => Stack(children: [
                      PositionedDirectional(
                        start: (-0.34 + 1.34 * _c.value) * c.maxWidth,
                        top: 0,
                        bottom: 0,
                        width: barW,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(T.rPill)),
                            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)],
                          ),
                        ),
                      ),
                    ]),
                  );
                })
              : null,
        ),
      ),
    );
  }
}

/// `.b-check` — the design system's checkbox / radio.
///
/// Box is 18×18 (radius 5, or a circle for [radio]) with a 1.5px `ink300`
/// outline; checked fills with `--balsm-primary`, which app.jsx rebinds to the
/// accent petal ("so DS components follow it"), so pass the session [accent].
class BCheck extends StatelessWidget {
  const BCheck({
    super.key,
    required this.label,
    required this.checked,
    required this.onTap,
    required this.accent,
    this.icon,
    this.radio = false,
    this.ar = false,
  });
  final String label;
  final bool checked;
  final VoidCallback onTap;
  final Accent accent;

  /// Optional glyph shown before the label (15px, per `SymptomPicker`).
  final IconData? icon;
  final bool radio;
  final bool ar;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              curve: Motion.easeOut,
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: checked ? accent.main : Colors.white,
                shape: radio ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: radio ? null : BorderRadius.circular(5),
                border: Border.all(color: checked ? accent.main : T.ink300, width: 1.5),
              ),
              child: radio
                  ? AnimatedScale(
                      scale: checked ? 1 : 0,
                      duration: const Duration(milliseconds: 130),
                      curve: Motion.easeOut,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    )
                  : AnimatedOpacity(
                      opacity: checked ? 1 : 0,
                      duration: const Duration(milliseconds: 110),
                      child: const Icon(LucideIcons.check, size: 12, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(width: 9),
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 15, color: T.fg1),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(label, style: Typo.body(ar: ar).copyWith(fontSize: 14, height: 1.45, color: T.fg1)),
          ),
        ]),
      );
}
