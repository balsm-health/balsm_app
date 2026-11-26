import 'package:flutter/widgets.dart';

/// Motion tokens ported verbatim from `colors_and_type.css` (`--ease-*`,
/// `--dur-*`). The one source for every animation duration and curve in the app
/// and the modules, so they stay identical to the claude.ai/design prototype.
class Motion {
  Motion._();

  // ── Durations ──────────────────────────────────────────────
  static const fast = Duration(milliseconds: 120); // --dur-fast (press)
  static const base = Duration(milliseconds: 200); // --dur-base (state)
  static const slow = Duration(milliseconds: 320); // --dur-slow (fills/entrance)

  /// A sheet sliding in, a page change, a programmatic scroll.
  static const transition = Duration(milliseconds: 300);

  /// One cycle of a looping placeholder: shimmer, indeterminate progress.
  static const loop = Duration(milliseconds: 1500);

  // ── Easing curves ──────────────────────────────────────────
  static const easeOut = Cubic(0.16, 1, 0.3, 1); // default — calm/spring-like
  static const easeInOut = Cubic(0.65, 0, 0.35, 1);
}
