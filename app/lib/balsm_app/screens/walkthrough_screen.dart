import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../app_state.dart';
import '../i18n/strings.i69n.dart' show WalkthroughStrings;
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/balsm_flower.dart';

/// First-run onboarding walkthrough — Treatment **A · Petal** from the live
/// Claude Design (`wt-treatments.jsx`, skin `petal`), picked over the
/// Watercolor and Editorial alternatives: calm, cream-surfaced, centered,
/// matching the Welcome screen's existing light aesthetic most closely.
///
/// Three narrative slides (vision → an interactive "day with Balsm" demo →
/// data ownership), swipe or tap through. Ends by handing off straight to
/// Welcome — the prototype's separate end/replay card only existed to
/// *demonstrate* that handoff in a standalone comparison harness; the real
/// app does the handoff directly, same pattern as `_UnderEighteenScreen` in
/// auth_flow.dart diverging from prototype-only chrome.
///
/// Shown once per device: [PatientAppState.go] marks `walkthroughSeen` the
/// moment this route is left, so a returning (never-signed-in) user who
/// closed the app mid-flow lands on Welcome next time, not back here.
class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key});
  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _Slide {
  const _Slide(
      {required this.accent, required this.eyebrow, required this.title, required this.body, this.demo = false});
  final Accent accent;
  final String eyebrow;
  final String title;
  final String body;
  final bool demo;
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  int _index = 0;
  int _dir = 1; // last-move direction: +1 forward, -1 back — drives slide-in offset
  double _dx = 0; // live drag offset, px — resets on release
  double? _dragStartX;

  List<_Slide> _slides(PatientAppState s) {
    final wt = s.strings.walkthrough;
    return [
      _Slide(accent: Accent.emerald, eyebrow: wt.wt_eyebrow_1, title: wt.wt_title_1, body: wt.wt_body_1),
      _Slide(accent: Accent.blue, eyebrow: wt.wt_eyebrow_2, title: wt.wt_title_2, body: wt.wt_body_2, demo: true),
      _Slide(accent: Accent.aqua, eyebrow: wt.wt_eyebrow_3, title: wt.wt_title_3, body: wt.wt_body_3),
    ];
  }

  void _finish(PatientAppState s) => s.go('welcome');

  void _next(int total, PatientAppState s) {
    if (_index >= total - 1) {
      _finish(s);
      return;
    }
    setState(() {
      _dir = 1;
      _index += 1;
    });
  }

  void _prev() {
    if (_index <= 0) return;
    setState(() {
      _dir = -1;
      _index -= 1;
    });
  }

  void _goTo(int i) {
    if (i < 0 || i == _index) return;
    setState(() {
      _dir = i > _index ? 1 : -1;
      _index = i;
    });
  }

  void _onDragStart(DragStartDetails d) => _dragStartX = d.globalPosition.dx;

  void _onDragUpdate(DragUpdateDetails d) {
    final start = _dragStartX;
    if (start == null) return;
    setState(() => _dx = d.globalPosition.dx - start);
  }

  void _onDragEnd(DragEndDetails d, bool rtl, int total, PatientAppState s) {
    final dx = _dx;
    _dragStartX = null;
    setState(() => _dx = 0);
    const threshold = 46.0;
    if (dx.abs() < threshold) return;
    // Dragged toward the leading edge → forward (mirrored under RTL, same as
    // the design's `useWtSwipe`).
    var forward = dx < 0;
    if (rtl) forward = !forward;
    if (forward) {
      _next(total, s);
    } else {
      _prev();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final slides = _slides(s);
    final total = slides.length;
    final slide = slides[_index];
    final wt = s.strings.walkthrough;
    final rtl = s.rtl;

    return DecoratedBox(
      decoration: const BoxDecoration(color: T.cream50),
      child: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          child: GestureDetector(
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: (d) => _onDragEnd(d, rtl, total, s),
            behavior: HitTestBehavior.translucent,
            child: Column(children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 5, 20, 0),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  _SkipButton(label: wt.wt_skip, onTap: () => _finish(s)),
                ]),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.base,
                  switchInCurve: Motion.easeOut,
                  switchOutCurve: Motion.easeOut,
                  // `wtSlideIn`: the incoming slide enters from ±26px (data-dir),
                  // fading in as it settles — no exit animation on the outgoing
                  // one, matching the design's key-remount (not cross-fade).
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: Offset(_dir * 0.08, 0), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => current ?? const SizedBox.shrink(),
                  child: Padding(
                    key: ValueKey(_index),
                    padding: const EdgeInsets.fromLTRB(30, 8, 30, 8),
                    child: Transform.translate(
                      offset: Offset(_dx * 0.05, 0),
                      child: _PetalSlide(slide: slide, ar: rtl, strings: wt),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                child: Column(children: [
                  _Dots(total: total, index: _index, accent: slide.accent, onGo: _goTo),
                  const SizedBox(height: 18),
                  _WtNextButton(
                    label: _index == total - 1 ? wt.wt_start : wt.wt_next,
                    accent: slide.accent,
                    ar: rtl,
                    onTap: () => _next(total, s),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Slide body — icon/aura stage or the interactive demo, then copy ───
class _PetalSlide extends StatelessWidget {
  const _PetalSlide({required this.slide, required this.ar, required this.strings});
  final _Slide slide;
  final bool ar;
  final WalkthroughStrings strings;
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (slide.demo) _WtDayDemo(accent: slide.accent, ar: ar, strings: strings) else _PetalStage(slide: slide),
      const SizedBox(height: 34),
      // `.wt-petal-copy { max-width: 332px }` constrains the whole copy
      // block, not just the body line — eyebrow and title share the cap too.
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 332),
        child: Column(children: [
          // `.eyebrow-l { text-transform: uppercase }` — a no-op on Arabic.
          Text(slide.eyebrow.toUpperCase(),
              textAlign: TextAlign.center, style: Typo.eyebrow(slide.accent.main, ar: ar)),
          const SizedBox(height: 13),
          Text(slide.title,
              textAlign: TextAlign.center,
              style: Typo.display(ar: ar).copyWith(fontSize: FS.xl2, height: 1.16, letterSpacing: -0.52)),
          const SizedBox(height: 13),
          Text(slide.body, textAlign: TextAlign.center, style: Typo.body(ar: ar)),
        ]),
      ),
    ]);
  }
}

/// Soft petal-tinted aura behind a white icon tile (`.wt-aura` + `.wt-petal-tile`).
class _PetalStage extends StatelessWidget {
  const _PetalStage({required this.slide});
  final _Slide slide;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 208,
        height: 208,
        child: Stack(alignment: Alignment.center, children: [
          // `.wt-aura { position: absolute; inset: -16px; }` on the 208px
          // stage — the aura box is 240px, overflowing the stage by design.
          OverflowBox(
            maxWidth: 240,
            maxHeight: 240,
            child: _PetalAura(color: slide.accent.main),
          ),
          Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: T.white, shape: BoxShape.circle, boxShadow: T.shadowWtTile),
            child: _slideGlyph(slide),
          ),
        ]),
      );
}

Widget _slideGlyph(_Slide slide) {
  // Vision slide (emerald) shows the five-petal brand mark at markSize=104;
  // the data-ownership slide (aqua) shows a single accent icon at size=50 —
  // both per `<WtGlyph slide={slide} size={50} markSize={104} .../>` in
  // wt-treatments.jsx's Petal skin.
  if (slide.accent == Accent.emerald) return const BalsmFlower(size: 104);
  return Icon(LucideIcons.shieldCheck, size: 50, color: slide.accent.main);
}

/// `.wt-aura` — four offset, blurred radial-gradient blobs arranged in a
/// diagonal "petal" pattern (not a single centered halo), breathing
/// 0.96→1.04 scale over 5.4s ease-in-out (`@keyframes wtBreathe`). Positions/
/// sizes/alphas below are converted from the CSS multi-background-layer
/// declaration (background-position % against a 240×240 box).
class _PetalAura extends StatefulWidget {
  const _PetalAura({required this.color});
  final Color color;
  @override
  State<_PetalAura> createState() => _PetalAuraState();
}

class _PetalAuraState extends State<_PetalAura> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2700))
    ..repeat(reverse: true);
  late final Animation<double> _scale = Tween(begin: 0.96, end: 1.04).animate(
    CurvedAnimation(parent: _c, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _blobs = [
    (dx: 0.363, dy: 0.340, size: 0.62, alpha: 0.34), // 14% 8% / 62% 62%
    (dx: 0.644, dy: 0.380, size: 0.60, alpha: 0.26), // 86% 20% / 60% 60%
    (dx: 0.643, dy: 0.660, size: 0.58, alpha: 0.22), // 84% 88% / 58% 58%
    (dx: 0.378, dy: 0.652, size: 0.62, alpha: 0.28), // 18% 90% / 62% 62%
  ];

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final blur = ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(children: [
          for (final b in _blobs)
            Positioned(
              left: 240 * b.dx - 240 * b.size / 2,
              top: 240 * b.dy - 240 * b.size / 2,
              width: 240 * b.size,
              height: 240 * b.size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [widget.color.withValues(alpha: b.alpha), widget.color.withValues(alpha: 0)],
                    stops: const [0, 0.72], // radial-gradient(closest-side, color, transparent 72%)
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
    if (reduce) return blur;
    return AnimatedBuilder(
        animation: _scale, builder: (_, child) => Transform.scale(scale: _scale.value, child: child), child: blur);
  }
}

// ── Interactive "day with Balsm" demo (shared marketing preview, non-PHI) ──
class _WtDayDemo extends StatefulWidget {
  const _WtDayDemo({required this.accent, required this.ar, required this.strings});
  final Accent accent;
  final bool ar;
  final WalkthroughStrings strings;
  @override
  State<_WtDayDemo> createState() => _WtDayDemoState();
}

class _WtDayDemoState extends State<_WtDayDemo> {
  int _tab = 0;
  int _mood = 2;
  int _pin = 0;
  bool _auto = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 3400), (_) {
      if (_auto && mounted) setState(() => _tab = (_tab + 1) % 3);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _pick(int i) {
    _auto = false;
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final wt = widget.strings;
    final tabs = [
      (LucideIcons.fileText, wt.wt_demo_record),
      (LucideIcons.activity, wt.wt_demo_checkin),
      (LucideIcons.mapPin, wt.wt_demo_nearby),
    ];
    return GestureDetector(
      // Absorb horizontal drags so tapping/scrubbing the demo never swipes
      // the walkthrough slide underneath it.
      onHorizontalDragStart: (_) {},
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 332),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
              color: T.white, borderRadius: BorderRadius.all(Radius.circular(T.rXl)), boxShadow: T.shadowWtDemo),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: T.cream100, borderRadius: BorderRadius.circular(T.rLg)),
              child: Row(children: [
                for (var i = 0; i < tabs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: _DemoTab(
                      icon: tabs[i].$1,
                      label: tabs[i].$2,
                      on: i == _tab,
                      accent: widget.accent,
                      ar: widget.ar,
                      onTap: () => _pick(i),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 10),
            // `.wt-demo-panel { min-height: 108px }` — a floor, not a fixed
            // height: the Record tab's two rows render slightly taller than
            // 108px with real font metrics, so a hard SizedBox clipped/
            // overflowed here. ConstrainedBox lets it grow instead.
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 108),
              child: AnimatedSwitcher(
                duration: Motion.base,
                child: KeyedSubtree(
                  key: ValueKey(_tab),
                  child: switch (_tab) {
                    0 => _DemoRecords(accent: widget.accent, ar: widget.ar, strings: wt),
                    1 => _DemoCheckin(
                        accent: widget.accent,
                        mood: _mood,
                        strings: wt,
                        onMood: (i) => setState(() {
                              _auto = false;
                              _mood = i;
                            })),
                    _ => _DemoMap(
                        accent: widget.accent,
                        pin: _pin,
                        ar: widget.ar,
                        strings: wt,
                        onPin: (i) => setState(() {
                              _auto = false;
                              _pin = i;
                            })),
                  },
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DemoTab extends StatelessWidget {
  const _DemoTab(
      {required this.icon,
      required this.label,
      required this.on,
      required this.accent,
      required this.ar,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool on;
  final Accent accent;
  final bool ar;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.easeOut,
          height: 32,
          decoration: BoxDecoration(
            color: on ? T.white : Colors.transparent,
            borderRadius: BorderRadius.circular(T.rLg - 3),
            boxShadow: on ? T.shadowWtTabOn : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: on ? accent.main : T.fg3),
            const SizedBox(width: 5),
            Text(label,
                style: Typo.body(ar: ar)
                    .copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: on ? accent.main : T.fg3)),
          ]),
        ),
      );
}

/// Record tab — two non-PHI marketing preview rows (matches the design's mock
/// `WT_DAY_RECORDS`; never real patient data, shown before any account exists).
class _DemoRecords extends StatelessWidget {
  const _DemoRecords({required this.accent, required this.ar, required this.strings});
  final Accent accent;
  final bool ar;
  final WalkthroughStrings strings;
  @override
  Widget build(BuildContext context) {
    final rows = [
      (LucideIcons.flaskConical, strings.wt_demo_rec1_t, strings.wt_demo_rec1_d),
      (LucideIcons.fileText, strings.wt_demo_rec2_t, strings.wt_demo_rec2_d),
    ];
    return Column(children: [
      for (final (i, r) in rows.indexed)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(color: T.cream100, borderRadius: BorderRadius.circular(T.rMd)),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: accent.bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(r.$1, size: 15, color: accent.main),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.$2,
                      style: Typo.body(ar: ar)
                          .copyWith(fontSize: 12.5, fontWeight: FontWeight.w600, color: T.fg1, height: 1.2)),
                  const SizedBox(height: 1),
                  Text(r.$3, style: Typo.body(ar: ar).copyWith(fontSize: 11, color: T.fg4, height: 1.2)),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Check-in tab — a tiny trend sparkline (decorative, not real vitals) + the
/// four mood buttons from the real daily check-in flow's vocabulary.
class _DemoCheckin extends StatelessWidget {
  const _DemoCheckin({required this.accent, required this.mood, required this.strings, required this.onMood});
  final Accent accent;
  final int mood;
  final WalkthroughStrings strings;
  final ValueChanged<int> onMood;
  @override
  Widget build(BuildContext context) {
    final moods = [
      (LucideIcons.frown, strings.wt_demo_mood_low),
      (LucideIcons.meh, strings.wt_demo_mood_okay),
      (LucideIcons.smile, strings.wt_demo_mood_good),
      (LucideIcons.laugh, strings.wt_demo_mood_great),
    ];
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
            height: 52, // <svg className="wt-demo-chart" ... height="52">
            width: double.infinity,
            child: CustomPaint(painter: _SparklinePainter(color: accent.main)),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < moods.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _MoodButton(icon: moods[i].$1, label: moods[i].$2, on: i == mood, accent: accent, onTap: () => onMood(i)),
            ],
          ]),
        ]));
  }
}

class _MoodButton extends StatelessWidget {
  const _MoodButton(
      {required this.icon, required this.label, required this.on, required this.accent, required this.onTap});
  final IconData icon;
  final String label;
  final bool on;
  final Accent accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AnimatedScale(
        // `.wt-demo-mood.on { transform: scale(1.08) }` — selected-state
        // grow, layered under Pressable's own press-scale.
        scale: on ? 1.08 : 1.0,
        duration: Motion.base,
        curve: Motion.easeOut,
        child: Pressable(
          onTap: onTap,
          scale: 0.94,
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.easeOut,
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? accent.bg : T.white,
              border: Border.all(color: on ? accent.main : T.ink100, width: 1.5),
            ),
            child: Icon(icon, size: 18, color: on ? accent.main : T.fg4, semanticLabel: label),
          ),
        ),
      );
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    // Same 6-point shape as the design's `.wt-demo-chart polyline`, scaled to
    // this box's size (source viewBox 200×60).
    const pts = [
      Offset(6, 46),
      Offset(42, 36),
      Offset(78, 40),
      Offset(114, 20),
      Offset(150, 26),
      Offset(194, 10),
    ];
    final sx = size.width / 200, sy = size.height / 60;
    final path = Path()..moveTo(pts.first.dx * sx, pts.first.dy * sy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx * sx, p.dy * sy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.color != color;
}

/// Nearby tab — three tappable pins over a flat map-tint background
/// (decorative positions, matches the design's mock `WT_DAY_PINS`).
class _DemoMap extends StatelessWidget {
  const _DemoMap(
      {required this.accent, required this.pin, required this.ar, required this.strings, required this.onPin});
  final Accent accent;
  final int pin;
  final bool ar;
  final WalkthroughStrings strings;
  final ValueChanged<int> onPin;
  @override
  Widget build(BuildContext context) {
    final pins = [
      (0.20, 0.66, strings.wt_demo_pin1),
      (0.56, 0.30, strings.wt_demo_pin2),
      (0.82, 0.62, strings.wt_demo_pin3),
    ];
    // `.wt-demo-map { height: 108px }` — fixed, unlike the panel's own
    // min-height: pin positions are percentages of this box, so it can't be
    // allowed to inherit an unbounded height from the now-flexible parent.
    return SizedBox(
      height: 108,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(T.rMd),
        child: Container(
          color: T.cream100,
          child: LayoutBuilder(builder: (context, c) {
            return Stack(children: [
              for (var i = 0; i < pins.length; i++)
                Positioned(
                  left: pins[i].$1 * c.maxWidth - 10,
                  top: pins[i].$2 * c.maxHeight - 20,
                  child: Pressable(
                    onTap: () => onPin(i),
                    scale: 0.9,
                    child: Icon(LucideIcons.mapPin, size: i == pin ? 20 : 16, color: i == pin ? accent.main : T.fg4),
                  ),
                ),
              PositionedDirectional(
                bottom: 8,
                start: 8,
                end: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: T.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(T.rPill)),
                  child: Text(pins[pin].$3,
                      textAlign: TextAlign.center,
                      style: Typo.body(ar: ar).copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: T.fg2)),
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

// ── Chrome: skip button, dots, next/get-started CTA ────────────────────
class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        // `.wt-skip { padding: 8px 8px; min-height: 40px; border-radius: pill }`
        // — the 40pt floor is what makes it a comfortable target.
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Text(label, style: Typo.bodySm().copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
        ),
      );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.total, required this.index, required this.accent, required this.onGo});
  final int total;
  final int index;
  final Accent accent;
  final ValueChanged<int> onGo;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onGo(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                // `.wt-dot { transition: width 0.3s var(--ease-out), ... }`
                // — an explicit 300ms, not the --dur-base (200ms) token.
                duration: const Duration(milliseconds: 300),
                curve: Motion.easeOut,
                width: i == index ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                    color: i == index ? accent.main : T.ink200, borderRadius: BorderRadius.circular(T.rPill)),
              ),
            ),
          ),
      ]);
}

/// `.wt-next` — same visual weight as the shared `PButton` primary/large
/// variant, kept as a small local widget only because this CTA needs a
/// *trailing* arrow (`PButton`'s optional icon renders leading).
///
/// Fill is the **app** accent, not the slide's petal: `.b-btn-primary` paints
/// `--balsm-primary`, which app.jsx binds once at the root to the accent tweak.
/// The walkthrough's per-slide `accentVars` rebind only `--app-accent*`, so the
/// slide petal reaches the box-shadow (`.b-btn-primary { box-shadow:
/// var(--app-accent-shadow) }`) and nothing else.
class _WtNextButton extends StatelessWidget {
  const _WtNextButton({required this.label, required this.accent, required this.ar, required this.onTap});
  final String label;

  /// The slide's petal — drives the glow only.
  final Accent accent;
  final bool ar;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          height: 56,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppScope.of(context).accent.main,
              borderRadius: BorderRadius.circular(T.rLg),
              boxShadow: accent.boxShadow),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label,
                style: Typo.body(ar: ar).copyWith(fontSize: FS.lg, fontWeight: FontWeight.w600, color: T.white)),
            const SizedBox(width: 9),
            Transform.flip(flipX: ar, child: const Icon(LucideIcons.arrowRight, size: 19, color: T.white)),
          ]),
        ),
      );
}
