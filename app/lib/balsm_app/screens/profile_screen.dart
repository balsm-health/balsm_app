import 'package:auth/auth.dart' show signOutUseCaseProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:core/core.dart'
    show
        StatusScreen,
        accountSummaryProvider,
        FlavorConfig,
        balsmApiControllerProvider,
        ServerSelectorScreen,
        CountryCode,
        CountryCodeL10n,
        LanguageCode,
        LanguageCodeL10n;
import 'package:sessions/sessions.dart' show SessionsScreen;
import 'package:deletion/deletion.dart' show DeleteAccountScreen, DeletionConfirmScreen, DeletionCancelledScreen;
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../shell.dart' show AdaptiveFrame;
import 'personal_details.dart';
import 'ecosystem_sheet.dart';
import 'feedback_sheet.dart';
import 'profile_subscreens.dart';
import 'storage_sheet.dart';
import '../widgets/badges.dart';

/// Profile tab (home.jsx ProfileScreen) — main screen + language/country sheets.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    // Real account summary → profile head (name + handle). Null while loading /
    // signed out, in which case the head renders neutrally.
    final account = ref.watch(accountSummaryProvider);
    final summary = account.valueOrNull;
    final displayName = (summary?.displayName ?? '').trim();
    final curLang = s.lang;
    // Reflects the active backup target (StorageTarget).
    final stCfg = storageCfg(s.storageProvider);
    // Design order (home.jsx ProfileScreen): personal → conditions → care →
    // emergency → notif → privacy → feedback → ecosystem → help.
    // Appointments stays as a Flutter-only extra (design never opens that
    // screen from profile). Governance stays in its own card below.
    final rows = <(IconData, String, VoidCallback?, bool)>[
      (LucideIcons.user, 'profile.p_personal', () => openPersonalDetails(context), false),
      (LucideIcons.clipboardList, 'profile.p_cond', () => openMedicalProfile(context), false),
      (LucideIcons.stethoscope, 'profile.p_care', () => openCareTeam(context), false),
      // Flutter-only row. The design defines an AppointmentsScreen but never
      // navigates to it (app.jsx calls it a sub-screen "reached from
      // Home/Profile", yet nothing links there), so the app surfaces it — next
      // to Care team, which schedules the visits. Every design row keeps its
      // relative order.
      (LucideIcons.calendar, 'care.appts', () => s.setTab('appts'), false),
      (LucideIcons.siren, 'profile.p_emergency', () => openEmergency(context), true),
      (LucideIcons.bell, 'profile.p_notif', null, false),
      (
        LucideIcons.shieldCheck,
        'profile.p_privacy',
        () => openPrivacyData(context, onDeleteAccount: () => openAccountDeletion(context)),
        false
      ),
      (LucideIcons.star, 'feedback.fb_row', () => showFeedbackSheet(context), false),
      (LucideIcons.flower2, 'ecosystem.eco_row', () => showEcosystemSheet(context), false),
      (LucideIcons.lifeBuoy, 'profile.p_help', null, false),
    ];
    return ContentColumn(
        maxWidth: 720,
        child: ListView(padding: EdgeInsets.zero, children: [
          const PadTop(),
          AppBarRow(children: [
            Expanded(child: Text(s.strings.common.profile, style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl))),
          ]),

          // Profile head — real account summary (name + handle) plus the
          // patient's own chronic conditions (`.profile-head`). Everything here
          // is real data: the design's "patient since" line has no counterpart
          // on AccountSummary, so it is omitted rather than fabricated.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Column(children: [
              Avatar(initials: accountInitials(displayName), color: T.petalAqua, size: 84, fontSize: FS.xl3, ar: s.rtl),
              if (displayName.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(displayName, style: Typo.title(ar: s.rtl).copyWith(fontSize: FS.xl2, fontWeight: FontWeight.w800)),
              ],
              // A failed `GET /account/self` used to render exactly like a
              // signed-out or still-loading head — a nameless avatar, forever,
              // with no way to retry. Say so, and offer the retry.
              if (account.hasError) ...[
                const SizedBox(height: 14),
                Text(s.strings.profile.acct_load_failed,
                    textAlign: TextAlign.center, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                const SizedBox(height: 8),
                PButton(s.strings.profile.acct_retry,
                    icon: LucideIcons.rotateCcw,
                    variant: BtnVariant.soft,
                    size: BtnSize.sm,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: () => ref.invalidate(accountSummaryProvider)),
              ],
              if (summary?.handle != null && summary!.handle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('@${summary.handle}',
                    textDirection: TextDirection.ltr, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
              ],
              // `.profile-head .chip-wrap` — the patient's own chronic
              // conditions. Real on-device PHI shown to the data subject; the
              // strip stays hidden until the profile actually has conditions,
              // so nothing is ever fabricated. (There is no "patient since"
              // line: AccountSummary carries no creation date, and inventing
              // one would be fake data.)
              const _ConditionChips(),
            ]),
          ),

          // Language + country
          _ListCard(children: [
            _ListRow(
                icon: LucideIcons.languages,
                label: s.strings.profile.p_lang,
                trailing: curLang.nativeName,
                first: true,
                onTap: () => _showLanguageSheet(context)),
            _ListRow(
                icon: s.isHomeCountry ? LucideIcons.mapPin : LucideIcons.plane,
                label: s.strings.profile.p_country,
                trailing: s.country.name(kCatalog, locale: s.lang.value),
                iconBg: s.isHomeCountry ? null : T.sun500,
                iconFg: s.isHomeCountry ? null : Colors.white,
                onTap: () => _showCountrySheet(context)),
          ]),

          // Storage — opens the backup/sync sheet (connect iCloud / Google Drive).
          _ListCard(children: [
            _ListRow(
                icon: stCfg.icon,
                label: s.strings.storage.storage,
                iconBg: stCfg.bg,
                iconFg: stCfg.color,
                trailingWidget:
                    Pill(s.storageProvider.label(s.strings.storage), kind: PillKind.neutral, dot: false, ar: s.rtl),
                first: true,
                onTap: () => showStorageSync(context)),
          ]),

          // Menu
          _ListCard(
            children: rows.indexed
                .map((entry) => _ListRow(
                      icon: entry.$2.$1,
                      label: s.t(entry.$2.$2),
                      first: entry.$1 == 0,
                      onTap: entry.$2.$3 ?? () {},
                      iconBg: entry.$2.$4 ? T.dangerBg : null,
                      iconFg: entry.$2.$4 ? T.danger : null,
                      labelColor: entry.$2.$4 ? T.danger : null,
                    ))
                .toList(),
          ),

          // Account & security — real governance screens (sessions, service
          // status, account deletion). Flutter-only extras; not in the design
          // profile list. These push the module screens (their own design
          // system + re-auth).

          // → StatusScreen hop.
          _ListCard(children: [
            _ListRow(
              icon: LucideIcons.smartphone,
              label: s.strings.nav.gov_sessions,
              first: true,
              onTap: () => _pushSessionsRouted(context),
            ),
            _ListRow(
              icon: LucideIcons.activity,
              label: s.strings.nav.gov_status,
              onTap: () => _pushGovernance(context, const StatusScreen()),
            ),
            // Deletion drives declarative go_router nav (goNamed('deletion.confirm'|
            // '.cancelled') + go('/')). It is hosted in a scoped GoRouter whose
            // deletion screens nest under an invisible exit-base, so every pop and
            // every go('/') resolves — see [_pushDeletionRouted].
            _ListRow(
              icon: LucideIcons.trash2,
              label: s.strings.nav.gov_delete,
              iconBg: T.dangerBg,
              iconFg: T.danger,
              labelColor: T.danger,
              onTap: () => _pushDeletionRouted(context),
            ),
            // Dev-only API server switcher (Local / Staging / Prod / custom). Gated
            // on serverSwitchingEnabled (dev/staging), so it never renders in prod.
            // (Prod can still reach the read-only Dev Config via the shake gesture.)
            // The choice persists (reconfigure) and survives relaunch (init() in
            // main). ServerSelectorScreen owns its Scaffold + Navigator.pop, so the
            // plain _pushGovernance push is sufficient.
            if (FlavorConfig.current.serverSwitchingEnabled)
              _ListRow(
                icon: LucideIcons.server,
                label: 'Switch server (dev)',
                onTap: () => _pushGovernance(
                  context,
                  ServerSelectorScreen(
                    controller: ref.watch(balsmApiControllerProvider),
                  ),
                ),
              ),
          ]),

          // Sign out
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: PButton(s.strings.profile.p_signout,
                icon: LucideIcons.logOut,
                variant: BtnVariant.secondary,
                block: true,
                ar: s.rtl,
                color: T.danger, onTap: () async {
              // Clears tokens + best-effort server sign-out + publishes
              // UserSignedOut (the main listener clears currentUserId).
              await ref.read(signOutUseCaseProvider).call();
              if (context.mounted) s.go('welcome');
            }),
          ),
        ]));
  }
}

/// Pushes a real governance module screen (sessions / deletion / status) as a
/// full-screen route on the root navigator, wrapped in the app's [Directionality]
/// and [AdaptiveFrame] so it width-caps on tablet/desktop. Mirrors the
/// lockout / 404 → [StatusScreen] hop. The pushed screens carry their own
/// design system (BalsmAppBar / BalsmColors) and, for deletion, their own
/// re-auth — none of which is touched here.
void _pushGovernance(BuildContext context, Widget screen) {
  final s = AppScope.of(context);
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
    builder: (_) => Directionality(textDirection: s.dir, child: AdaptiveFrame(child: screen)),
  ));
}

/// Pushes the real [SessionsScreen] wrapped in a SMALL, SCOPED [GoRouter] so its
/// AppBar back button (`context.pop()`) resolves.
///
/// The prototype shell has NO GoRouter mounted (it navigates via plain
/// [Navigator] + `PatientAppState.route`), so pushing [SessionsScreen] raw makes
/// its `context.pop()` throw at runtime ("no GoRouter"). Here it is hosted in a
/// throwaway [GoRouter] whose navigator holds an invisible exit-base BENEATH the
/// screen — so `context.pop()` has something to pop to (go_router 14.x throws
/// `GoError('There is nothing to pop')` on a single-page stack). Popping the
/// screen reveals the base; [_ScopedShellExitObserver] then dismisses the outer
/// route, returning to the prototype shell. Look is unchanged
/// (Directionality + [AdaptiveFrame]), matching [_pushGovernance].
///
/// Sessions has a single route whose ONLY navigation is `context.pop()`, so the
/// one-shot exit observer suffices. Deletion drives a multi-screen declarative
/// flow (`goNamed` + `go('/')`); it uses the richer [_pushDeletionRouted] host.
void _pushSessionsRouted(BuildContext context) {
  final s = AppScope.of(context);
  final theme = Theme.of(context);
  final rootNav = Navigator.of(context, rootNavigator: true);
  final router = GoRouter(
    initialLocation: '/sessions',
    observers: [
      _ScopedShellExitObserver(() {
        // Defer to avoid re-entrant navigation during the scoped pop.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (rootNav.canPop()) rootNav.pop();
        });
      }),
    ],
    routes: [
      GoRoute(
        // Invisible exit-base: the page revealed when SessionsScreen pops.
        path: '/',
        builder: (_, __) => const SizedBox.shrink(),
        routes: [
          // Relative child so the initial stack is [base, SessionsScreen] and
          // `context.pop()` from the screen lands on the base (then exits).
          GoRoute(
            path: 'sessions',
            builder: (_, __) => const SessionsScreen(),
          ),
        ],
      ),
    ],
  );
  rootNav.push(MaterialPageRoute<void>(
    builder: (_) => MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
      builder: (_, child) => Directionality(
        textDirection: s.dir,
        child: AdaptiveFrame(child: child ?? const SizedBox.shrink()),
      ),
    ),
  ));
}

/// One-shot observer for the scoped sessions router. The only pop its navigator
/// can see is [SessionsScreen] → exit-base (the back button) — its confirm
/// dialogs use the root navigator — so the first pop means "leave sessions":
/// dismiss the outer route back to the prototype shell. One-shot so the pops
/// fired while the scoped router is torn down are ignored.
class _ScopedShellExitObserver extends NavigatorObserver {
  _ScopedShellExitObserver(this.onExit);
  final VoidCallback onExit;
  bool _done = false;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_done) return;
    _done = true;
    onExit();
  }
}

/// Pushes the real deletion flow (request → confirm → cancelled) hosted in a
/// scoped [GoRouter], so its declarative navigation resolves without the
/// prototype shell owning a router.
///
/// The deletion screens nest under an invisible exit-base at `/`:
///
///     /                       (SizedBox.shrink — the exit sentinel)
///       deletion/request      DeleteAccountScreen   [deletion.request]
///         confirm             DeletionConfirmScreen [deletion.confirm]
///         cancelled           DeletionCancelledScreen [deletion.cancelled]
///
/// so every stack always carries the base beneath the visible screen. Each
/// screen's `context.pop()` therefore has a target; `goNamed('deletion.confirm'
/// | 'deletion.cancelled')` resolve by name; and `context.go('/')` (or a back
/// out of the first screen) lands on the base — [_ScopedDeletionHost] watches
/// the router and, the moment the location returns to `/`, dismisses the outer
/// route back to the prototype shell.
void openAccountDeletion(BuildContext context) => _pushDeletionRouted(context);

void _pushDeletionRouted(BuildContext context) {
  final s = AppScope.of(context);
  final theme = Theme.of(context);
  final rootNav = Navigator.of(context, rootNavigator: true);
  rootNav.push(MaterialPageRoute<void>(
    builder: (_) => _ScopedDeletionHost(
      dir: s.dir,
      theme: theme,
      onExit: () {
        // Defer to avoid re-entrant navigation during the scoped route change.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (rootNav.canPop()) rootNav.pop();
        });
      },
    ),
  ));
}

/// Owns the throwaway [GoRouter] for the deletion flow and exits back to the
/// shell when the scoped location returns to the invisible base (`/`). Stateful
/// so the router + its delegate listener live and die with the pushed route.
class _ScopedDeletionHost extends StatefulWidget {
  const _ScopedDeletionHost({
    required this.dir,
    required this.theme,
    required this.onExit,
  });
  final TextDirection dir;
  final ThemeData theme;
  final VoidCallback onExit;
  @override
  State<_ScopedDeletionHost> createState() => _ScopedDeletionHostState();
}

class _ScopedDeletionHostState extends State<_ScopedDeletionHost> {
  late final GoRouter _router;
  bool _exited = false;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/deletion/request',
      routes: [
        GoRoute(
          // Invisible exit sentinel: reaching `/` means "leave deletion".
          path: '/',
          builder: (_, __) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: 'deletion/request',
              name: 'deletion.request',
              builder: (_, __) => const DeleteAccountScreen(),
              // Nested so the stack is [base, request, …] and each pop resolves.
              routes: [
                GoRoute(
                  path: 'confirm',
                  name: 'deletion.confirm',
                  builder: (_, __) => const DeletionConfirmScreen(),
                ),
                GoRoute(
                  path: 'cancelled',
                  name: 'deletion.cancelled',
                  builder: (_, __) => const DeletionCancelledScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    _router.routerDelegate.addListener(_onRouteChanged);
  }

  void _onRouteChanged() {
    if (_exited) return;
    if (_router.routerDelegate.currentConfiguration.uri.path == '/') {
      _exited = true;
      widget.onExit();
    }
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChanged);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: widget.theme,
      routerConfig: _router,
      builder: (_, child) => Directionality(
        textDirection: widget.dir,
        child: AdaptiveFrame(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => PCard(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(T.rLg),
          child: Column(children: children),
        ),
      );
}

class _ListRow extends StatelessWidget {
  const _ListRow(
      {required this.icon,
      required this.label,
      this.trailing,
      this.trailingWidget,
      this.onTap,
      this.iconBg,
      this.iconFg,
      this.labelColor,
      this.first = false});
  final IconData icon;
  final String label;
  final String? trailing;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
  final Color? iconBg;
  final Color? iconFg;
  final Color? labelColor;
  final bool first;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // `.list-row:active { background: ink50 }`.
    return PressHighlight(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: T.ink100))),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(children: [
          IconSquare(icon, bg: iconBg ?? s.accent.bg, fg: iconFg ?? s.accent.d, size: 34, iconSize: 19, radius: T.rSm),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w500, color: labelColor ?? T.fg1))),
          if (trailingWidget != null) trailingWidget!,
          if (trailing != null)
            Padding(
                padding: const EdgeInsets.only(right: 8, left: 8),
                child:
                    Text(trailing!, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3))),
          Chevron(rtl: s.rtl),
        ]),
      ),
    );
  }
}

/// `.profile-head .chip-wrap` — the patient's chronic conditions as centred
/// badges (`--balsm-ink-100` on `--balsm-ink-700`). Renders nothing until the
/// on-device health profile actually holds conditions.
class _ConditionChips extends ConsumerWidget {
  const _ConditionChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final conditions = ref.watch(healthProfileProvider).valueOrNull?.conditions ?? const [];
    if (conditions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in conditions)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: T.ink100, borderRadius: BorderRadius.circular(T.rPill)),
              child: Text(c.name, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.ink700)),
            ),
        ],
      ),
    );
  }
}

// ── Language sheet ───────────────────────────────────────────
void _showLanguageSheet(BuildContext context) {
  final s = AppScope.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x5C14202B),
    builder: (ctx) => Directionality(
      textDirection: s.dir,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _SheetShell(title: s.strings.settings.choose_lang, children: [
            ...LanguageCode.supported.indexed.map((e) => _SelectRow(
                  label: e.$2.nativeName,
                  sub: e.$2.name(kCatalog),
                  code: e.$2.value.toUpperCase(),
                  selected: e.$2 == s.lang,
                  last: e.$1 == LanguageCode.supported.length - 1,
                  badge: e.$2.isFullySupported ? s.strings.settings.lang_full : s.strings.settings.lang_beta,
                  badgeOk: e.$2.isFullySupported,
                  enabled: e.$2.isFullySupported,
                  onTap: e.$2.isFullySupported
                      ? () {
                          s.setLang(e.$2);
                          Navigator.pop(ctx);
                        }
                      : null,
                )),
          ]),
        ),
      ),
    ),
  );
}

void _showCountrySheet(BuildContext context) {
  final s = AppScope.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x5C14202B),
    builder: (ctx) => Directionality(
      textDirection: s.dir,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _SheetShell(
              title: s.strings.settings.choose_country,
              subtitle: s.strings.settings.travel_help,
              children: [
                ...CountryCode.known.indexed.map((e) => _SelectRow(
                      label: e.$2.name(kCatalog, locale: s.lang.value),
                      sub: '${e.$2.dialCode}   ${s.strings.emergency.emergency} ${e.$2.emergencyNumber}',
                      code: e.$2.value.toUpperCase(),
                      codeMono: true,
                      selected: e.$2 == s.country,
                      last: e.$1 == CountryCode.known.length - 1,
                      badge: e.$2 == kHomeCountry ? s.strings.settings.home_country : null,
                      badgeOk: true,
                      onTap: () {
                        s.setCountry(e.$2);
                        Navigator.pop(ctx);
                      },
                    )),
              ]),
        ),
      ),
    ),
  );
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, this.subtitle, required this.children});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      decoration:
          const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
      padding: const EdgeInsets.only(bottom: 38),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(
            width: 38, height: 4, decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
        const SizedBox(height: 12),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: Text(title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)))
            ])),
        if (subtitle != null)
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(subtitle!, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)))),
        const SizedBox(height: 8),
        Flexible(
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(horizontal: 12), children: children)),
      ]),
    );
  }
}

class _SelectRow extends StatelessWidget {
  const _SelectRow(
      {required this.label,
      this.sub,
      this.code,
      this.codeMono = false,
      this.selected = false,
      this.last = false,
      this.badge,
      this.badgeOk = true,
      this.enabled = true,
      this.onTap});
  final String label;
  final String? sub;

  /// Leading 44px tile — the language/ISO code, tinted when the row is active.
  final String? code;
  final bool codeMono;
  final bool selected;

  /// Last row in the list: no hairline underneath.
  final bool last;
  final String? badge;
  final bool badgeOk;
  final bool enabled;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: PressHighlight(
        onTap: onTap,
        radius: T.rMd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: T.ink50))),
          child: Row(children: [
            if (code != null) ...[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: selected ? s.accent.bg : T.ink50, borderRadius: BorderRadius.circular(T.rMd)),
                child: codeMono
                    ? Text(code!,
                        style: Typo.num(size: 15, weight: FontWeight.w600, color: selected ? s.accent.d : T.fg2))
                    : Text(code!,
                        style: Typo.display(ar: s.rtl)
                            .copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: selected ? s.accent.d : T.fg2)),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(sub!, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                  ),
              ]),
            ),
            if (badge != null)
              Padding(
                padding: const EdgeInsets.only(right: 8, left: 8),
                child: Pill(badge!, kind: badgeOk ? PillKind.neutral : PillKind.warn, dot: false, ar: s.rtl),
              ),
            if (selected) Icon(LucideIcons.checkCircle2, size: 22, color: s.accent.main),
          ]),
        ),
      ),
    );
  }
}
