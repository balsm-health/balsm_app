import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:core/core.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'app_state.dart';
import 'routes.dart';
import 'desktop_menu.dart';
import 'dev/log_buffer.dart';
import 'assets.dart';
import 'kit.dart';
import 'offline_banner.dart';
import 'responsive.dart';
import 'tokens.dart';
import 'widgets/splash_bloom.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/meds_screen.dart';
import 'screens/prescriptions_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/records_screen.dart';
import 'screens/trends_screen.dart';
import 'screens/quick_log.dart';
import 'screens/auth_flow.dart';
import 'screens/personal_details.dart';
import 'screens/profile_subscreens.dart';
import 'screens/ecosystem_sheet.dart';
import 'screens/feedback_sheet.dart';
import 'screens/storage_sheet.dart';
import 'screens/add_prescription_sheet.dart';
import 'screens/report_flow.dart';
import 'widgets/account_switcher.dart';
import 'deep_link_handler.dart';
import 'dev/shake_to_dev_config.dart';
import 'screens/care_team_screen.dart';

/// Root of the patient app prototype. Watches the Riverpod-owned
/// [PatientAppState] and renders the auth flow or the main tabbed app
/// depending on `route`.
/// Service-extension names already bound in this isolate.
///
/// `developer.registerExtension` throws `ArgumentError` on a duplicate, and the
/// shell's `initState` runs again whenever it remounts (sign out and back in,
/// `go('welcome')` and back) without the isolate restarting. Unguarded, that
/// throw aborts the rest of `initState` — the boot-splash timer included — and
/// surfaces as an unhandled exception, which inside a debugger session reads as
/// "the app errors on restart".
@visibleForTesting
final boundDebugExtensions = <String>{};

/// Registers [name] once per isolate; a repeat bind is a no-op.
@visibleForTesting
void registerExtensionOnce(String name, developer.ServiceExtensionHandler handler) {
  if (!boundDebugExtensions.add(name)) return;
  developer.registerExtension(name, handler);
}

class PatientApp extends ConsumerStatefulWidget {
  const PatientApp({super.key, required this.navObserver});

  /// Logs a `screen_view` analytics action on each navigation.
  final NavigatorObserver navObserver;

  @override
  ConsumerState<PatientApp> createState() => _PatientAppState();
}

class _PatientAppState extends ConsumerState<PatientApp> {
  late final PatientAppState state = ref.read(patientAppStateProvider);
  final _navKey = GlobalKey<NavigatorState>();

  /// Rasterisation root for the desktop menu's Save-screenshot action.
  final _captureKey = GlobalKey();

  void _menuOpen(void Function(BuildContext) opener) {
    final ctx = _navKey.currentContext;
    if (ctx != null && ctx.mounted) opener(ctx);
  }

  // Boot splash (auth.jsx `SplashScreen`) — mark wash + mark spinner,
  // held ~2.3s on cold start, then fades out.
  bool _booting = true;

  /// Web only: a scanned profile-QR URL (`/t/{jti}`, legacy `/emergency/{jti}`)
  /// renders the public resolve page instead of the app — no session needed,
  /// and the sessionless shell must not eject to the auth flow. The AES key
  /// stays in the URL fragment, read by the resolve screen itself.
  String? _publicResolveJti;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final segs = Uri.base.pathSegments.where((p) => p.isNotEmpty).toList();
      if (segs.length == 2 && (segs[0] == PublicQrPaths.token || segs[0] == PublicQrPaths.legacyEmergency)) {
        _publicResolveJti = segs[1];
      }
    }
    LogBuffer.instance.install();
    _bindDebugServiceExtensions();
    // `SplashScreen`: hold 2300ms, or 1200 under reduced motion — there is no
    // entrance animation left to watch. Read off the dispatcher rather than a
    // MediaQuery, which initState has no safe access to.
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    Timer(Duration(milliseconds: reduce ? 1200 : 2300), () {
      if (mounted) setState(() => _booting = false);
    });
  }

  /// Debug-only VM hooks so design QA can switch tabs and open nested
  /// screens without accessibility taps.
  void _bindDebugServiceExtensions() {
    if (!kDebugMode) return;
    registerExtensionOnce('ext.balsm.setTab', (method, params) async {
      state.setTab(AppTab.fromId(params['tab']));
      return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true}));
    });
    registerExtensionOnce('ext.balsm.go', (method, params) async {
      final ctx = _navKey.currentContext;
      if (ctx != null) {
        Navigator.of(ctx, rootNavigator: true).popUntil((route) => route.isFirst);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      state.go(params['route'] ?? 'app');
      return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true}));
    });
    registerExtensionOnce('ext.balsm.scroll', (method, params) async {
      final ctx = _navKey.currentContext;
      final c = ctx == null ? null : PrimaryScrollController.maybeOf(ctx);
      if (c != null && c.hasClients) {
        await c.animateTo(
          c.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
      return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true, 'scrolled': c?.hasClients == true}));
    });
    registerExtensionOnce('ext.balsm.setLang', (method, params) async {
      // Locale switch for the docshots driver: one run captures every supported
      // language instead of a rebuild per locale. Rebuilding the shell is enough
      // — direction and the message bundle both hang off state.lang.
      final code = params['lang'] ?? 'en';
      state.setLang(LanguageCode.fromCode(code));
      // The account's display name is locale-dependent in the docshots build.
      // Invalidating the provider alone is not enough — the adapter serves from
      // its own CachedValue — so drop that cache too. Harmless elsewhere.
      final account = ref.read(accountApiProvider);
      if (account is FakeAccountApi) account.language = code;
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) await ref.read(readAccountRepositoryProvider).refresh(uid.value);
      ref.invalidate(accountSummaryProvider);
      // Let the rebuild settle (RTL flips the whole tree) before the capture.
      await Future<void>.delayed(const Duration(milliseconds: 420));
      return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true, 'lang': code}));
    });
    registerExtensionOnce('ext.balsm.checkinNext', (method, params) async {
      state.qaCheckinAdvance?.call();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return developer.ServiceExtensionResponse.result(jsonEncode({'ok': state.qaCheckinAdvance != null}));
    });
    registerExtensionOnce('ext.balsm.open', (method, params) async {
      final screen = params['screen'] ?? '';
      final ctx = _navKey.currentContext;
      if (ctx != null) {
        Navigator.of(ctx, rootNavigator: true).popUntil((route) => route.isFirst);
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (screen.isEmpty || screen == 'close') {
        return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true, 'screen': screen}));
      }
      // Re-read AND re-check after the pop's async gap: the navigator this
      // context belongs to may have been torn down while we waited.
      final next = _navKey.currentContext;
      if (next == null || !next.mounted) {
        return developer.ServiceExtensionResponse.error(1, 'no navigator');
      }
      switch (screen) {
        case 'personal':
          openPersonalDetails(next);
        case 'medical':
          openMedicalProfile(next);
        case 'care':
          openCareTeam(next);
        case 'emergency':
          openEmergency(next);
        case 'privacy':
          openPrivacyData(next, onDeleteAccount: () => openAccountDeletion(next));
        case 'feedback':
          showFeedbackSheet(next);
        case 'ecosystem':
          showEcosystemSheet(next);
        case 'storage':
          showStorageSync(next);
        case 'quicklog':
          showQuickLog(next);
        case 'checkin':
          openCheckin(next);
        case 'addRx':
          showAddPrescription(next);
        case 'switcher':
          showAccountSwitcher(next);
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true, 'screen': screen}));
    });
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch rebuilds this subtree on every state notification — the
    // Riverpod equivalent of the old AnimatedBuilder(animation: state).
    ref.watch(patientAppStateProvider);
    return AppScope(
      state: state,
      child: Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: _navKey,
          navigatorObservers: [widget.navObserver],
          // G2: wire Flutter's Material/Cupertino/widget localizations so date
          // pickers, semantics and default tooltips localize. The app's own
          // string system (i69n `tr()`) is unchanged; these delegates only
          // cover framework-provided widgets.
          //
          // `delegates` (plural) is material_ui's own bundle of exactly the
          // three that used to be listed here — Cupertino, Material, Widgets.
          // Flutter 3.47 moved these out of flutter_localizations into the
          // design packages, so importing both made the name ambiguous.
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
              child: RepaintBoundary(
                key: _captureKey,
                child: ShakeToDevConfig(navigatorKey: _navKey, child: child!),
              ),
            );
          },
          home: DesktopMenuScope(
            state: state,
            captureKey: _captureKey,
            actions: (
              checkIn: () => _menuOpen(openCheckin),
              quickLog: () => _menuOpen(showQuickLog),
              emergency: () => _menuOpen(openEmergency),
              logs: () => _menuOpen(LogsScreen.open),
              devConfig: () => _menuOpen(openDevConfig),
            ),
            child: DeepLinkHandler(
              child: Directionality(
                textDirection: state.dir,
                // Publishes `--app-accent` to the kit so accent-driven widgets
                // (row-head actions, spinners, progress fills, default buttons)
                // follow the app accent instead of a hardcoded hue.
                child: AccentScope(
                  accent: state.accent,
                  child: Scaffold(
                    backgroundColor: Colors.white,
                    body: Stack(children: [
                      // The shell contains its own main pane so the rail stays
                      // at the window edge; every other screen is contained
                      // whole — app.css `.app-body > .screen:not(.app-shell)`.
                      _publicResolveJti != null
                          ? AdaptiveFrame(child: PublicEmergencyResolveScreen(tokenId: _publicResolveJti!))
                          : state.route == AppRoutes.app
                              ? const _MainApp()
                              : const AdaptiveFrame(child: AuthRouter()),
                      if (_publicResolveJti == null)
                        Positioned.fill(child: _BootSplash(state: state, visible: _booting)),
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

/// Content containment at expanded and up — app.css `@container app
/// (min-width: 1024px)`: the screen sits centred at [T.contentMax] on the
/// cream canvas with a hairline down either side, so a touch-first layout
/// never stretches edge-to-edge on desktop/web. Below [minWidth] the screen
/// fills its pane and the internal layout (bottom nav ↔ side rail, adaptive
/// panes) handles every size.
class AdaptiveFrame extends StatelessWidget {
  const AdaptiveFrame({super.key, required this.child, this.minWidth = BalsmWindow.expandedMin});
  final Widget child;

  /// Pane width from which containment applies. The shell's main pane passes
  /// the window threshold less the rail, since the design measures the whole
  /// app body while this widget can only see its own pane.
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < minWidth) return child;
      return ColoredBox(
        color: T.cream50,
        child: Center(
          child: Container(
            width: T.contentMax,
            decoration: const BoxDecoration(
              color: T.surface,
              border: BorderDirectional(
                start: BorderSide(color: T.border),
                end: BorderSide(color: T.border),
              ),
            ),
            child: child,
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
  AppTab? _lastTab;
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _flashNav();
      });
    }

    // Patient app tabs: home / map (nearby care) / medications / profile, plus
    // the quick-log FAB (self-report). Any tab id without a case still
    // resolves to the "coming next" placeholder rather than crashing.
    final screen = switch (s.tab) {
      AppTab.home => const HomeScreen(),
      AppTab.map => const MapScreen(),
      AppTab.meds => const MedsScreen(),
      AppTab.records => RecordsScreen(onBack: () => s.setTab(AppTab.home)),
      AppTab.trends => const TrendsScreen(),
      AppTab.prescriptions => const PrescriptionsScreen(),
      AppTab.profile => const ProfileScreen(),
    };

    final content = LayoutBuilder(builder: (context, c) {
      // Design window classes (app.jsx / RESPONSIVE.md §0): compact <600 →
      // bottom bar · medium/expanded 600–1439 → icon rail · wide ≥1440 →
      // 240px sidebar with the brand block. Rail/sidebar persist on
      // sub-screens; only compact hides its bar there.
      if (c.maxWidth >= BalsmWindow.mediumMin) {
        return Row(children: [
          _SideNav(expanded: c.maxWidth >= BalsmWindow.wideMin),
          // `.app-main`: from 1024 the screen is contained on the cream canvas
          // while the rail keeps the window edge. The pane is the window less
          // the rail, so the threshold moves by the same amount.
          Expanded(
            child: AdaptiveFrame(
              minWidth: BalsmWindow.expandedMin - BalsmWindow.railW,
              child: _navLoading ? const _ScreenSkeleton() : screen,
            ),
          ),
        ]);
      }
      // Phone: full-bleed screen + bottom tab bar. Hide the bar on full-screen
      // sub-screens (trends / records / appointments / prescriptions).
      // Design `app.jsx`: hide on trends/records (and Flutter's appointments
      // sub-screen). Prescriptions stay on the meds path with the tab bar.
      final hideTabBar = s.tab == AppTab.trends || s.tab == AppTab.records;
      return Column(children: [
        Expanded(child: _navLoading ? const _ScreenSkeleton() : screen),
        if (!hideTabBar) const _TabBar(),
      ]);
    });

    // One mount covers both layouts — the phone Column and the tablet
    // _SideNav Row are both inside `content`. Per-screen mounting would stack
    // duplicates as the user moves between tabs.
    return _OfflineAwareBody(
      child: Stack(children: [
        content,
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: TopLoadingBar(loading: _navLoading, color: s.accent.main),
        ),
      ]),
    );
  }
}

/// Puts the offline strip ABOVE the shell content rather than over it.
///
/// In flow, not overlaid. Overlaying it — which is what the first version did —
/// paints the strip on top of each page's header, because a screen's top
/// spacing comes from [PadTop] inside the page, not from any inset the shell
/// reserves.
///
/// The strip consumes the status-bar inset itself, so the subtree below has
/// that inset removed: [PadTop] reads `MediaQuery.paddingOf(context).top` and
/// would otherwise add the notch height a second time, under a strip already
/// clearing it. With it removed, PadTop falls back to its own 24px minimum,
/// which is the gap the header wants under the strip anyway.
class _OfflineAwareBody extends ConsumerWidget {
  const _OfflineAwareBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `valueOrNull == false` and not `!= true`: connectivity is unknown for the
    // first frames, and an unknown state must not shift the whole layout down.
    final offline = ref.watch(onlineProvider).valueOrNull == false;
    if (!offline) return child;

    return Column(children: [
      OfflineBanner(message: AppScope.of(context).strings.common.offline_banner),
      Expanded(
        child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
      ),
    ]);
  }
}

/// Claude Design `ScreenSkeleton` — placeholder chrome while a tab settles.
class _ScreenSkeleton extends StatelessWidget {
  const _ScreenSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar({double w = 140, double h = 14}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: T.ink100, borderRadius: BorderRadius.circular(T.rSm)),
        );
    Widget circle(double size) =>
        Container(width: size, height: size, decoration: const BoxDecoration(color: T.ink100, shape: BoxShape.circle));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      children: [
        bar(w: 140, h: 26),
        const SizedBox(height: 16),
        PCard(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            circle(52),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [bar(w: 160), const SizedBox(height: 8), bar(w: 110, h: 10)])),
          ]),
        ),
        const SizedBox(height: 16),
        PCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  circle(40),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [bar(w: 150), const SizedBox(height: 8), bar(w: 80, h: 10)])),
                ]),
              ),
          ]),
        ),
      ],
    );
  }
}

// ── Phone bottom tab bar ─────────────────────────────────────
class _TabBar extends StatelessWidget {
  const _TabBar();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // `.tabbar { background: var(--balsm-surface) }` — the design dropped the
    // frosted plate for the solid surface. Nothing here clips, so the centre
    // FAB still rides 22px above the bar.
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: T.surface,
        border: Border(top: BorderSide(color: T.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: 22 + MediaQuery.paddingOf(context).bottom.clamp(0, 12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Tab(id: AppTab.home, icon: LucideIcons.home, label: s.strings.nav.tab_home),
          _Tab(id: AppTab.map, icon: LucideIcons.mapPin, label: s.strings.nav.tab_map),
          // Quick-log "+" — opens the daily check-in flow as a route (center slot).
          const _QuickLog(),
          _Tab(id: AppTab.meds, icon: LucideIcons.pill, label: s.strings.nav.tab_meds),
          _Tab(id: AppTab.profile, icon: LucideIcons.user, label: s.strings.nav.tab_profile),
        ]),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.id, required this.icon, required this.label});
  final AppTab id;
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
            Text(label,
                style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.xs2, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}

/// Quick-log "+" action — the design's center FAB. Rendered as a raised accent
/// circle in the bottom tab bar (and the side rail), it opens the quick-log
/// sheet ([showQuickLog]): the full check-in plus the one-metric mini flows.
class _QuickLog extends StatelessWidget {
  const _QuickLog({this.rail = false, this.wide = false});
  final bool rail;
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (wide) {
      // Sidebar (≥1440): `.tab-fab .fab { width: 100%; height: 48px;
      // border-radius: var(--radius-md); padding: 0 14px; justify-content:
      // flex-start; gap: 8px; font-size: var(--pt-md); font-weight: 700 }`
      // with `.fab-label` shown, inside `.tab-fab { margin: 4px 0 12px }`.
      return Padding(
        padding: const EdgeInsets.only(top: Space.s1, bottom: Space.s3),
        child: Pressable(
          onTap: () => showQuickLog(context),
          scale: 0.97,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: s.accent.main,
              borderRadius: BorderRadius.circular(T.rMd),
              boxShadow: s.accent.boxShadow,
            ),
            child: Row(children: [
              const Icon(LucideIcons.plus, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.strings.checkin.ql_title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.body(ar: s.rtl)
                        .copyWith(fontSize: FS.md, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ]),
          ),
        ),
      );
    }
    // Bar: a 58px disc whose 4px white ring lets it punch through the bar as
    // it rides above it. Rail (600–1439): `.tab-fab .fab { width: 48px;
    // height: 48px; border: 0 }` with a 24px glyph, drawn flush.
    final size = rail ? 48.0 : 58.0;
    final button = Pressable(
      onTap: () => showQuickLog(context),
      scale: 0.94,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: s.accent.main,
          shape: BoxShape.circle,
          border: rail ? null : Border.all(color: Colors.white, width: 4),
          boxShadow: s.accent.boxShadow,
        ),
        child: Icon(LucideIcons.plus, size: rail ? 24 : 26, color: Colors.white),
      ),
    );
    if (rail) {
      // `.tab-fab { order: -1; padding: 4px 0 0; margin-bottom: 8px }` on a
      // 60px-tall tab slot — the disc leads the rail, above the tabs.
      return Padding(
        padding: const EdgeInsets.only(top: Space.s1, bottom: Space.s4),
        child: Center(child: button),
      );
    }
    return Expanded(
      child: Center(
        child: Transform.translate(offset: const Offset(0, -22), child: button),
      ),
    );
  }
}

// ── Tablet / desktop side rail ───────────────────────────────
/// app.css `@container app (min-width: 600px) .app-shell > .tabbar`: the
/// 72px rail (`--shell-rail-w`) — 12/6/16 padding, 4px gaps, solid surface,
/// hairline at the inline end — growing at 1440 into the 240px sidebar
/// (`--shell-sidebar-w`, 16/12/20 padding). Order is the design's: brand,
/// quick-log, then the tabs.
class _SideNav extends StatelessWidget {
  const _SideNav({this.expanded = false});

  /// Wide window class (≥1440): the sidebar with the brand block and labelled
  /// rows. Otherwise the medium/expanded icon rail.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      width: expanded ? BalsmWindow.sidebarW : BalsmWindow.railW,
      padding: expanded ? const EdgeInsets.fromLTRB(12, 16, 12, 20) : const EdgeInsets.fromLTRB(6, 12, 6, 16),
      decoration: const BoxDecoration(
        color: T.surface,
        border: BorderDirectional(end: BorderSide(color: T.border)),
      ),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: Space.s1, children: [
          _NavBrand(expanded: expanded),
          _QuickLog(rail: true, wide: expanded),
          _RailItem(id: AppTab.home, icon: LucideIcons.home, label: s.strings.nav.tab_home, wide: expanded),
          _RailItem(id: AppTab.map, icon: LucideIcons.mapPin, label: s.strings.nav.tab_map, wide: expanded),
          _RailItem(id: AppTab.meds, icon: LucideIcons.pill, label: s.strings.nav.tab_meds, wide: expanded),
          _RailItem(id: AppTab.profile, icon: LucideIcons.user, label: s.strings.nav.tab_profile, wide: expanded),
          const Spacer(),
        ]),
      ),
    );
  }
}

/// `.nav-brand` — the mark alone on the rail (`.nav-mark` 40px, `.nav-word`
/// hidden); on the sidebar a 44px mark beside the wordmark, `Balsm` in the
/// 22px display face and `.health` at 17px in the TLD colour.
class _NavBrand extends StatelessWidget {
  const _NavBrand({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 14),
        child: Center(child: SvgPicture.asset(Assets.brand_icon, width: 40, height: 40)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 22),
      child: Row(children: [
        SvgPicture.asset(Assets.brand_icon, width: 44, height: 44),
        const SizedBox(width: 12),
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text: 'Balsm',
                style: Typo.heading(ar: false)
                    .copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: T.wordmark, letterSpacing: -0.22)),
            TextSpan(
                text: '.health',
                style:
                    Typo.heading(ar: false).copyWith(fontSize: 17, fontWeight: FontWeight.w500, color: T.wordmarkTld)),
          ]),
          textDirection: TextDirection.ltr,
        ),
      ]),
    );
  }
}

/// One nav tab off the phone bar. Rail: `.tabbar .tab { padding: 10px 4px 8px;
/// border-radius: var(--radius-md); gap: 4px; min-height: 60px }` with the
/// label clamped to two lines and `.tab.active { background: accent-50 }`.
/// Sidebar: a 44px row, `padding: 0 12px; gap: 12px`, 20px glyph, `pt-sm`
/// label at 500 in fg2 — active in accent-600 at 600.
class _RailItem extends StatelessWidget {
  const _RailItem({required this.id, required this.icon, required this.label, this.wide = false});
  final AppTab id;
  final IconData icon;
  final String label;
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final active = s.tab == id;
    final child = wide
        ? Row(children: [
            Icon(icon, size: 20, color: active ? s.accent.d : T.fg2),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.body(ar: s.rtl).copyWith(
                      fontSize: FS.sm,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? s.accent.d : T.fg2)),
            ),
          ])
        : Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 24, color: active ? s.accent.main : T.fg4),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Typo.body(ar: s.rtl).copyWith(
                    fontSize: FS.xs2, fontWeight: FontWeight.w600, height: 1.2, color: active ? s.accent.main : T.fg4)),
          ]);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => s.setTab(id),
      child: Container(
        constraints: BoxConstraints(minHeight: wide ? 44 : 60),
        padding: wide ? const EdgeInsets.symmetric(horizontal: 12) : const EdgeInsets.fromLTRB(4, 10, 4, 8),
        alignment: wide ? AlignmentDirectional.centerStart : Alignment.center,
        decoration: BoxDecoration(
          color: active ? s.accent.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(T.rMd),
        ),
        child: child,
      ),
    );
  }
}

/// Branded boot splash (`SplashScreen` in auth.jsx): mark wash
/// backdrop, mark spinner, then fade over `--dur-slow`.
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
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: T.cream50),
          // Image's own `opacity`, not an Opacity wrapper: wrapping a
          // full-bleed image forces a saveLayer offscreen composite every
          // frame, while this folds the alpha into the paint.
          Image.asset(
            Assets.brand_background,
            fit: BoxFit.cover,
            // `.splash-bg { background-position: 78% top }` — the same crop
            // the welcome screen uses, so the cross-fade lands on itself.
            alignment: const Alignment(0.56, -1),
            opacity: const AlwaysStoppedAnimation(0.95),
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.2,
                colors: [
                  Color(0x00FAFAF7),
                  Color(0x57FAFAF7),
                  Color(0xEBFAFAF7),
                ],
                stops: [0.0, 0.54, 1.0],
              ),
            ),
          ),
          // `.splash-core` — the mark and its promise, optically centred, with
          // `.splash-foot` pinned to the bottom.
          Column(children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const SplashMark(),
                    // `.splash-promise { margin-top: 22px }`
                    const SizedBox(height: 22),
                    SplashRise(
                      delay: const Duration(milliseconds: 550),
                      child: Text(
                        state.strings.boot.boot_promise,
                        textAlign: TextAlign.center,
                        style: Typo.heading(ar: ar).copyWith(fontSize: FS.lg, height: 1.35, letterSpacing: -0.01),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            SplashRise(
              delay: const Duration(milliseconds: 800),
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.paddingOf(context).bottom + 42),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(state.strings.ecosystem.eco_tagline, style: Typo.eyebrow(T.wordmark, ar: ar)),
                  const SizedBox(height: 16),
                  const SplashDots(),
                ]),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
