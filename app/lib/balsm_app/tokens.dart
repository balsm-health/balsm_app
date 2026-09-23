import 'package:flutter/widgets.dart';

/// Design tokens ported from `colors_and_type.css` + `app.css` of the
/// claude.ai/design "Patient App" prototype. Colors are the locked Balsm
/// brand palette (identical to packages/core `_tokens.dart`).
/// Which visual direction the app paints.
///
/// [standard] is the shipped Balsm Design System — `--balsm-surface: #FFFFFF`
/// and `--radius-lg/xl: 14/20px`, straight out of
/// `_ds/…/brand/colors_and_type.css`. It is what `Balsm App.html` renders, so
/// it is the default: the app is meant to match the prototype.
///
/// [warm] is `New Design Direction - Warm.html` — "cream surfaces instead of
/// cool-white cards, larger rounder radii, editorial Montserrat display type".
/// Montserrat is already the display family, so the two remaining deltas are
/// the ones below.
///
/// Switching this is a BRAND decision, not a styling one: the surface and
/// radius values are design-SYSTEM tokens shared with the website and every
/// other Balsm product. Flipping it here alone makes this app diverge from the
/// system it implements — deliberate divergence, not an accident, which is why
/// it lives behind a named constant rather than scattered literals. The
/// durable fix is a themed variant in Balsm-Core that mirrors out to all of
/// them.
///
/// Compile-time on purpose: `const` keeps every token const, so no call site
/// or `const` widget has to change.
enum BalsmDirection { standard, warm }

/// The direction this build paints. See [BalsmDirection].
///
/// [BalsmDirection.standard] is the design system's shipped look — what
/// `Balsm App.html` renders, and what `_ds/…/brand/colors_and_type.css` shares
/// with every other Balsm product. Warm was tried here and read as worse on
/// device, so this stays standard. Flipping the one word swaps surface and
/// radii; nothing else has to change.
const kDirection = BalsmDirection.standard;

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
  static const ink400 = Color(0xFF9BA4AD);
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
  static const danger = Color(0xFFD44A3C);
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
  /// Card and control background. The kit's shared widgets paint this rather
  /// than a literal white, so the surface is one token.
  ///
  /// White ink painted ON a coloured fill is NOT a surface and stays
  /// `Colors.white`: it must not follow this token when it changes.
  static const surface = kDirection == BalsmDirection.warm ? cream100 : white;
  static const surfaceAlt = cream100;
  static const surfaceMuted = ink50;
  static const surfaceInverse = ink900;
  static const border = ink200;
  static const borderStrong = ink300;
  static const borderFocus = hueBlue;

  static const fg1 = ink900; // primary text
  static const fg2 = ink700; // secondary
  static const fg3 = ink600; // tertiary / meta
  static const fg4 = ink400; // placeholder / disabled

  // ── Radii ──────────────────────────────────────────────────
  static const rXs = 4.0;
  static const rSm = 6.0;
  static const rMd = kDirection == BalsmDirection.warm ? 14.0 : 10.0;
  static const rLg = kDirection == BalsmDirection.warm ? 26.0 : 14.0;
  static const rXl = kDirection == BalsmDirection.warm ? 32.0 : 20.0;
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
