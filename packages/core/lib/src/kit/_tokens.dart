import 'package:material_ui/material_ui.dart';

// Design tokens from Balsm-Core/brand/colors_and_type.css
// Superseded by BalsmTheme in T063 (Phase 2).
class BalsmColors {
  BalsmColors._();

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

  // App accent = hue-blue (primary CTA, focus, links)
  static const appAccent = hueBlue;
  static const appAccent600 = hueBlue600;
  static const appAccent50 = hueBlue50;

  // Neutrals (cool, navy-slate-biased — keyed to the #1F2D3D wordmark)
  static const ink900 = Color(0xFF14202B);
  static const ink800 = Color(0xFF1F2D3D); // = wordmark
  static const ink700 = Color(0xFF384756);
  static const ink600 = Color(0xFF526174); // = wordmark ".health" TLD
  static const ink500 = Color(0xFF78838F);
  static const ink400 = Color(0xFF9BA4AD);
  static const ink300 = Color(0xFFC0C6CC);
  static const ink200 = Color(0xFFDBDFE3); // border
  static const ink100 = Color(0xFFEBEDF0);
  static const ink50 = Color(0xFFF5F6F8);

  static const cream50 = Color(0xFFFAFAF7);
  static const cream100 = Color(0xFFF4F3EC);

  // Semantic
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

  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = cream100;
  static const surfaceMuted = ink50;
  static const surfaceInverse = ink900;
  static const border = ink200;
  static const borderStrong = ink300;
  static const borderFocus = hueBlue;

  // Foreground roles
  static const fg1 = ink900;
  static const fg2 = ink700;
  static const fg3 = ink600;
  static const fg4 = ink400;
}

class BalsmRadius {
  BalsmRadius._();
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 20.0;
  static const pill = 999.0;
}

class BalsmShadow {
  BalsmShadow._();
  // 0.06 * 255 ≈ 15 (0x0F), 0.04 * 255 ≈ 10 (0x0A)
  static const xs = [
    BoxShadow(color: Color(0x0F14202B), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const sm = [
    BoxShadow(color: Color(0x0F14202B), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0A14202B), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const md = [
    BoxShadow(color: Color(0x1414202B), blurRadius: 20, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A14202B), blurRadius: 6, offset: Offset(0, 2)),
  ];
  // Brand / accent glow
  static const brand = [
    BoxShadow(
      color: Color(0x381283FF),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}

// Duration constants from CSS motion tokens
class BalsmDuration {
  BalsmDuration._();
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
}

// Curve equivalent of CSS ease-out cubic-bezier(0.16, 1, 0.3, 1)
const kBalsmEaseOut = Curves.easeOutExpo;

/// Window class — the Tier 5 responsive layer (`responsive.css` +
/// `RESPONSIVE.md` in `Balsm-Core/brand/design-system`). The CSS side keeps
/// these thresholds as unitless px precisely so Flutter can resolve the same
/// classes out of a `LayoutBuilder`; keep the two in step.
enum BalsmWindowClass {
  compact,
  medium,
  expanded,
  wide;

  /// Resolve from the window's logical width.
  static BalsmWindowClass of(double width) => width < BalsmWindow.mediumMin
      ? BalsmWindowClass.compact
      : width < BalsmWindow.expandedMin
          ? BalsmWindowClass.medium
          : width < BalsmWindow.wideMin
              ? BalsmWindowClass.expanded
              : BalsmWindowClass.wide;
}

/// Row density. `compact` is floored to `standard` on touch — a 32px row
/// cannot hold a 44/48 target.
enum BalsmDensity { compact, standard, comfortable }

/// Window-class measurements. Ranges are continuous: every rule is a minimum,
/// never a fixed size. Members marked SPEC-ONLY have no component yet
/// (RESPONSIVE.md → Gaps).
class BalsmWindow {
  BalsmWindow._();

  // ── Thresholds ─────────────────────────────────────────────
  static const compactMax = 599.0;
  static const mediumMin = 600.0;
  static const mediumMax = 1023.0;
  static const expandedMin = 1024.0;
  static const expandedMax = 1439.0;
  static const wideMin = 1440.0;
  static const shortMax = 700.0; // height — "short" is an orthogonal modifier
  static const minWidth = 800.0; // below the minimum the window scrolls,
  static const minHeight = 600.0; // never clips

  static bool isShort(double height) => height <= shortMax;

  // ── Shell ──────────────────────────────────────────────────
  static const sidebarW = 240.0;
  static const railW = 72.0; // SPEC-ONLY
  static const bottomBarH = 64.0; // SPEC-ONLY
  static const topBarH = 56.0;
  static const topBarHShort = 48.0;

  static double topBarHeightFor(double windowHeight) => isShort(windowHeight) ? topBarHShort : topBarH;

  // ── Containment ────────────────────────────────────────────
  static const contentMax = 768.0; // single-column measure
  static const contentMaxGrid = 1200.0; // 12-col grid cap at wide
  static const gutter = 16.0;
  static const gutterMd = 24.0;
  static const gutterLg = 48.0;
  static const colsMobile = 4;
  static const colsTablet = 8;
  static const colsDesktop = 12;

  static double gutterFor(BalsmWindowClass cls) => switch (cls) {
        BalsmWindowClass.compact => gutter,
        BalsmWindowClass.medium => gutterMd,
        BalsmWindowClass.expanded || BalsmWindowClass.wide => gutterLg,
      };

  static int columnsFor(BalsmWindowClass cls) => switch (cls) {
        BalsmWindowClass.compact => colsMobile,
        BalsmWindowClass.medium => colsTablet,
        BalsmWindowClass.expanded || BalsmWindowClass.wide => colsDesktop,
      };

  // ── Panes ──────────────────────────────────────────────────
  static const paneListMin = 288.0;
  static const paneListMd = 288.0;
  static const paneListLg = 320.0;
  static const paneListXl = 352.0;
  static const paneInspector = 352.0; // wide only

  /// List-pane width; null at compact, where detail is a pushed route.
  static double? paneListWidthFor(BalsmWindowClass cls) => switch (cls) {
        BalsmWindowClass.compact => null,
        BalsmWindowClass.medium => paneListMd,
        BalsmWindowClass.expanded => paneListLg,
        BalsmWindowClass.wide => paneListXl,
      };

  // ── Overlays ───────────────────────────────────────────────
  static const sheetSideW = 400.0; // SPEC-ONLY
  static const modalMaxWSm = 380.0;
  static const modalMaxWMd = 460.0;
  static const modalMaxWLg = 640.0;
  static const modalMaxWXl = 860.0;

  // ── Density ────────────────────────────────────────────────
  static const rowHCompact = 32.0;
  static const rowHDefault = 40.0;
  static const rowHComfortable = 52.0;

  /// Class default, overridable per user or workspace. `compact` is floored to
  /// `standard` on a coarse pointer.
  static BalsmDensity densityFor(
    BalsmWindowClass cls, {
    required bool touch,
    BalsmDensity? override,
  }) {
    final resolved = override ??
        switch (cls) {
          BalsmWindowClass.compact => BalsmDensity.comfortable,
          BalsmWindowClass.medium => touch ? BalsmDensity.comfortable : BalsmDensity.standard,
          BalsmWindowClass.expanded || BalsmWindowClass.wide => BalsmDensity.standard,
        };
    return resolved == BalsmDensity.compact && touch ? BalsmDensity.standard : resolved;
  }

  static double rowHeight(BalsmDensity density) => switch (density) {
        BalsmDensity.compact => rowHCompact,
        BalsmDensity.standard => rowHDefault,
        BalsmDensity.comfortable => rowHComfortable,
      };

  // ── Input modality ─────────────────────────────────────────
  /// Minimum target on a coarse pointer. Fine pointers use component
  /// intrinsics (button 38, row 40, icon-only 44).
  static const touchTarget = 48.0;
}
