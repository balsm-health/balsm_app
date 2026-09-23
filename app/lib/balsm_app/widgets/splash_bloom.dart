import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import 'balsm_mark.dart';

/// The boot splash's mark composition (`auth.jsx` `SplashScreen`, `app.css`
/// `.splash-*`, default `data-anim="bloom"`).
///
/// The prototype ships six further variants — aurora, stagger, spin, shimmer,
/// orbit, pulse, float — behind `splashAnim`, which is set only by
/// `tweaks-panel.jsx`, a dev overlay that is prototype scratch and not ported.
/// `bloom` is what the product actually shows, so it is what this is:
///
///   * a five-hue aura that scales up behind the mark (`.splash-aura`),
///   * the mark itself blooming from 0.86 (`.splash-logo`),
///   * and the whole 208px wrap breathing once it has settled
///     (`.splash-logo-wrap`, `splashBreathe`).
///
/// Honours `prefers-reduced-motion`: the reduced-motion block in `app.css`
/// kills every splash animation and transform, so this renders the settled
/// frame with no controller running at all.
class SplashMark extends StatefulWidget {
  const SplashMark({super.key, this.size = 208});

  /// Edge of the square wrap (`.splash-logo-wrap` is 208).
  final double size;

  @override
  State<SplashMark> createState() => _SplashMarkState();
}

class _SplashMarkState extends State<SplashMark> with TickerProviderStateMixin {
  /// Drives the one-shot entrance: aura scale and mark bloom, which overlap
  /// on their own delays inside a single 1.5s timeline.
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  /// `splashBreathe 4.6s ease-in-out 1.4s infinite` — a ping-pong, so the
  /// controller runs half a period and reverses.
  late final AnimationController _breathe =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));

  /// `.splash-logo { transform: scale(0.86); animation: splashBloom 0.9s ease-out 0.15s }`
  late final Animation<double> _bloom = Tween(begin: 0.86, end: 1.0).animate(CurvedAnimation(
    parent: _in,
    curve: const Interval(0.15 / 1.5, (0.15 + 0.9) / 1.5, curve: Motion.easeOut),
  ));

  /// `.splash-aura { transform: scale(0.62); animation: splashAuraIn 1.3s ease-out 0.2s }`
  late final Animation<double> _aura = Tween(begin: 0.62, end: 1.0).animate(CurvedAnimation(
    parent: _in,
    curve: const Interval(0.2 / 1.5, (0.2 + 1.3) / 1.5, curve: Motion.easeOut),
  ));

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduced motion: jump to the settled frame rather than animating to it.
      _in.value = 1;
      return;
    }
    _in.forward();
    // The breathe starts at 1.4s, after the entrance has essentially landed.
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) _breathe.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _in.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    // The mark is 132 of the 208 wrap.
    final markSize = size * 132 / 208;
    return AnimatedBuilder(
      animation: Listenable.merge([_in, _breathe]),
      builder: (context, _) {
        // `splashBreathe`: 1 → 1.035 → 1 on an ease-in-out.
        final breathe = 1 + 0.035 * Curves.easeInOut.transform(_breathe.value);
        return Transform.scale(
          scale: breathe,
          child: SizedBox.square(
            dimension: size,
            child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              Transform.scale(scale: _aura.value, child: _Aura(size: size)),
              Transform.scale(
                scale: _bloom.value,
                child: BalsmFlower(size: markSize),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// `.splash-aura` — five blurred hue blobs, one per ribbon, laid out around
/// the mark. Each is a `radial-gradient(closest-side, hue, transparent 72%)`
/// sized and positioned as a CSS background layer.
class _Aura extends StatelessWidget {
  const _Aura({required this.size});
  final double size;

  /// CSS `blur(24px)` at the design's 208px box, scaled with [size].
  double get _sigma => 24 * size / 208;

  @override
  Widget build(BuildContext context) {
    // The blur bleeds well past the box in CSS (nothing clips it), so paint
    // onto a canvas big enough to hold the tail.
    final bleed = _sigma * 2;
    return SizedBox.square(
      dimension: size + bleed * 2,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
        child: CustomPaint(painter: _AuraPainter(box: size, origin: bleed)),
      ),
    );
  }
}

/// One entry per `background` layer of `.splash-aura`.
typedef _Blob = ({Color color, double alpha, double sizeFrac, double x, double y});

class _AuraPainter extends CustomPainter {
  const _AuraPainter({required this.box, required this.origin});

  /// Edge of the CSS box the layers are positioned within.
  final double box;

  /// Inset of that box inside the (larger) paint canvas.
  final double origin;

  /// `background-position` percentages with `background-size` percentages,
  /// straight off the stylesheet.
  static const _blobs = <_Blob>[
    (color: T.hueAqua, alpha: 0.34, sizeFrac: 0.66, x: 0.12, y: 0.04),
    (color: T.hueBlue, alpha: 0.30, sizeFrac: 0.66, x: 0.84, y: 0.20),
    (color: T.hueViolet, alpha: 0.30, sizeFrac: 0.64, x: 0.92, y: 0.82),
    (color: T.hueMint, alpha: 0.30, sizeFrac: 0.68, x: 0.22, y: 0.94),
    (color: T.hueEmerald, alpha: 0.30, sizeFrac: 0.64, x: -0.04, y: 0.60),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in _blobs) {
      final edge = box * b.sizeFrac;
      // CSS positions a background layer across the free space left over.
      final free = box - edge;
      final rect = Rect.fromLTWH(origin + b.x * free, origin + b.y * free, edge, edge);
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          edge / 2,
          [b.color.withValues(alpha: b.alpha), b.color.withValues(alpha: 0)],
          // `transparent 72%` — the stop, not the edge of the circle.
          [0.0, 0.72],
        );
      canvas.drawCircle(rect.center, edge / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) => old.box != box || old.origin != origin;
}

/// `.splash-dots` — five hue dots that lift in sequence, forever.
class SplashDots extends StatefulWidget {
  const SplashDots({super.key});

  @override
  State<SplashDots> createState() => _SplashDotsState();
}

class _SplashDotsState extends State<SplashDots> with SingleTickerProviderStateMixin {
  /// `splashDot 1.4s ease-out infinite`, with each dot 0.12s behind the last.
  /// One controller spans the whole stagger so the dots cannot drift apart.
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  /// Dot order and hue: `.splash-dots span:nth-child(n)`.
  static const _hues = [T.hueAqua, T.hueEmerald, T.hueBlue, T.hueMint, T.hueViolet];

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduced motion holds every dot at full opacity, unanimated.
    if (!MediaQuery.disableAnimationsOf(context)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// `0%, 100% { opacity: 0.35; transform: none } 30% { opacity: 1; translateY(-3px) }`
  ({double opacity, double dy}) _frame(double t) {
    final eased = t <= 0.3 ? Motion.easeOut.transform(t / 0.3) : Motion.easeOut.transform(1 - (t - 0.3) / 0.7);
    return (opacity: 0.35 + 0.65 * eased, dy: -3 * eased);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, hue) in _hues.indexed)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 9),
              child: Builder(builder: (_) {
                if (still) {
                  return _Dot(color: hue, opacity: 1, dy: 0);
                }
                // 0.12s of 1.4s per dot.
                final t = (_c.value - i * 0.12 / 1.4) % 1.0;
                final f = _frame(t < 0 ? t + 1 : t);
                return _Dot(color: hue, opacity: f.opacity, dy: f.dy);
              }),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.opacity, required this.dy});
  final Color color;
  final double opacity;
  final double dy;

  @override
  Widget build(BuildContext context) => Transform.translate(
        offset: Offset(0, dy),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color.withValues(alpha: opacity), shape: BoxShape.circle),
        ),
      );
}

/// `.splash-promise` / `.splash-foot` — a 9px rise on a delay. Both use the
/// same curve and differ only in when they start.
class SplashRise extends StatefulWidget {
  const SplashRise({super.key, required this.delay, required this.child});
  final Duration delay;
  final Widget child;

  @override
  State<SplashRise> createState() => _SplashRiseState();
}

class _SplashRiseState extends State<SplashRise> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 9 * (1 - Motion.easeOut.transform(_c.value))),
          child: child,
        ),
        child: widget.child,
      );
}
