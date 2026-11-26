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

  /// `--content-max` as the patient app body sets it at expanded and up (app.css
  /// `@container app (min-width: 1024px) .app-body`): the 768 reading measure widened to 1024 for the
  /// app's card columns.
  static const appContentMax = 1024.0;
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
  /// Minimum target on a coarse pointer: Android asks 48, iOS 44, so 48 satisfies both. Hit area only;
  /// whatever is painted inside keeps its design size. Fine pointers use component intrinsics (button 38,
  /// row 40, icon-only 44).
  static const touchTarget = 48.0;
}
