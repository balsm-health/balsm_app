import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:account/account.dart' show accountProfileUseCaseProvider;
import 'package:core/core.dart';
import 'package:deletion/deletion.dart';
import 'package:emergency_card/emergency_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart';

import '../update/update_gate.dart';
import 'app_state.dart';
import 'assets.dart';
import 'deep_link_handler.dart';
import 'deep_links.dart';
import 'desktop_menu.dart';
import 'dev/log_buffer.dart';
import 'dev/shake_to_dev_config.dart';
import 'family/family_flag_guard.dart';
import 'family/family_links_sync.dart';
import 'flags.dart';
import 'kit.dart';
import 'maintenance/maintenance_controller.dart';
import 'maintenance/maintenance_widgets.dart';
import 'offline_banner.dart';
import 'responsive.dart';
import 'routes.dart';
import 'screens/add_prescription_sheet.dart';
import 'screens/auth_flow.dart';
import 'screens/care_team_screen.dart';
import 'screens/ecosystem_sheet.dart';
import 'screens/feedback_sheet.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/meds_screen.dart';
import 'screens/personal_details.dart';
import 'screens/prescriptions_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/profile_subscreens.dart';
import 'screens/quick_log.dart';
import 'screens/records_screen.dart';
import 'screens/report_flow.dart';
import 'screens/storage_sheet.dart';
import 'screens/trends_screen.dart';
import 'theme.dart';
import 'widgets/account_switcher.dart';
import 'widgets/balsm_mark.dart';
import 'widgets/beta_banner.dart';
import 'widgets/exit_confirm_scope.dart';
import 'widgets/other_tab_screen.dart';

// Scrolling the page to its end after a tab change.
const _scrollToEnd = Duration(milliseconds: 280);

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
  const PatientApp({required this.navObservers, super.key});

  /// Logs a `screen_view` analytics action on each navigation.
  final List<NavigatorObserver> navObservers;

  @override
  ConsumerState<PatientApp> createState() => _PatientAppState();
}

class _PatientAppState extends ConsumerState<PatientApp> with WidgetsBindingObserver {
  late final PatientAppState state = ref.read(patientAppStateProvider);
  final _navKey = GlobalKey<NavigatorState>();

  /// Rasterisation root for the desktop menu's Save-screenshot action.
  // Shared with Dev Config, which screenshots the app for bug reports.
  final GlobalKey<State<StatefulWidget>> _captureKey = appCaptureKey;

  void _menuOpen(void Function(BuildContext) opener) {
    final ctx = _navKey.currentContext;
    if (ctx != null && ctx.mounted) opener(ctx);
  }

  /// The day the app last drew "today" for, and the timer that fires at the
  /// next local midnight. Left open overnight, Home kept yesterday's finished
  /// check-in and the pregnancy screen yesterday's days-to-go.
  DateTime _day = _dayOf(DateTime.now());
  Timer? _midnight;

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  void _armMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    // A second past midnight, so the rebuild lands on the new day.
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), _checkDay);
  }

  /// Rebuilds once when the calendar day moved on (timer, or a resume after a
  /// night in the background where timers do not run).
  void _checkDay() {
    final today = _dayOf(DateTime.now());
    if (today != _day) {
      _day = today;
      state.dayChanged();
    }
    _armMidnight();
  }

  // Boot splash (auth.jsx `SplashScreen`) — mark wash + mark spinner,
  // held ~2.3s on cold start, then fades out.
  bool _booting = true;

  /// Web only: a scanned profile-QR URL (`/t/{jti}`, legacy `/emergency/{jti}`)
  /// renders the public resolve page instead of the app — no session needed,
  /// and the sessionless shell must not eject to the auth flow. The AES key
  /// stays in the URL fragment, read by the resolve screen itself.
  String? _publicResolveJti;

  /// Web only: `/delete-account` and `/delete-account-cancel` render the
  /// session-less deletion screens. Google Play requires the deletion route to
  /// work for someone who no longer has the app, so it must not eject to auth.
  bool _publicDelete = false;
  bool _publicDeleteCancel = false;

  /// Web only: another tab owns the on-device database, so this one shows
  /// [OtherTabScreen] instead of an app that cannot read or write anything.
  bool _otherTab = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Same route table as the mobile deep-link handler (deep_links.dart), so a
      // path means the same thing in a browser and in the app. Only the public
      // pages replace the shell here — a web visitor to one has no app behind
      // it to return to. Everything else is left to the mobile-style handler.
      switch (parseDeepLink(Uri.base)) {
        case EmergencyCardTarget(:final tokenId):
          _publicResolveJti = tokenId;
        case DeleteAccountTarget():
          _publicDelete = true;
        case DeleteAccountCancelTarget():
          _publicDeleteCancel = true;
        default:
          break;
      }
      // The public pages never touch the database, so they stay usable.
      if (_publicResolveJti == null && !_publicDelete && !_publicDeleteCancel) {
        unawaited(
          claimDatabaseTab().then((owned) {
            if (!owned && mounted) setState(() => _otherTab = true);
          }),
        );
      }
    }
    LogBuffer.instance.install();
    // FR-509: care team reconciles with the cloud when the app comes back to
    // the foreground. Sign-in / profile-switch is handled by the listen in
    // build(); pull-to-refresh by the care-team screen itself.
    WidgetsBinding.instance.addObserver(this);
    _armMidnight();
    // Family links have no push: pull them on sign-in (and on a cold start
    // that is already signed in) and on every resume — see below.
    ref.listenManual<UserId?>(
      currentUserIdProvider,
      (previous, next) {
        if (next != null && next != previous) {
          _pullFamilyLinks();
          unawaited(_restoreGender(next));
        }
      },
      fireImmediately: true,
    );
    // A block covers the shell from its home route, so anything pushed above
    // it (a sheet, a sub-screen) is closed when the block begins.
    ref.listenManual<MaintenanceStatus>(maintenanceProvider, (previous, next) {
      if (!next.blocks || (previous?.blocks ?? false)) return;
      _navKey.currentState?.popUntil((route) => route.isFirst);
    });
    _bindDebugServiceExtensions();
    // Hold 2300ms, or 1200 under reduced motion — the spinner is the only
    // thing left to watch. Read off the dispatcher rather than a MediaQuery,
    // which initState has no safe access to.
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    Timer(Duration(milliseconds: reduce ? 1200 : 2300), () {
      _splashHeld = true;
      _endBootWhenReady();
    });
    // The splash also waits for the signed-in account (name, gender, family)
    // so Home does not open empty — no name, "0 places", masculine copy —
    // and fill in seconds later. Capped so a slow server never traps the
    // patient on the splash.
    Timer(const Duration(seconds: 8), () {
      if (mounted && _booting) setState(() => _booting = false);
    });
  }

  bool _splashHeld = false;

  void _endBootWhenReady() {
    if (!mounted || !_booting || !_splashHeld) return;
    final signedIn = ref.read(currentUserIdProvider) != null;
    final accountReady = !signedIn || ref.read(accountSummaryProvider).hasValue;
    if (accountReady) {
      setState(() => _booting = false);
    } else {
      ref.listenManual(accountSummaryProvider, (_, next) {
        if (next.hasValue || next.hasError) {
          if (mounted && _booting) setState(() => _booting = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle != AppLifecycleState.resumed) return;
    _checkDay();
    unawaited(ref.read(maintenanceProvider.notifier).check());
    // Flags first: a sync switched on or off remotely applies to this very run.
    unawaited(
      ref.read(featureFlagsProvider).refresh().whenComplete(() {
        _syncCareTeam();
        _pullFamilyLinks();
      }),
    );
  }

  /// Gendered Arabic copy follows the account's saved sex. Account details
  /// sets it when opened, but nothing did on a cold start, so a restarted app
  /// addressed every woman in the masculine until she opened that screen.
  /// Loaded once per signed-in account; a failure (offline) keeps what the
  /// state already has.
  Future<void> _restoreGender(UserId user) async {
    try {
      final profile = await ref.read(accountProfileUseCaseProvider).load();
      final g = profile?.gender;
      if (!mounted || g == null || ref.read(currentUserIdProvider) != user) return;
      state.setGender(g);
    } on Object catch (_) {
      // Offline or the server refused: the copy stays as it was.
    }
  }

  void _pullFamilyLinks() {
    if (!mounted || !familyLinkOn(state.flags) || ref.read(currentUserIdProvider) == null) return;
    if (ref.read(maintenanceProvider).pausesActions) return;
    pullFamilyLinks(ref);
  }

  /// Where the update check keeps its cache. Null when no storage is bound —
  /// a widget test pumping the shell bare — in which case no check runs.
  late final AppUpdatePrefs? _updatePrefs = () {
    try {
      return AppUpdatePrefs(ref.read(globalKVDataSourceProvider));
    } on Object catch (_) {
      return null;
    }
  }();

  /// Fire-and-forget: the care-team screen reads from drift, so a failed sync
  /// costs the patient nothing visible — [CareTeamSyncService] records it on
  /// the sync-status provider and retries on the next trigger.
  /// The Mother & Child flag as last built; null before the first build.
  bool? _familyOn;

  void _keepSelfWithoutFamily() {
    if (!mounted) return;
    unawaited(
      keepSelfActiveWithoutFamily(
        familyOn: state.flags.isOn(AppFlags.motherChild),
        active: ref.read(currentProfileIdProvider),
        self: () => ref.read(selfProfileIdProvider.future),
        selectSelf: () => ref.read(activeProfileSwitcherProvider).selectSelf(),
      ),
    );
  }

  void _syncCareTeam() {
    if (!mounted || ref.read(maintenanceProvider).pausesActions) return;
    final profileId = ref.read(currentProfileIdProvider);
    if (profileId == null) return;
    unawaited(ref.read(careTeamSyncServiceProvider).sync(profileId));
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
          duration: _scrollToEnd,
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
      // `refreshAccountSummary` and not a hand-rolled refresh: the summary is
      // cached under the literal key 'self', not under the user id, so
      // refreshing by id invalidated a different row and the UI kept serving
      // the previous locale's name.
      await refreshAccountSummary(ref);
      // Let the rebuild settle (RTL flips the whole tree) before the capture.
      await Future<void>.delayed(const Duration(milliseconds: 420));
      return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true, 'lang': code}));
    });
    registerExtensionOnce('ext.balsm.setGender', (method, params) async {
      // Gendered Arabic copy (CODING_STANDARDS.md §4) is checked by capturing
      // each screen once per gender in one run.
      state.setGender(Gender.fromString(params['gender']));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true, 'gender': state.gender.name}));
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
          unawaited(showFeedbackSheet(next));
        case 'ecosystem':
          unawaited(showEcosystemSheet(next));
        case 'storage':
          showStorageSync(next);
        case 'quicklog':
          showQuickLog(next, source: ProductSource.menu);
        case 'checkin':
          openCheckin(next);
        case 'addRx':
          unawaited(showAddPrescription(next));
        case 'switcher':
          unawaited(showAccountSwitcher(next));
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true, 'screen': screen}));
    });
  }

  /// Chose "Use on this device only" on the pre-sign-in maintenance page.
  bool _maintenanceDeviceOnly = false;

  /// The full-screen maintenance page, when one applies (design app-mc.jsx):
  /// a block covers the signed-in app; any maintenance covers sign-in and
  /// account creation, until the patient picks "Use on this device only".
  /// The walkthrough and the device-only unlock stay reachable — they never
  /// touch the server. The public QR / deletion pages are never covered.
  List<Widget> _maintenancePage(MaintenanceStatus m) {
    final route = state.route;
    if (route == AppRoutes.app) {
      return [if (m.blocks) const Positioned.fill(child: MaintenanceScreen(signedIn: true))];
    }
    if (!m.pausesActions || route == AppRoutes.walkthrough || route == AppRoutes.unlock) return const [];
    if (!m.blocks && _maintenanceDeviceOnly && state.authIntent == AuthIntent.deviceOnly) return const [];
    return [
      Positioned.fill(
        child: AdaptiveFrame(
          child: MaintenanceScreen(
            signedIn: false,
            onDeviceOnly: () {
              setState(() => _maintenanceDeviceOnly = true);
              state
                ..setAuthIntent(AuthIntent.deviceOnly)
                ..go(AppRoutes.phone);
            },
          ),
        ),
      ),
    ];
  }

  /// System back (Android) on a screen of the signed-in shell that sits above
  /// another: Records and Trends go up to Home, Prescriptions to Meds, as their
  /// own back buttons do. True when it handled the back; otherwise
  /// [ExitConfirmScope] asks "Exit Balsm?" instead of closing the app.
  bool _stepBackUp() {
    if (state.route != AppRoutes.app) return false;
    final up = switch (state.tab) {
      AppTab.records || AppTab.trends => AppTab.home,
      AppTab.prescriptions => AppTab.meds,
      _ => null,
    };
    if (up == null) return false;
    state.setTab(up);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch rebuilds this subtree on every state notification — the
    // Riverpod equivalent of the old AnimatedBuilder(animation: state).
    ref.watch(patientAppStateProvider);
    final maintenance = ref.watch(maintenanceProvider);
    // FR-509: reconcile on sign-in and on a dependant-profile switch. Firing on
    // the null -> non-null edge means a signed-out app never calls the API, and
    // a restored device pulls its roster as soon as the profile resolves.
    ref.listen<HealthProfileId?>(currentProfileIdProvider, (previous, next) {
      if (next != null && next != previous) _syncCareTeam();
      if (next != previous) _keepSelfWithoutFamily();
    });
    final familyOn = state.flags.isOn(AppFlags.motherChild);
    if (familyOn != _familyOn) {
      _familyOn = familyOn;
      if (!familyOn) scheduleMicrotask(_keepSelfWithoutFamily);
    }
    return AppScope(
      state: state,
      child: Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: _navKey,
          navigatorObservers: widget.navObservers,
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
          theme: balsmTheme(),
          // Clamp Dynamic Type so large system text never breaks layouts.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
              ),
              // Shake anywhere → Dev Config (read-only in prod).
              child: BetaBanner(
                state: state,
                child: RepaintBoundary(
                  key: _captureKey,
                  child: _otherTab
                      ? OtherTabScreen(state: state)
                      : ShakeToDevConfig(navigatorKey: _navKey, child: _UpdateGate(state, child!, prefs: _updatePrefs)),
                ),
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
                  child: ExitConfirmScope(
                    stepBack: _stepBackUp,
                    child: Scaffold(
                      backgroundColor: AppColors.white,
                      body: Stack(
                        children: [
                          // The shell contains its own main pane so the rail stays
                          // at the window edge; every other screen is contained
                          // whole — app.css `.app-body > .screen:not(.app-shell)`.
                          if (_publicResolveJti != null)
                            AdaptiveFrame(child: PublicEmergencyResolveScreen(tokenId: _publicResolveJti!))
                          else if (_publicDelete)
                            const AdaptiveFrame(child: PublicDeleteScreen())
                          else if (_publicDeleteCancel)
                            const AdaptiveFrame(child: PublicDeleteCancelledScreen())
                          else if (state.route == AppRoutes.app)
                            const _MainApp()
                          else
                            const AdaptiveFrame(child: AuthRouter()),
                          if (_publicResolveJti == null && !_publicDelete && !_publicDeleteCancel)
                            ..._maintenancePage(maintenance),
                          if (_publicResolveJti == null && !_publicDelete && !_publicDeleteCancel)
                            Positioned.fill(child: _BootSplash(state: state, visible: _booting)),
                        ],
                      ),
                    ),
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
/// (min-width: 1024px)`: the screen sits centred at [BalsmWindow.appContentMax] on the
/// cream canvas with a hairline down either side, so a touch-first layout
/// never stretches edge-to-edge on desktop/web. Below [minWidth] the screen
/// fills its pane and the internal layout (bottom nav ↔ side rail, adaptive
/// panes) handles every size.
class AdaptiveFrame extends StatelessWidget {
  const AdaptiveFrame({required this.child, super.key, this.minWidth = BalsmWindow.expandedMin});
  final Widget child;

  /// Pane width from which containment applies. The shell's main pane passes
  /// the window threshold less the rail, since the design measures the whole
  /// app body while this widget can only see its own pane.
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < minWidth) return child;
        return ColoredBox(
          color: AppColors.cream50,
          child: Center(
            child: Container(
              width: BalsmWindow.appContentMax,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: BorderDirectional(
                  start: BorderSide(color: AppColors.border),
                  end: BorderSide(color: AppColors.border),
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
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
      AppTab.map => MapScreen(filterRequest: s.mapFilterRequest),
      AppTab.meds => const MedsScreen(),
      AppTab.records => RecordsScreen(onBack: () => s.setTab(AppTab.home)),
      AppTab.trends => const TrendsScreen(),
      AppTab.prescriptions => const PrescriptionsScreen(),
      AppTab.profile => const ProfileScreen(),
    };

    final content = LayoutBuilder(
      builder: (context, c) {
        // Design window classes (app.jsx / RESPONSIVE.md §0): compact <600 →
        // bottom bar · medium/expanded 600–1439 → icon rail · wide ≥1440 →
        // 240px sidebar with the brand block. Rail/sidebar persist on
        // sub-screens; only compact hides its bar there.
        if (c.maxWidth >= BalsmWindow.mediumMin) {
          return Row(
            children: [
              _SideNav(expanded: c.maxWidth >= BalsmWindow.wideMin),
              // `.app-main`: from 1024 the screen is contained on the cream canvas
              // while the rail keeps the window edge. The pane is the window less
              // the rail, so the threshold moves by the same amount.
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: AdaptiveFrame(
                        minWidth: BalsmWindow.expandedMin - BalsmWindow.railW,
                        child: _navLoading ? const _ScreenSkeleton() : screen,
                      ),
                    ),
                    const MaintenanceStrip(),
                  ],
                ),
              ),
            ],
          );
        }
        // Phone: full-bleed screen + bottom tab bar. Hide the bar on full-screen
        // sub-screens (trends / records / appointments / prescriptions).
        // Design `app.jsx`: hide on trends/records (and Flutter's appointments
        // sub-screen). Prescriptions stay on the meds path with the tab bar.
        final hideTabBar = s.tab == AppTab.trends || s.tab == AppTab.records;
        return Column(
          children: [
            Expanded(child: _navLoading ? const _ScreenSkeleton() : screen),
            // Read-only maintenance: the strip sits right above the tab bar.
            const MaintenanceStrip(),
            if (!hideTabBar) const _TabBar(),
          ],
        );
      },
    );

    // One mount covers both layouts — the phone Column and the tablet
    // _SideNav Row are both inside `content`. Per-screen mounting would stack
    // duplicates as the user moves between tabs.
    return _OfflineAwareBody(
      child: Stack(
        children: [
          content,
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: TopLoadingBar(loading: _navLoading, color: s.accent.main),
          ),
        ],
      ),
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
    // `value == false` and not `!= true`: connectivity is unknown for the
    // first frames, and an unknown state must not shift the whole layout down.
    final offline = ref.watch(onlineProvider).value == false;
    if (!offline) return child;

    return Column(
      children: [
        OfflineBanner(message: AppScope.of(context).strings.common.offline_banner),
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
        ),
      ],
    );
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
          decoration: BoxDecoration(color: AppColors.ink100, borderRadius: BorderRadius.circular(AppRadii.sm)),
        );
    Widget circle(double size) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: AppColors.ink100, shape: BoxShape.circle),
        );

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 56, 20, 24),
      children: [
        bar(h: 26),
        const SizedBox(height: 16),
        PCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              circle(52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [bar(w: 160), const SizedBox(height: 8), bar(w: 110, h: 10)],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      circle(40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [bar(w: 150), const SizedBox(height: 8), bar(w: 80, h: 10)],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Phone bottom tab bar ─────────────────────────────────────

/// Space under the tabs for a bottom system inset of [inset].
///
/// The design's 22px foot already leaves room for the iPhone home indicator,
/// which may overlap it, so only 12 more of its 34 are added. Android draws
/// edge to edge from SDK 35, and its 3-button navigation bar (about 48dp) is
/// solid: nothing may sit under it, so the bar never gives less than the whole
/// inset. Gesture navigation's thin handle keeps the iPhone spacing.
@visibleForTesting
double tabBarBottomPadding(double inset) => math.max(22 + inset.clamp(0, 12), inset);

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
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(bottom: tabBarBottomPadding(MediaQuery.paddingOf(context).bottom)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Tab(id: AppTab.home, icon: LucideIcons.home, label: s.strings.nav.tab_home),
            _Tab(id: AppTab.map, icon: LucideIcons.mapPin, label: s.strings.nav.tab_map),
            // Quick-log "+" — opens the daily check-in flow as a route (center slot).
            const _QuickLog(),
            _Tab(id: AppTab.meds, icon: LucideIcons.pill, label: s.strings.nav.tab_meds),
            _Tab(id: AppTab.profile, icon: LucideIcons.user, label: s.strings.nav.tab_profile),
          ],
        ),
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
    final color = active ? s.accent.main : AppColors.textHint;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => s.setTab(id),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 4, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: Typo.body(ar: s.rtl)
                    .copyWith(fontSize: FontSizes.eyebrow, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick-log "+" action — the design's center FAB. Rendered as a raised accent
/// circle in the bottom tab bar (and the side rail), it opens the quick-log
/// sheet ([showQuickLog]): the full check-in plus the one-metric mini flows.
///
/// In read-only maintenance it is washed out with a lock badge and announces
/// "Adding is paused during maintenance"; a tap still reaches the guard.
class _QuickLog extends StatelessWidget {
  const _QuickLog({this.rail = false, this.wide = false});
  final bool rail;
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget fab(Widget child) =>
        MaintenanceFabLock(label: s.strings.checkin.ql_title, onTap: () => showQuickLog(context), child: child);
    if (wide) {
      // Sidebar (≥1440): `.tab-fab .fab { width: 100%; height: 48px;
      // border-radius: var(--radius-md); padding: 0 14px; justify-content:
      // flex-start; gap: 8px; font-size: var(--pt-md); font-weight: 700 }`
      // with `.fab-label` shown, inside `.tab-fab { margin: 4px 0 12px }`.
      return Padding(
        padding: const EdgeInsets.only(top: Space.s1, bottom: Space.s3),
        child: fab(
          Pressable(
            onTap: () => showQuickLog(context),
            scale: 0.97,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: s.accent.main,
                borderRadius: BorderRadius.circular(AppRadii.md),
                boxShadow: s.accent.boxShadow,
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.plus, size: 20, color: AppColors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.strings.checkin.ql_title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Typo.body(ar: s.rtl)
                          .copyWith(fontSize: FontSizes.body, fontWeight: FontWeight.w700, color: AppColors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    // Bar: a 58px disc whose 4px white ring lets it punch through the bar as
    // it rides above it. Rail (600–1439): `.tab-fab .fab { width: 48px;
    // height: 48px; border: 0 }` with a 24px glyph, drawn flush.
    // The compact bar now draws it inline (app.css "Check-in FAB — v2 colour +
    // inline position"): a 52px ink disc, no ring, centred in the bar.
    final size = rail ? 48.0 : 52.0;
    final button = fab(
      Pressable(
        onTap: () => showQuickLog(context),
        scale: 0.94,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rail ? s.accent.main : AppColors.ink800,
            shape: BoxShape.circle,
            boxShadow: rail ? s.accent.boxShadow : AppShadows.fab,
          ),
          child: Icon(LucideIcons.plus, size: rail ? 24 : 26, color: AppColors.white),
        ),
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
    // `.tabbar .tab-fab { align-self: center }` — level with the tabs (58
    // tall), not raised above the bar.
    return Expanded(
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: 3),
        child: Center(child: button),
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
      padding: expanded
          ? const EdgeInsetsDirectional.fromSTEB(12, 16, 12, 20)
          : const EdgeInsetsDirectional.fromSTEB(6, 12, 6, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: BorderDirectional(end: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.s1,
          children: [
            _NavBrand(expanded: expanded),
            _QuickLog(rail: true, wide: expanded),
            _RailItem(id: AppTab.home, icon: LucideIcons.home, label: s.strings.nav.tab_home, wide: expanded),
            _RailItem(id: AppTab.map, icon: LucideIcons.mapPin, label: s.strings.nav.tab_map, wide: expanded),
            _RailItem(id: AppTab.meds, icon: LucideIcons.pill, label: s.strings.nav.tab_meds, wide: expanded),
            _RailItem(id: AppTab.profile, icon: LucideIcons.user, label: s.strings.nav.tab_profile, wide: expanded),
            const Spacer(),
          ],
        ),
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
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 22),
      child: Row(
        children: [
          SvgPicture.asset(Assets.brand_icon, width: 44, height: 44),
          const SizedBox(width: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Balsm',
                  style: Typo.heading().copyWith(
                    fontSize: FontSizes.headline,
                    fontWeight: FontWeight.w700,
                    color: AppColors.wordmark,
                    letterSpacing: -0.22,
                  ),
                ),
                TextSpan(
                  text: '.health',
                  style: Typo.heading().copyWith(
                    fontSize: FontSizes.subheadSm,
                    fontWeight: FontWeight.w500,
                    color: AppColors.wordmarkTld,
                  ),
                ),
              ],
            ),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
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
        ? Row(
            children: [
              Icon(icon, size: 20, color: active ? s.accent.d : AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.body(ar: s.rtl).copyWith(
                    fontSize: FontSizes.bodySm,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? s.accent.d : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: active ? s.accent.main : AppColors.textHint),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Typo.body(ar: s.rtl).copyWith(
                  fontSize: FontSizes.eyebrow,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: active ? s.accent.main : AppColors.textHint,
                ),
              ),
            ],
          );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => s.setTab(id),
      child: Container(
        constraints: BoxConstraints(minHeight: wide ? 44 : 60),
        padding: wide ? const EdgeInsets.symmetric(horizontal: 12) : const EdgeInsetsDirectional.fromSTEB(4, 10, 4, 8),
        alignment: wide ? AlignmentDirectional.centerStart : Alignment.center,
        decoration: BoxDecoration(
          color: active ? s.accent.bg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: child,
      ),
    );
  }
}

/// Branded boot splash (`SplashScreen` in auth.jsx): mark wash
/// backdrop and the mark spinner, with no text, then fade over `--dur-slow`.
class _BootSplash extends StatelessWidget {
  const _BootSplash({required this.state, required this.visible});
  final PatientAppState state;
  final bool visible;
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Motion.slow,
        curve: Motion.easeOut,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.cream50),
            // Image's own `opacity`, not an Opacity wrapper: wrapping a
            // full-bleed image forces a saveLayer offscreen composite every
            // frame, while this folds the alpha into the paint.
            Image.asset(
              Assets.brand_background,
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.95),
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.2,
                  colors: [
                    AppColors.creamClear,
                    AppColors.creamVeil,
                    AppColors.creamFrost,
                  ],
                  stops: [0.0, 0.54, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              // The mark alone, no caption. A screen reader still hears what is
              // happening: the label that used to be drawn is now spoken.
              child: Center(
                child: Semantics(
                  label: state.strings.boot.boot_preparing,
                  child: const MarkSpinner(size: 96),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app-update prompt, dressed for this shell: its brand's manifest and
/// name, the patient app's strings, accent and mark.
class _UpdateGate extends StatelessWidget {
  const _UpdateGate(this.state, this.child, {this.prefs});
  final PatientAppState state;
  final Widget child;

  /// Null when no storage is bound — the update check then does not run.
  final AppUpdatePrefs? prefs;

  @override
  Widget build(BuildContext context) {
    final brand = FlavorConfig.currentOrNull?.brand ?? AppBrand.balsm;
    final name = brand.nameIn(state.lang.value);
    final u = state.strings.update;
    return UpdateGate(
      brand: brand,
      lang: state.lang.value,
      prefs: prefs,
      look: UpdateLook(
        rtl: state.rtl,
        accent: state.accent,
        mark: const BalsmFlower(size: 52),
        copy: UpdateCopy(
          eyebrowNew: u.upd_eyebrow_new,
          eyebrowRequired: u.upd_eyebrow_required,
          availableTitle: u.upd_available_t(name),
          availableBody: u.upd_available_b,
          requiredTitle: u.upd_required_t(name),
          requiredBody: u.upd_required_b,
          current: u.upd_current,
          newVersion: u.upd_new,
          whatsNew: u.upd_whats_new,
          updateNow: u.upd_now,
          skip: u.upd_skip,
          fullNotes: u.upd_full_notes,
          close: state.strings.common.a11y_close,
        ),
      ),
      child: child,
    );
  }
}
