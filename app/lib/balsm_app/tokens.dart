import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Design tokens ported from `colors_and_type.css` + `app.css` of the
/// claude.ai/design "Patient App" prototype. Colors are the locked Balsm
/// brand palette (identical to packages/core `_tokens.dart`).
class T {
  T._();

  // ── Brand hues (five-ribbon ring mark) ─────────────────────
  static const hueAqua = Color(0xFF02BBB5);
  static const hueEmerald = Color(0xFF01C4A2);
  static const hueBlue = Color(0xFF1283FF);
  static const hueMint = Color(0xFF55D77F);
  static const hueViolet = Color(0xFF724DD0);

  static const hueAqua600 = Color(0xFF029E99);
  static const hueEmerald600 = Color(0xFF019A7F);
  static const hueBlue600 = Color(0xFF0F6BCC);
  static const hueMint600 = Color(0xFF3FC366);
  static const hueViolet600 = Color(0xFF5C3AB0);

  static const hueAqua50 = Color(0xFFE2F8F6);
  static const hueEmerald50 = Color(0xFFE1F8F1);
  static const hueBlue50 = Color(0xFFE4F0FF);
  static const hueMint50 = Color(0xFFE8F9EE);
  static const hueViolet50 = Color(0xFFECE6FA);

  // ── Cool navy-slate neutrals (siblings of the wordmark) ────
  static const ink900 = Color(0xFF14202B);
  static const ink800 = Color(0xFF1F2D3D); // = wordmark
  static const ink700 = Color(0xFF384756);
  static const ink600 = Color(0xFF526174); // = wordmark ".health" TLD
  static const ink500 = Color(0xFF78838F);
  // Was 0xFF9BA4AD, which measured 2.42:1 on cream — below the 4.5 WCAG asks
  // for body text, and this ink carries placeholders and disabled labels.
  // 0xFF677281 clears it at 4.67:1 while staying the same cool grey.
  static const ink400 = Color(0xFF677281);
  static const ink300 = Color(0xFFC0C6CC);
  static const ink200 = Color(0xFFDBDFE3);
  static const ink100 = Color(0xFFEBEDF0);
  static const ink50 = Color(0xFFF5F6F8);
  static const white = Color(0xFFFFFFFF);

  static const cream50 = Color(0xFFFAFAF7);
  static const cream100 = Color(0xFFF4F3EC);
  static const cream200 = Color(0xFFEAE9DD);

  static const sun400 = Color(0xFFF5C842);
  static const sun500 = Color(0xFFE5B428);
  static const sun600 = Color(0xFFD9A020);

  // ── Semantic ───────────────────────────────────────────────
  static const success = hueMint;
  static const successBg = hueMint50;
  static const warning = Color(0xFFE5B428);
  static const warningBg = Color(0xFFFDF5DC);
  // Was 0xFFD44A3C: 4.15:1 on cream and 4.34:1 under white text, both short of
  // 4.5 at the sizes buttons and error lines actually use. Darkened to clear
  // both (5.80 and 6.06) without leaving the red it was.
  static const danger = Color(0xFFB4342A);
  static const dangerBg = Color(0xFFFBEBE7);
  static const controlled = hueViolet;
  static const controlledBg = hueViolet50;
  static const expiring = Color(0xFFD97A20);
  static const expiringBg = Color(0xFFFBEEDC);
  static const info = hueBlue;
  static const infoBg = hueBlue50;
  static const neutral = ink500;
  static const neutralBg = ink100;

  // ── Wordmark ───────────────────────────────────────────────
  static const wordmark = ink800; // بلسم · Balsm — navy slate
  static const wordmarkTld = ink600; // .health — same hue, lighter

  // ── Surfaces / foreground roles ────────────────────────────
  static const surface = white;
  static const surfaceAlt = cream100;
  static const surfaceMuted = ink50;
  static const surfaceInverse = ink900;
  static const border = ink200;
  static const borderStrong = ink300;
  static const borderFocus = hueBlue;

  /// Text or icon colour that stays legible on [fill].
  ///
  /// Picks ink900 or white by measuring, rather than assuming white reads on
  /// anything: white on mint is 2.28:1 and on sun 1.93:1 — invisible by the
  /// standard — while ink900 on those is 7.24 and 8.57. On violet and blue it
  /// is the other way round. Measuring means a new accent cannot quietly ship
  /// an illegible button.
  static Color onFill(Color fill) =>
      _contrast(ink900, fill) >= _contrast(const Color(0xFFFFFFFF), fill) ? ink900 : const Color(0xFFFFFFFF);

  static double _relativeLuminance(Color c) {
    double channel(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  }

  static double _contrast(Color a, Color b) {
    final la = _relativeLuminance(a);
    final lb = _relativeLuminance(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  static const fg1 = ink900; // primary text
  static const fg2 = ink700; // secondary
  static const fg3 = ink600; // tertiary / meta
  static const fg4 = ink400; // placeholder / disabled

  // ── Radii ──────────────────────────────────────────────────
  static const rXs = 4.0;
  static const rSm = 6.0;
  static const rMd = 10.0;
  static const rLg = 14.0;
  static const rXl = 20.0;
  static const r2xl = 28.0;
  static const rPill = 999.0;

  // ── Layout ─────────────────────────────────────────────────
  /// `--content-max` as the app body sets it at expanded and up (app.css
  /// `@container app (min-width: 1024px) .app-body`): the DS's 768 reading
  /// measure widened to 1024 for the app's card columns.
  static const contentMax = 1024.0;

  // ── Shadows (warm, soft) ───────────────────────────────────
  static const List<BoxShadow> shadowXs = [
    BoxShadow(color: Color(0x0F14202B), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0F14202B), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0A14202B), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x1414202B), blurRadius: 20, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A14202B), blurRadius: 6, offset: Offset(0, 2)),
  ];

  // App accent shadow (blue) — `--app-accent-shadow`
  static const List<BoxShadow> accentShadow = [
    BoxShadow(color: Color(0x421283FF), blurRadius: 22, offset: Offset(0, 8)),
  ];

  // ── Walkthrough-only shadows (walkthrough.css) ─────────────
  // Distinct alpha/blur from the shared --shadow-md/xs scale, so kept local
  // rather than aliased to shadowMd/shadowXs.
  static const List<BoxShadow> shadowWtTile = [
    BoxShadow(color: Color(0x1A14202B), blurRadius: 36, offset: Offset(0, 16)), // rgba(20,32,43,0.10)
    BoxShadow(color: Color(0x0F14202B), blurRadius: 8, offset: Offset(0, 3)), // rgba(20,32,43,0.06)
  ];
  static const List<BoxShadow> shadowWtDemo = [
    BoxShadow(color: Color(0x1F14202B), blurRadius: 36, offset: Offset(0, 16)), // rgba(20,32,43,0.12)
    BoxShadow(color: Color(0x0F14202B), blurRadius: 8, offset: Offset(0, 3)), // rgba(20,32,43,0.06)
  ];
  static const List<BoxShadow> shadowWtTabOn = [
    BoxShadow(color: Color(0x1F14202B), blurRadius: 4, offset: Offset(0, 1)), // rgba(20,32,43,0.12)
  ];
}

/// Motion tokens ported verbatim from `colors_and_type.css` (`--ease-*`,
/// `--dur-*`). One source of truth for every animation in the patient app so
/// durations/curves stay identical to the claude.ai/design prototype.
class Motion {
  Motion._();

  // ── Durations ──────────────────────────────────────────────
  static const fast = Duration(milliseconds: 120); // --dur-fast (press)
  static const base = Duration(milliseconds: 200); // --dur-base (state)
  static const slow = Duration(milliseconds: 320); // --dur-slow (fills/entrance)

  // ── Easing curves ──────────────────────────────────────────
  static const easeOut = Cubic(0.16, 1, 0.3, 1); // default — calm/spring-like
  static const easeIn = Cubic(0.7, 0, 0.84, 0);
  static const easeInOut = Cubic(0.65, 0, 0.35, 1);
}

/// The accent hue that tints CTAs, rings, active states. Default = blue.
class Accent {
  const Accent(this.main, this.d, this.bg, this.shadow);
  final Color main;
  final Color d; // darker (pressed)
  final Color bg; // wash
  final Color shadow;

  static const blue = Accent(T.hueBlue, T.hueBlue600, T.hueBlue50, Color(0x421283FF));
  static const aqua = Accent(T.hueAqua, T.hueAqua600, T.hueAqua50, Color(0x4202BBB5));
  static const emerald = Accent(T.hueEmerald, T.hueEmerald600, T.hueEmerald50, Color(0x4201C4A2));
  static const violet = Accent(T.hueViolet, T.hueViolet600, T.hueViolet50, Color(0x42724DD0));
  static const mint = Accent(T.hueMint600, Color(0xFF2FA552), T.hueMint50, Color(0x4D55D77F));

  List<BoxShadow> get boxShadow => [BoxShadow(color: shadow, blurRadius: 22, offset: const Offset(0, 8))];
}

// The Tier 5 window-class layer (thresholds, shell/pane sizes, density
// resolution) lives in the shared kernel as `BalsmWindow` / `BalsmWindowClass`
// / `BalsmDensity` — `package:core/core.dart`, already imported by this app.
// It is deliberately not duplicated here: unlike these colour tokens, nothing
// about it is prototype-specific.
