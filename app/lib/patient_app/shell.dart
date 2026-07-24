import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'app_state.dart';
import 'kit.dart';
import 'responsive.dart';
import 'tokens.dart';
import 'widgets/balsm_flower.dart';
import 'screens/home_screen.dart';
import 'screens/meds_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth_flow.dart';
import 'dev/shake_to_dev_config.dart';

/// Root of the patient app prototype. Owns [PatientAppState] and renders the
/// auth flow or the main tabbed app depending on `route`.
class PatientApp extends StatefulWidget {
  const PatientApp({super.key, required this.state, required this.navObserver});

  /// Pre-loaded state (persisted session + prefs). See [PatientAppState.load].
  final PatientAppState state;

  /// Logs a `screen_view` analytics action on each navigation.
  final NavigatorObserver navObserver;

  @override
  State<PatientApp> createState() => _PatientAppState();
}

class _PatientAppState extends State<PatientApp> {
  late final PatientAppState state = widget.state;
  final _navKey = GlobalKey<NavigatorState>();

  // Boot splash (app.jsx `DSLoadingOverlay open={booting}`) — branded petal
  // spinner shown for ~1.7s on cold start, then fades out.
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _booting = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: _navKey,
          navigatorObservers: [widget.navObserver],
          // G2: wire Flutter's Material/Cupertino/widget localizations so date
          // pickers, semantics and default tooltips localize. The app's own
          // string system (i69n `tr()`) is unchanged; these delegates only
          // cover framework-provided widgets.
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Four first-class locales (FR-207): English + the three Arabic
          // regions. `state.lang` only tracks the base language (no region),
          // so an 'ar' locale resolves to the first supported Arabic entry
          // (ar-EG) for framework localization; all render Arabic. RTL stays
          // driven by the manual Directionality below.
          supportedLocales: const [
            Locale('en'),
            Locale('ar', 'EG'),
            Locale('ar', 'SA'),
            Locale('ar', 'AE'),
          ],
          locale: Locale(state.lang.value),
          theme: ThemeData(scaffoldBackgroundColor: Colors.white, useMaterial3: true),
          // Clamp Dynamic Type so large system text never breaks layouts.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
              ),
              // Shake anywhere → Dev Config (read-only in prod).
              child: ShakeToDevConfig(navigatorKey: _navKey, child: child!),
            );
          },
          home: Directionality(
            textDirection: state.dir,
            child: AdaptiveFrame(
              child: Scaffold(
                backgroundColor: Colors.white,
                body: Stack(children: [
                  state.route == 'app' ? const _MainApp() : const AuthRouter(),
                  Positioned.fill(child: _BootSplash(state: state, visible: _booting)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Caps the app on very wide screens so a touch-first layout never stretches
/// edge-to-edge on desktop/web. Below [_maxW] the app fills the window and the
/// internal layout (bottom nav ↔ side rail, adaptive panes) handles every size.
class AdaptiveFrame extends StatelessWidget {
  const AdaptiveFrame({super.key, required this.child});
  final Widget child;

  static const _maxW = Bp.xl; // 1280

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth <= _maxW) return child;
      return ColoredBox(
        color: const Color(0xFFF1EFE7),
        child: Center(
          child: SizedBox(
            width: _maxW,
            child: ColoredBox(color: Colors.white, child: child),
          ),
        ),
      );
    });
  }
}

/// Main signed-in app. Adapts navigation to the window: phones (< md) use the
/// bottom tab bar; tablets/desktop (≥ md) use a persistent leading nav rail
/// (Material adaptive-navigation: sidebar on large, bottom nav on small).
class _MainApp extends StatefulWidget {
  const _MainApp();
  @override
  State<_MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<_MainApp> {
  String? _lastTab;
  bool _navLoading = false;
  Timer? _navTimer;

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }

  // app.jsx: on tab change, navLoading is true for ~520ms → top loading bar.
  void _flashNav() {
    _navTimer?.cancel();
    if (!_navLoading) setState(() => _navLoading = true);
    _navTimer = Timer(const Duration(milliseconds: 520), () {
      if (mounted) setState(() => _navLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (_lastTab == null) {
      _lastTab = s.tab;
    } else if (_lastTab != s.tab) {
      _lastTab = s.tab;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _flashNav(); });
    }

    // P001 patient-MVP slice ships only the home / medications / profile tabs.
    // Later-phase screens (trends, map, records, appointments, prescriptions,
    // quick-log / self-report) are gated out of navigation; any stale tab id
    // resolves to the "coming next" placeholder rather than crashing.
    final screen = switch (s.tab) {
      'home' => const HomeScreen(),
      'meds' => const MedsScreen(),
      'profile' => const ProfileScreen(),
      _ => _Placeholder(title: s.tab),
    };

    final content = LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= Bp.md;
      if (wide) {
        // Persistent side rail + content. Sub-screens render in-place; the rail
        // stays reachable (persistent-nav).
        return Row(children: [
          const _SideNav(),
          Expanded(child: screen),
        ]);
      }
      // Phone: full-bleed screen + bottom tab bar.
      return Column(children: [
        Expanded(child: screen),
        const _TabBar(),
      ]);
    });

    return Stack(children: [
      content,
      PositionedDirectional(
        top: 0, start: 0, end: 0,
        child: TopLoadingBar(loading: _navLoading, color: s.accent.main),
      ),
    ]);
  }
}

// ── Phone bottom tab bar ─────────────────────────────────────
class _TabBar extends StatelessWidget {
  const _TabBar();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xEBFFFFFF),
        border: Border(top: BorderSide(color: T.border)),
      ),
      padding: EdgeInsets.only(bottom: 22 + MediaQuery.of(context).padding.bottom.clamp(0, 12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Tab(id: 'home', icon: LucideIcons.home, label: s.strings.tab_home),
        _Tab(id: 'meds', icon: LucideIcons.pill, label: s.strings.tab_meds),
        _Tab(id: 'profile', icon: LucideIcons.user, label: s.strings.tab_profile),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.id, required this.icon, required this.label});
  final String id;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final active = s.tab == id;
    final color = active ? s.accent.main : T.fg4;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => s.setTab(id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(label, style: Typo.body(ar: s.rtl).copyWith(
                fontSize: FS.xs2, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}

// ── Tablet / desktop side rail ───────────────────────────────
class _SideNav extends StatelessWidget {
  const _SideNav();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      width: 96,
      decoration: const BoxDecoration(
        color: Color(0xEBFFFFFF),
        border: BorderDirectional(end: BorderSide(color: T.border)),
      ),
      child: SafeArea(
        child: Column(children: [
          const SizedBox(height: Space.s5),
          _RailItem(id: 'home', icon: LucideIcons.home, label: s.strings.tab_home),
          _RailItem(id: 'meds', icon: LucideIcons.pill, label: s.strings.tab_meds),
          _RailItem(id: 'profile', icon: LucideIcons.user, label: s.strings.tab_profile),
          const Spacer(),
        ]),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.id, required this.icon, required this.label});
  final String id;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final active = s.tab == id;
    final color = active ? s.accent.main : T.fg4;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => s.setTab(id),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: Space.s1, horizontal: Space.s2),
        padding: const EdgeInsets.symmetric(vertical: Space.s2),
        decoration: BoxDecoration(
          color: active ? s.accent.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(T.rMd),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(label, style: Typo.body(ar: s.rtl).copyWith(
              fontSize: FS.xs2, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Center(
      child: Text('${title[0].toUpperCase()}${title.substring(1)}\n(coming next)',
          textAlign: TextAlign.center, style: Typo.subhead(ar: s.rtl).copyWith(color: T.fg3)),
    );
  }
}

/// Branded boot splash (`DSLoadingOverlay variant="brand" spinner="petal"`):
/// petal spinner + "Preparing your health record" over the warm cream surface.
/// Fades out over `--dur-slow` when [visible] flips false.
class _BootSplash extends StatelessWidget {
  const _BootSplash({required this.state, required this.visible});
  final PatientAppState state;
  final bool visible;
  @override
  Widget build(BuildContext context) {
    final ar = state.rtl;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Motion.slow,
        curve: Motion.easeOut,
        child: Container(
          color: T.cream50,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const PetalSpinner(size: 72),
            const SizedBox(height: 28),
            Text(state.strings.boot_preparing,
                textAlign: TextAlign.center,
                style: Typo.subhead(ar: ar).copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(state.strings.boot_tagline,
                textAlign: TextAlign.center, style: Typo.meta(ar: ar)),
          ]),
        ),
      ),
    );
  }
}
