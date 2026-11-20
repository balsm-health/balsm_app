import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../kit.dart';
import '../screens/own_card_screen.dart';
import '../tokens.dart';
import '../widgets/balsm_mark.dart';
import 'maintenance_controller.dart';

// The full-screen page keeps the earlier amber (maintenance.jsx MaintScreen);
// the card above the tab bar and the details sheet use the `T.maint*` palette.
const _amber = Color(0xFF9A6E00);
const _pageTop = Color(0xFFFDF8E8);

/// How often the countdown is redrawn (design `useMaintClock`).
const _tick = Duration(seconds: 30);

/// The progress bar never draws empty, so the bar reads as a bar
/// (`useMaintClock`: pct clamped to 0.04–1).
const _minProgress = 0.04;

/// The details sheet's height cap, a share of the screen (`maxHeight: 90%`).
const _sheetMaxHeight = 0.9;

/// The floating card's blinking dot (`mtBlink 1.8s`) and the sheet badge's
/// pulse (`mtPulse 2.4s`).
const _blinkPeriod = Duration(milliseconds: 1800);
const _pulsePeriod = Duration(milliseconds: 2400);

/// "Until about 2:00 PM", "… tomorrow", or "We'll share the end time soon"
/// when no end is announced or the announced one has already passed.
String maintenanceEndText(BuildContext context, PatientAppState s, DateTime? endsAt, DateTime now) {
  final m = s.strings.maintenance;
  if (endsAt == null || !endsAt.isAfter(now)) return m.end_unknown;
  final local = endsAt.toLocal();
  final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local));
  final today = now.toLocal();
  final sameDay = local.year == today.year && local.month == today.month && local.day == today.day;
  return sameDay ? m.until(time) : m.until_tomorrow(time);
}

/// "Back in about 1 h 45 min" (design `maintLeftText`), rounded to the
/// minute and never below one; "Duration not announced yet" when no end is
/// announced or the announced one has passed.
String maintenanceLeftText(PatientAppState s, DateTime? endsAt, DateTime now) {
  final m = s.strings.maintenance;
  if (endsAt == null || !endsAt.isAfter(now)) return m.left_unknown;
  final mins = (endsAt.difference(now).inSeconds / 60).round().clamp(1, 1 << 30);
  final (h, r) = (mins ~/ 60, mins % 60);
  if (h == 0) return m.left_m(mins);
  return r == 0 ? m.left_h(h) : m.left_hm(h, r);
}

/// How far through the window [now] is, 0.04–1 (design `useMaintClock`), or
/// null when there is no end to count towards. Without a start the bar
/// starts at its minimum.
double? maintenanceProgress(MaintenanceStatus status, DateTime now) {
  final end = status.endsAt;
  if (end == null || !end.isAfter(now)) return null;
  final start = status.startsAt ?? now;
  final total = end.difference(start).inMilliseconds;
  if (total <= 0) return _minProgress;
  final left = end.difference(now).inMilliseconds;
  return (1 - left / total).clamp(_minProgress, 1.0);
}

/// Rebuilds [builder] every [_tick] with the clock's "now", so the countdown
/// moves while it is on screen.
class _Ticking extends ConsumerStatefulWidget {
  const _Ticking({required this.builder});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  ConsumerState<_Ticking> createState() => _TickingState();
}

class _TickingState extends ConsumerState<_Ticking> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, ref.watch(maintenanceClockProvider)());
}

/// Repeats [builder]'s animation (0→1→0 over [period]) unless the platform
/// asks for reduced motion, when it holds at 0.
class _Breathing extends StatefulWidget {
  const _Breathing({required this.period, required this.builder});

  final Duration period;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period ~/ 2);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c
        ..stop()
        ..value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => widget.builder(context, Curves.easeInOut.transform(_c.value)),
      );
}

/// A thin progress bar: [value] of the width, from the inline start.
class _Progress extends StatelessWidget {
  const _Progress({required this.value, required this.height, this.track, this.fill, this.gradient});

  final double value;
  final double height;
  final Color? track;
  final Color? fill;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(T.rPill)),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: value,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: fill, gradient: gradient, borderRadius: BorderRadius.circular(T.rPill)),
            ),
          ),
        ),
      );
}

/// Opens the maintenance sheet: the card's details, or — with [paused] —
/// "Adding and editing are paused for now" after a paused action was tapped.
Future<void> showMaintenanceSheet(BuildContext context, {required bool paused}) {
  final s = AppScope.of(context);
  return showAppSheet<void>(
    context,
    useRootNavigator: true,
    textDirection: s.dir,
    builder: (_) => MaintenanceSheet(s: s, paused: paused),
  );
}

/// The details sheet (design `MaintSheet`): an amber hero with the countdown,
/// the admin message in its own card, what still works (and, unless
/// [paused], what is paused), a reassurance line, "Got it" and the patient's
/// own emergency card.
class MaintenanceSheet extends ConsumerWidget {
  const MaintenanceSheet({super.key, required this.s, required this.paused});

  final PatientAppState s;
  final bool paused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = s.strings.maintenance;
    final status = ref.watch(maintenanceProvider);
    const top = Radius.circular(24);
    // `maxHeight: 90%`: the sheet scrolls rather than rising under the
    // status bar.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * _sheetMaxHeight),
      child: Material(
        color: T.surface,
        borderRadius: const BorderRadius.vertical(top: top),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              // ── hero ──
              Container(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 18),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: top),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [T.maintBg2, T.maintBg, T.surface],
                    stops: [0, 0.6, 1],
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SheetGrab(),
                  const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _HeroTile(paused: paused),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.rtl ? m.sheet_eyebrow : m.sheet_eyebrow.toUpperCase(),
                            style: Typo.eyebrow(T.maintInk2, ar: s.rtl)
                                .copyWith(fontSize: FS.xs, letterSpacing: s.rtl ? 0 : 1.44)),
                        const SizedBox(height: 2),
                        Semantics(
                          header: true,
                          child: Text(paused ? m.paused_title : m.ro_title,
                              style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -4),
                      child: RoundBtn(
                        icon: LucideIcons.x,
                        iconSize: 17,
                        ghost: true,
                        semanticLabel: m.close,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(paused ? m.paused_body(s.gender) : m.ro_body,
                      style: Typo.bodySm(ar: s.rtl).copyWith(height: 1.55)),
                  const SizedBox(height: 14),
                  MaintenanceCountdown(s: s),
                ]),
              ),
              // ── body ──
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 26),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (status.message case final message?) ...[
                    const SizedBox(height: 14),
                    _MessageCard(s: s, message: message),
                  ],
                  MaintenanceLists(s: s, compact: paused),
                  const SizedBox(height: 14),
                  Row(children: [
                    const Icon(LucideIcons.shieldCheck, size: 14, color: T.hueMint600),
                    const SizedBox(width: 6),
                    Expanded(child: Text(m.data_safe, style: Typo.meta(ar: s.rtl))),
                  ]),
                  const SizedBox(height: 18),
                  PButton(m.got_it, block: true, large: true, ar: s.rtl, onTap: () => Navigator.of(context).pop()),
                  const SizedBox(height: 10),
                  // Over the sheet, so back returns here (design: the card
                  // replaces the sheet until it is closed).
                  PButton(m.open_card,
                      icon: LucideIcons.idCard,
                      variant: BtnVariant.ghost,
                      size: BtnSize.md,
                      block: true,
                      ar: s.rtl,
                      onTap: () => openOwnCard(context)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The sheet's 56px white tile — a wrench, or pencil-off when an action was
/// paused — with the pulsing amber badge at its top inline-end corner.
class _HeroTile extends StatelessWidget {
  const _HeroTile({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          width: 56,
          height: 56,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: T.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: T.maintTileShadow,
                ),
                child: Icon(paused ? LucideIcons.pencilOff : LucideIcons.wrench, size: 26, color: T.maintInk2),
              ),
            ),
            PositionedDirectional(
              top: -4,
              end: -4,
              child: _Breathing(
                period: _pulsePeriod,
                builder: (context, t) => Opacity(
                  opacity: 0.9 + 0.1 * t,
                  child: Transform.scale(
                    scale: 1 + 0.08 * t,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: T.maintDot,
                        shape: BoxShape.circle,
                        border: Border.all(color: T.surface, width: 2),
                      ),
                      child: const Icon(LucideIcons.eye, size: 11, color: T.surface),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// The direction of [text]'s first strong letter (HTML `dir="auto"`), or
/// [fallback] when it has none.
TextDirection _directionOf(String text, TextDirection fallback) {
  final strong = RegExp(r'[A-Za-z\u00C0-\u024F\u0370-\u03FF\u0400-\u04FF]|[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]')
      .firstMatch(text)
      ?.group(0);
  if (strong == null) return fallback;
  return RegExp(r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]').hasMatch(strong) ? TextDirection.rtl : TextDirection.ltr;
}

/// "Message from the Balsm team": the admin's free text, in its own card.
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.s, required this.message});

  final PatientAppState s;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rLg)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsetsDirectional.only(top: 2),
            child: Icon(LucideIcons.megaphone, size: 17, color: T.fg2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.strings.maintenance.message_title,
                  style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              // `dir="auto"`: the admin writes one text for every language,
              // so it runs in its own direction, not the app's.
              Text(message,
                  textDirection: _directionOf(message, s.dir), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg1)),
            ]),
          ),
        ]),
      );
}

/// The countdown block (design `MaintCountdown`): "Back in about …", the end
/// time, and how far through the window we are.
class MaintenanceCountdown extends ConsumerWidget {
  const MaintenanceCountdown({super.key, required this.s});

  final PatientAppState s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = s.strings.maintenance;
    final status = ref.watch(maintenanceProvider);
    return _Ticking(builder: (context, now) {
      final pct = maintenanceProgress(status, now);
      return Container(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(T.rLg),
          border: Border.all(color: T.maintLine),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.clock, size: 15, color: T.maintInk2),
                const SizedBox(width: 6),
                Text(maintenanceLeftText(s, status.endsAt, now),
                    style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
              ]),
              Text(maintenanceEndText(context, s, status.endsAt, now), style: Typo.meta(ar: s.rtl)),
            ],
          ),
          if (pct != null) ...[
            const SizedBox(height: 8),
            Semantics(
              label: m.progress_label,
              value: '${(pct * 100).round()}%',
              child: _Progress(
                value: pct,
                height: 6,
                track: T.maintBg2,
                gradient: const LinearGradient(colors: [T.maintDot, T.maintDotLight]),
              ),
            ),
          ],
        ]),
      );
    });
  }
}

/// What still works and — unless [compact] — what is paused: two tinted
/// cards with an icon tile per item (design `MaintLists`).
class MaintenanceLists extends StatelessWidget {
  const MaintenanceLists({super.key, required this.s, this.compact = false});

  final PatientAppState s;

  /// Only "Still available" (the paused sheet).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final m = s.strings.maintenance;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 10, children: [
        _ListCard(
          s: s,
          title: m.still_available,
          titleIcon: LucideIcons.circleCheck,
          // The design's mint-600 ink measures about 2:1 on the mint wash, too
          // faint for 12px text; the title takes the darker mint ink.
          titleInk: T.hueMintInk,
          iconInk: T.hueMint600,
          bg: T.hueMint50,
          line: T.hueMint.withValues(alpha: 0.28),
          items: [
            (LucideIcons.eye, m.ok_view),
            (LucideIcons.idCard, m.ok_card),
            (LucideIcons.bellRing, m.ok_reminders),
          ],
        ),
        if (!compact)
          _ListCard(
            s: s,
            title: m.paused_for_now,
            titleIcon: LucideIcons.circlePause,
            titleInk: T.maintInk2,
            iconInk: T.maintInk2,
            bg: T.maintBg,
            line: T.maintLine,
            items: [
              (LucideIcons.pencilOff, m.paused_log),
              (LucideIcons.refreshCwOff, m.paused_sync),
              (LucideIcons.logIn, m.paused_signin),
            ],
          ),
      ]),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.s,
    required this.title,
    required this.titleIcon,
    required this.titleInk,
    required this.iconInk,
    required this.bg,
    required this.line,
    required this.items,
  });

  final PatientAppState s;
  final String title;
  final IconData titleIcon;
  final Color titleInk;
  final Color iconInk;
  final Color bg;
  final Color line;
  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            header: true,
            child: Row(children: [
              Icon(titleIcon, size: 14, color: titleInk),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: titleInk)),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          ...items.map((e) => Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 7),
                child: Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(9)),
                    child: Icon(e.$1, size: 15, color: iconInk),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.$2, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg1, height: 1.4)),
                  ),
                ]),
              )),
        ]),
      );
}

/// The floating card above the tab bar while maintenance is read-only
/// (design `MaintStrip`): a wrench tile with a blinking dot, the countdown,
/// "Details ›", and a thin bar along the bottom for how far through the
/// window we are.
class MaintenanceStrip extends ConsumerWidget {
  const MaintenanceStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(maintenanceProvider);
    if (status.mode != MaintenanceMode.readonly) return const SizedBox.shrink();
    final s = AppScope.of(context);
    final m = s.strings.maintenance;
    const radius = BorderRadius.all(Radius.circular(16));
    void open() => showMaintenanceSheet(context, paused: false);
    return _Ticking(builder: (context, now) {
      final left = maintenanceLeftText(s, status.endsAt, now);
      final pct = maintenanceProgress(status, now);
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 8),
        child: Semantics(
          button: true,
          label: m.strip_a11y(left),
          onTap: open,
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: const BoxDecoration(borderRadius: radius, boxShadow: T.maintCardShadow),
            child: Material(
              type: MaterialType.transparency,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: T.maintLine),
                  gradient: const LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [T.maintBg, T.maintBg2],
                  ),
                ),
                child: InkWell(
                  onTap: open,
                  borderRadius: radius,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 10),
                        child: Row(children: [
                          const _StripTile(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(m.strip_title,
                                  style: Typo.bodySm(ar: s.rtl)
                                      .copyWith(fontWeight: FontWeight.w700, color: T.maintInk, height: 1.3)),
                              Text(left,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Typo.meta(ar: s.rtl).copyWith(color: T.maintInk.withValues(alpha: 0.85))),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Text(m.strip_details,
                              style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.maintInk)),
                          const SizedBox(width: 2),
                          Transform.flip(
                            flipX: s.rtl,
                            child: const Icon(LucideIcons.chevronRight, size: 15, color: T.maintInk),
                          ),
                        ]),
                      ),
                      if (pct != null)
                        PositionedDirectional(
                          start: 0,
                          end: 0,
                          bottom: 0,
                          child: Opacity(
                            opacity: 0.7,
                            child: _Progress(value: pct, height: 3, fill: T.maintDot),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// The card's 36px white tile: a wrench with the blinking amber dot.
class _StripTile extends StatelessWidget {
  const _StripTile();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 36,
        height: 36,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: T.surface, borderRadius: BorderRadius.circular(12)),
              child: const Icon(LucideIcons.wrench, size: 17, color: T.maintInk2),
            ),
          ),
          PositionedDirectional(
            top: -2,
            end: -2,
            child: _Breathing(
              period: _blinkPeriod,
              builder: (context, t) => Opacity(
                opacity: 1 - 0.65 * t,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: T.maintDot,
                    shape: BoxShape.circle,
                    border: Border.all(color: T.surface, width: 2),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
}

/// Full-screen page: a full block (signed in or not), or read-only before
/// sign-in. Only the emergency card ([signedIn]) and the country emergency
/// number stay reachable; [onDeviceOnly] offers "Use on this device only"
/// before sign-in while read-only.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key, required this.signedIn, this.onDeviceOnly});

  final bool signedIn;
  final VoidCallback? onDeviceOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final m = s.strings.maintenance;
    final status = ref.watch(maintenanceProvider);
    final now = ref.watch(maintenanceClockProvider)();
    final block = status.blocks;
    final number = s.country.emergencyNumber;
    final body = status.message ?? (signedIn || block ? (block ? m.block_body : m.ro_body) : m.pre_body);

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_pageTop, T.surface],
            stops: [0, 0.55],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(28, 48, 28, 12),
                        child: Column(children: [
                          const _MarkWithWrench(),
                          const SizedBox(height: 18),
                          Text(m.eyebrow.toUpperCase(), style: Typo.eyebrow(T.maintInk2, ar: s.rtl)),
                          const SizedBox(height: 12),
                          Semantics(
                            header: true,
                            child: Text(block ? m.block_title : m.ro_title,
                                textAlign: TextAlign.center, style: Typo.heading(ar: s.rtl)),
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Text(body, textAlign: TextAlign.center, style: Typo.bodySm(ar: s.rtl)),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: T.surface,
                              borderRadius: BorderRadius.circular(T.rPill),
                              border: Border.all(color: T.ink100),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(LucideIcons.clock, size: 15, color: T.fg3),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(maintenanceEndText(context, s, status.endsAt, now),
                                    style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 28),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (signedIn) ...[
                            PButton(m.open_card,
                                icon: LucideIcons.idCard,
                                block: true,
                                large: true,
                                ar: s.rtl,
                                onTap: () => openOwnCard(context)),
                            const SizedBox(height: 10),
                          ],
                          if (!signedIn && !block && onDeviceOnly != null) ...[
                            PButton(m.device_only,
                                icon: LucideIcons.smartphone, block: true, large: true, ar: s.rtl, onTap: onDeviceOnly),
                            const SizedBox(height: 10),
                          ],
                          if (number.isNotEmpty) ...[
                            PButton(m.call_emergency(number, s.gender),
                                icon: LucideIcons.phone,
                                variant: BtnVariant.secondary,
                                color: T.danger,
                                block: true,
                                large: true,
                                ar: s.rtl,
                                onTap: () => launchUrl(Uri(scheme: 'tel', path: number))),
                            const SizedBox(height: 10),
                          ],
                          PButton(status.checking ? m.checking : m.check_again(s.gender),
                              icon: LucideIcons.rotateCw,
                              variant: BtnVariant.ghost,
                              block: true,
                              ar: s.rtl,
                              onTap: status.checking ? null : () => ref.read(maintenanceProvider.notifier).check()),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Balsm mark with the amber wrench badge at its inline-end foot.
class _MarkWithWrench extends StatelessWidget {
  const _MarkWithWrench();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(clipBehavior: Clip.none, children: [
        const Positioned.fill(child: Opacity(opacity: 0.9, child: BalsmFlower(size: 88))),
        PositionedDirectional(
          end: -6,
          bottom: -4,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: T.warningBg,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(LucideIcons.wrench, size: 17, color: _amber),
          ),
        ),
      ]),
    );
  }
}

/// The quick-log button's wrapper (design `AppNav`): its screen-reader
/// label, and — while maintenance is read-only — a washed-out look
/// (`saturate(0.35)`, 75% opacity), a small amber lock badge at the top
/// inline-end corner and "Adding is paused during maintenance". Tapping still
/// reaches the guard, which shows the paused sheet. The badge stays full
/// colour so it reads as a lock.
class MaintenanceFabLock extends ConsumerWidget {
  const MaintenanceFabLock({super.key, required this.label, required this.onTap, required this.child});

  /// What the button says outside read-only maintenance.
  final String label;
  final VoidCallback onTap;
  final Widget child;

  /// CSS `saturate()` as a colour matrix.
  static List<double> _saturate(double s) => [
        0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
        0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
        0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
        0, 0, 0, 1, 0,
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = ref.watch(maintenanceProvider.select((m) => m.mode == MaintenanceMode.readonly));
    return Semantics(
      button: true,
      label: paused ? AppScope.of(context).strings.maintenance.fab_paused : label,
      onTap: onTap,
      excludeSemantics: true,
      child: paused ? _locked() : child,
    );
  }

  Widget _locked() {
    return Stack(clipBehavior: Clip.none, children: [
      Opacity(opacity: 0.75, child: ColorFiltered(colorFilter: ColorFilter.matrix(_saturate(0.35)), child: child)),
      PositionedDirectional(
        top: -2,
        end: -2,
        child: Container(
          key: const ValueKey('maintenance-fab-lock'),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: T.maintDot,
            shape: BoxShape.circle,
            border: Border.all(color: T.surface, width: 2),
          ),
          child: const Icon(LucideIcons.lock, size: 10, color: T.surface),
        ),
      ),
    ]);
  }
}
