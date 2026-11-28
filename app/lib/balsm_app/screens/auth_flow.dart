import 'dart:async';

import 'package:account/account.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../assets.dart';
import '../auth/auth_flow_controllers.dart';
import '../auth/go_online_controller.dart';
import '../dev/shake_to_dev_config.dart';
import '../kit.dart';
import '../responsive.dart';
import '../routes.dart';
import '../widgets/auth_fields.dart';
import '../widgets/language_pill.dart';
import '../widgets/legal_sheet.dart';
import 'remove_device_account.dart';
import 'social_sign_in_block.dart';
import 'walkthrough_screen.dart';

// A step dot growing into the active pill.
const _stepDotAnimation = Duration(milliseconds: 250);

/// Routes the auth flow by `state.route`.
class AuthRouter extends StatelessWidget {
  const AuthRouter({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return switch (s.route) {
      AppRoutes.walkthrough => const WalkthroughScreen(),
      AppRoutes.phone => const _PhoneScreen(),
      AppRoutes.otp => const _OtpScreen(),
      AppRoutes.profileSetup => const _ProfileSetupScreen(),
      AppRoutes.unlock => const _UnlockScreen(),
      AppRoutes.mergeOrDiscard => const _MergeOrDiscardScreen(),
      _ => const _WelcomeScreen(),
    };
  }
}

// ── Welcome ──────────────────────────────────────────────────
class _WelcomeScreen extends ConsumerStatefulWidget {
  const _WelcomeScreen();
  @override
  ConsumerState<_WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<_WelcomeScreen> {
  void _start(PatientAppState s, AuthIntent intent) {
    s
      ..setAuthIntent(intent)
      ..go(AppRoutes.phone);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // The design's 168px lockup fits a tall phone. Below 860 high (a Galaxy
    // A17 is 832, less its status and navigation bars) the bottom-anchored
    // column is taller than the space, scrolls up, and the logo ends up pinned
    // under the status bar. A smaller lockup and a tighter gap give it room.
    final short = MediaQuery.sizeOf(context).height < 860;
    return BalsmWelcomeBackground(
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ContentColumn(
                maxWidth: 440,
                maxHeight: kContentBlockMaxHeight,
                child: Column(
                  children: [
                    // `.wbody { margin-top: auto }` — lockup + CTAs sit on the cream
                    // fade; watercolor fills the space above.
                    // `.wbody { margin-top: auto }` with a safety valve. The 168px
                    // lockup, the Apple and Google buttons and an error line together
                    // overflow a 402x900 viewport.
                    // reverse: true keeps the content bottom-anchored exactly as the
                    // Spacer did, and scrolls instead of clipping when it cannot fit.
                    Expanded(
                      child: SingleChildScrollView(
                        reverse: true,
                        child: Padding(
                          // `.wbody { padding-bottom: 36px }`, trimmed on a short phone
                          // so the block sits down by the trust row, not high above it.
                          padding: EdgeInsetsDirectional.fromSTEB(28, 0, 28, short ? 20 : 36),
                          child: Column(
                            children: [
                              SvgPicture.asset(
                                Assets.brand_logo_vertical,
                                width: short ? 120 : 168,
                                height: short ? 120 : 168,
                              ),
                              SizedBox(height: short ? 18 : 26),
                              _SteadyLines(
                                lines: 2,
                                style: Typo.display(ar: s.rtl),
                                child: Text(
                                  s.strings.onboarding.w_title,
                                  textAlign: TextAlign.center,
                                  style: Typo.display(ar: s.rtl),
                                ),
                              ),
                              const SizedBox(height: 14),
                              // `.wsub { max-width: 34ch }` — hold the sub to a comfortable
                              // measure instead of the full 28px-gutter width. 34ch against
                              // the 16px body face is ~326 logical px.
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 326),
                                child: _SteadyLines(
                                  lines: 3,
                                  style: Typo.body(ar: s.rtl),
                                  child: Text(
                                    s.strings.onboarding.w_sub,
                                    textAlign: TextAlign.center,
                                    style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textSecondary),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              // auth.jsx WelcomeScreen: Apple and Google first, then "or
                              // with email". Nothing, and no space, where no provider is
                              // offered.
                              const SocialSignInBlock(compact: false),
                              // One button per way in, so the next screen knows whether it
                              // registers, signs in or creates a device-only account.
                              PButton(
                                s.strings.onboarding.w_create,
                                large: true,
                                block: true,
                                accent: s.accent,
                                ar: s.rtl,
                                onTap: () => _start(s, AuthIntent.signUp),
                              ),
                              const SizedBox(height: 10),
                              PButton(
                                s.strings.onboarding.w_signin,
                                variant: BtnVariant.secondary,
                                large: true,
                                block: true,
                                accent: s.accent,
                                ar: s.rtl,
                                onTap: () => _start(s, AuthIntent.signIn),
                              ),
                              const SizedBox(height: 10),
                              PButton(
                                s.strings.onboarding.w_device,
                                icon: LucideIcons.smartphone,
                                variant: BtnVariant.ghost,
                                size: BtnSize.md,
                                block: true,
                                accent: s.accent,
                                ar: s.rtl,
                                onTap: () => _start(s, AuthIntent.deviceOnly),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 22),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        // Labels are translated and wrap to different line counts;
                        // top alignment keeps the three icons on one baseline.
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Trust(s, LucideIcons.smartphone, s.strings.settings.trust_device),
                          const SizedBox(width: 22),
                          _Trust(s, LucideIcons.lock, s.strings.settings.trust_private),
                          const SizedBox(width: 22),
                          _Trust(s, LucideIcons.cloudOff, s.strings.settings.trust_offline),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Dev Config, reachable before anyone signs in. The shake gesture
                        // opens the same screen, but a shake is not available on a
                        // simulator and not discoverable on a device, and the server this
                        // build talks to is the first thing that goes wrong. Never in
                        // prod: `serverSwitchingEnabled` is dev + staging only.
                        // Only where a shake can't reach Dev Config: emulators,
                        // simulators, desktop and web. A real phone or tablet shakes,
                        // and the pill there is clutter (hidden while the check runs).
                        if (FlavorConfig.current.serverSwitchingEnabled && ref.watch(canShakeProvider).value == false)
                          _DevConfigPill(onClosed: () => setState(() {})),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            // auth.jsx WelcomeScreen: the language switch rides the top end
            // corner, a light pill over the watercolour.
            const PositionedDirectional(top: 12, end: 16, child: LanguagePill()),
          ],
        ),
      ),
    );
  }
}

/// Opens Dev Config from the welcome screen, labelled with the server this
/// build is actually talking to.
///
/// The host rather than the preset name: "Local" reads the same whether it
/// resolved to this machine, to an emulator's host alias, or to nothing at
/// all, and which one it is decides whether anything works. Shown only where
/// the server can be switched — dev and staging — so it never reaches a
/// patient.
class _DevConfigPill extends ConsumerWidget {
  const _DevConfigPill({required this.onClosed});

  /// Dev Config can repoint the client while this pill is showing where it
  /// points, so the caller rebuilds when it closes.
  final VoidCallback onClosed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The live client where there is one, the configured default where there
    // is not: a widget test or a docshots run builds this screen in a scope
    // that never overrode the controller, and a dev affordance must not be
    // what takes the welcome screen down.
    String base;
    try {
      base = ref.watch(balsmApiControllerProvider).client.baseUrl;
    } on Object catch (_) {
      base = FlavorConfig.current.defaultServer.apiBaseUrl;
    }
    final url = Uri.tryParse(base);
    final label = url == null || url.host.isEmpty ? '?' : (url.hasPort ? '${url.host}:${url.port}' : url.host);

    return Semantics(
      button: true,
      label: 'Dev config',
      child: MinTapTarget(
        child: Pressable(
          onTap: () async {
            await openDevConfig(context);
            onClosed();
          },
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.scrim,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: AppColors.white30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.wrench, size: 16, color: AppColors.white),
                const SizedBox(width: 7),
                // Narrow enough to sit beside the language pill on a 402px screen;
                // a long staging host ellipsises rather than overflowing the row.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.bodySm().copyWith(fontWeight: FontWeight.w700, color: AppColors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Auth header with step dots ───────────────────────────────
class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.onBack, this.step, this.total = 3});
  final VoidCallback onBack;

  /// 1-based; null shows no dots (sign-in and device-only are one step).
  final int? step;
  final int total;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 12),
      child: Row(
        children: [
          RoundBtn(icon: backArrow(context), semanticLabel: s.strings.common.a11y_back, onTap: onBack),
          const Spacer(),
          if (step case final step?)
            Row(
              children: [
                for (var i = 0; i < total; i++)
                  AnimatedContainer(
                    duration: _stepDotAnimation,
                    margin: const EdgeInsetsDirectional.only(start: 4),
                    width: i == step - 1 ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i <= step - 1 ? s.accent.main : AppColors.ink200,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Under-18 soft block ──────────────────────────────────────
// Destination when the fail-closed age gate rejects (< 18). Prototype-native
// styling (kit widgets / tokens) so it matches the rest of the auth flow; the
// real module's screen uses the core design system, so we mirror it here. Pushed
// as a route — its back/CTA simply return to the sign-up step. No session is
// ever created for an under-18 user.
class _UnderEighteenScreen extends StatelessWidget {
  const _UnderEighteenScreen();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          maxHeight: kContentBlockMaxHeight,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 12),
                child: Row(
                  children: [
                    RoundBtn(
                      icon: backArrow(context),
                      semanticLabel: s.strings.common.a11y_back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: s.accent.bg, shape: BoxShape.circle),
                      child: Icon(LucideIcons.shieldAlert, size: 38, color: s.accent.main),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      s.strings.settings.na_not_available,
                      textAlign: TextAlign.center,
                      style: Typo.display(ar: s.rtl),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.strings.onboarding.age_gate_body,
                      textAlign: TextAlign.center,
                      style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    PButton(
                      s.strings.settings.na_notify_me,
                      large: true,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 8),
                    // G6 / SC-011a: a hard-blocking screen must expose a no-auth
                    // support channel + the public status page. Opens the in-app
                    // PUBLIC status page (`{BASE_URL}/status`), which carries the
                    // mailto support link — reachable in ≤2 taps, no auth.
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const StatusScreen(),
                        ),
                      ),
                      icon: const Icon(LucideIcons.lifeBuoy, size: 18),
                      label: Text(
                        s.strings.settings.na_status_support,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Email + password ─────────────────────────────────────────
// Claude Design auth.jsx `PhoneScreen` (basic auth). Which Welcome button led
// here decides the screen ([PatientAppState.authIntent]):
//   sign up      email + new password → a code confirms the email → password set
//   sign in      email + password
//   device only  email + lock password, created on this device, no code
// The patient switches between sign up and sign in with the link at the foot.

class _PhoneScreen extends ConsumerStatefulWidget {
  const _PhoneScreen();
  @override
  ConsumerState<_PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<_PhoneScreen> {
  // View state only: text controllers + visibility toggle. Submit flow lives
  // in [CredentialsController].
  final ctrl = TextEditingController();
  final pwCtrl = TextEditingController();

  /// True while [_createOnDevice] is in flight. Separate from [_submitting] —
  /// that one reflects [credentialsControllerProvider], which the device-only
  /// path never touches.
  bool _creating = false;

  /// Set when [_createOnDevice] fails (e.g. secure-storage write failed).
  /// Never the exception's own text — a generic retry prompt only.
  String? _deviceError;

  AuthIntent get _intent => AppScope.of(context).authIntent;
  bool get _device => _intent == AuthIntent.deviceOnly;
  bool get _signUp => _intent == AuthIntent.signUp;

  /// The error line to show under the fields: the device-only failure while
  /// in that mode, the online controller's error otherwise.
  String? get _displayError => _device ? _deviceError : _error;

  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    // Coming back from the code step — the code never arrived, or it went to a
    // mistyped address — should not mean retyping both fields. A blank password
    // box invites a different password, which then fails for a new reason.
    // Cleared for real on sign-out and once a verified code has consumed it.
    final s = AppScope.of(context);
    ctrl.text = s.authEmail;
    pwCtrl.text = s.authPassword ?? '';
  }

  bool _showPw = false;

  bool get _submitting => ref.read(credentialsControllerProvider).submitting;

  String? get _error {
    final e = ref.read(credentialsControllerProvider).error;
    if (e == null) return null;
    final s = AppScope.of(context);
    return switch (e.kind) {
      AuthErrorKind.lockout => s.strings.auth.auth_locked_retry(e.lockoutSecs.toString()),
      AuthErrorKind.invalidCredentials => s.strings.auth.pw_invalid_creds,
      AuthErrorKind.emailRegistered => s.strings.auth.signup_email_registered,
      AuthErrorKind.server => e.message,
    };
  }

  @override
  void dispose() {
    ctrl.dispose();
    pwCtrl.dispose();
    super.dispose();
  }

  // D5: 8 characters minimum in every mode — the design says 6, but an
  // offline password can never be server-side rate-limited, so the product
  // owner raised the floor for everyone, not just device-only.
  bool get ok {
    final emailOk = isPlausibleEmail(ctrl.text);
    return emailOk && pwCtrl.text.length >= OfflineAccountService.minPasswordLength;
  }

  bool get _busy => _submitting || _creating;

  void _showForgotPassword(String email) {
    final s = AppScope.of(context);
    unawaited(
      showAppSheet<void>(
        context,
        builder: (_) => _ForgotPasswordSheet(initialEmail: email, s: s),
      ),
    );
  }

  /// Sign up ⇄ sign in, keeping what was typed.
  void _switchTo(PatientAppState s, AuthIntent intent) {
    if (_busy) return;
    // Rebuilding the controller clears a stale error from the other mode.
    ref.invalidate(credentialsControllerProvider);
    s.setAuthIntent(intent);
  }

  void _submit(PatientAppState s) {
    if (!ok || _busy) return;
    switch (_intent) {
      case AuthIntent.signIn:
        unawaited(_signIn(s));
      case AuthIntent.signUp:
        unawaited(_register(s));
      case AuthIntent.deviceOnly:
        unawaited(_createOnDevice(s));
    }
  }

  Future<void> _signIn(PatientAppState s) async {
    final address = ctrl.text.trim();
    final controller = ref.read(credentialsControllerProvider.notifier);

    final signedIn = await controller.signIn(email: address, password: pwCtrl.text);
    if (!mounted) return;
    if (signedIn) {
      // Credentials are proven good — this is what raises the platform
      // "Save password?" prompt. Nothing before this point should, or a
      // typo gets offered to the keychain.
      TextInput.finishAutofillContext();
      s.setAuthContact(method: AuthMethod.email, email: address);
      unawaited(enterAfterSignIn(context, ref, s));
      return;
    }

    // Nothing proven: never offer the typed password to the keychain.
    TextInput.finishAutofillContext(shouldSave: false);

    // Felt, not only shown. The message is visible and announced to a screen
    // reader; a patient who is deaf and not using one has neither a sound nor
    // speech, and a buzz says "that did not work" without their having to be
    // looking at the one line where it says so.
    unawaited(HapticFeedback.heavyImpact());

    // The refusal never says whether the address has an account — the server
    // does not tell the app, so the error reads the same either way, and the
    // "New to Balsm?" line below is always there for a newcomer.
  }

  /// Sign up: send the code that confirms the email, then move to the code
  /// step. The password waits in memory until the code proves the address.
  ///
  /// The server normally sends the code whether or not the address already
  /// has an account and never says which; a code for an existing account
  /// signs in to it, and the code step then asks whether to adopt the new
  /// password. While the server holds sign-up strict (email quota or abuse)
  /// it answers "already registered" instead, shown under the field, with the
  /// sign-in link right below.
  Future<void> _register(PatientAppState s) async {
    final address = ctrl.text.trim();
    final sent = await ref
        .read(credentialsControllerProvider.notifier)
        .requestSignupOtp(email: address, countryCode: s.country.value);
    if (!mounted || !sent) return;
    s
      ..setAuthContact(method: AuthMethod.email, email: address)
      // Held only for the length of the flow: if the code proves a NEW account
      // it becomes that account's password, and if it proves an existing one the
      // patient is asked whether to adopt it. Cleared either way.
      ..authPassword = pwCtrl.text
      ..go(AppRoutes.otp);
  }

  /// Device-only path: no network round-trip, no OTP. Creates the account
  /// entirely on-device, then runs the same disclosure gate everyone else
  /// goes through — while device-only, the disclosure API call is refused
  /// locally by the interceptor and tolerated; acceptance is stored on-device.
  Future<void> _createOnDevice(PatientAppState s) async {
    if (_creating) return;
    setState(() {
      _creating = true;
      _deviceError = null;
    });
    try {
      await ref.read(offlineAccountServiceProvider).create(email: ctrl.text.trim(), password: pwCtrl.text);
      if (!mounted) return;
      s.setAccountMode(AccountMode.deviceOnly);
      TextInput.finishAutofillContext();
      await enterAfterSignIn(context, ref, s);
    } on Object catch (_) {
      // Never the exception's own text (could be a secure-storage failure —
      // no reason to surface or log its message); a generic retry is enough.
      if (mounted) setState(() => _deviceError = s.strings.auth.device_create_failed);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  /// "New to Balsm? Create an account" / "Have an account? Sign in".
  Widget _switchLine(PatientAppState s, {required String prompt, required String action, required AuthIntent to}) {
    final style = Typo.meta(ar: s.rtl);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: Text('$prompt ', style: style)),
        Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _busy ? null : () => _switchTo(s, to),
            // 48pt tall, only as wide as the words, so it stays on the prompt's line.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: BalsmWindow.touchTarget, minHeight: BalsmWindow.touchTarget),
              child: Align(
                widthFactor: 1,
                child: Text(action, style: style.copyWith(color: s.accent.main, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final a = s.strings.auth;
    // Subscribe: the bridge getters above read this provider's current state.
    ref.watch(credentialsControllerProvider);
    final (title, help, cta) = switch (s.authIntent) {
      AuthIntent.signUp => (a.signup_title, a.signup_help, a.signup_send),
      AuthIntent.signIn => (a.signin_title, a.signin_help, _submitting ? a.pw_signing_in : a.pw_signin),
      AuthIntent.deviceOnly => (a.device_title, a.device_help, a.device_create),
    };
    return ColoredBox(
      color: AppColors.cream50,
      // Groups the email and password fields into one credential set, so the
      // platform manager saves them as a pair rather than two loose values.
      child: AutofillGroup(
        child: SafeArea(
          child: ContentColumn(
            maxWidth: 440,
            maxHeight: kContentBlockMaxHeight,
            child: Column(
              children: [
                // Sign up is two steps (this, then the code); the others are one.
                _AuthHeader(onBack: () => s.go(AppRoutes.welcome), step: _signUp ? 1 : null, total: 2),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(title, style: Typo.title(ar: s.rtl)),
                        const SizedBox(height: 8),
                        Text(help, style: Typo.body(ar: s.rtl)),
                        const SizedBox(height: 24),
                        // auth.jsx PhoneScreen: the providers above the email field,
                        // for an account that lives on the server (not device-only).
                        if (!_device) const SocialSignInBlock(compact: true),
                        _Label(s.strings.emergency.em_label, ar: s.rtl),
                        const SizedBox(height: 8),
                        AuthInput(
                          controller: ctrl,
                          id: 'emailField',
                          hint: s.strings.emergency.em_ph,
                          keyboard: TextInputType.emailAddress,
                          forceLtr: true,
                          accent: s.accent,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _Label(_device ? a.device_pw_label : a.pw_label, ar: s.rtl),
                            // Sign in only: a new account has no password to forget yet,
                            // and a device-only account has no server-side record to
                            // recover one from (see the warning card below).
                            if (s.authIntent == AuthIntent.signIn)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _submitting ? null : () => _showForgotPassword(ctrl.text.trim()),
                                // 48pt target around 13pt text: the label row grows, the
                                // link does not look any bigger.
                                child: MinTapTarget(
                                  child: Text(
                                    a.forgot_pw,
                                    style: Typo.meta(ar: s.rtl)
                                        .copyWith(color: s.accent.main, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AuthInput(
                          controller: pwCtrl,
                          id: 'passwordField',
                          // D5: 8 characters minimum in every mode — shown as the
                          // hint instead of a generic placeholder.
                          hint: a.pw_min_hint,
                          obscure: !_showPw,
                          forceLtr: true,
                          accent: s.accent,
                          // A new password where one is being chosen, so the
                          // platform can suggest a strong one; the saved one at sign in.
                          autofillHints: [
                            if (s.authIntent == AuthIntent.signIn)
                              AutofillHints.password
                            else
                              AutofillHints.newPassword,
                          ],
                          // Icon-only, so a screen reader has nothing to read, and
                          // 17px is well under a fingertip.
                          suffixIcon: Semantics(
                            button: true,
                            label: _showPw ? s.strings.common.a11y_hide_pw : s.strings.common.a11y_show_pw,
                            child: GestureDetector(
                              // Opaque, so the whole slot the decoration reserves is
                              // tappable rather than just the glyph.
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _showPw = !_showPw),
                              child: Icon(
                                _showPw ? LucideIcons.eyeOff : LucideIcons.eye,
                                size: 17,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_device) ...[
                          const SizedBox(height: 12),
                          _DeviceOnlyWarning(text: a.device_warning, ar: s.rtl),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 24),
                  child: Column(
                    children: [
                      if (_displayError case final displayError?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              displayError,
                              textAlign: TextAlign.center,
                              style:
                                  Typo.meta(ar: s.rtl).copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      Opacity(
                        opacity: ok && !_busy ? 1 : 0.4,
                        child: PButton(
                          cta,
                          large: true,
                          block: true,
                          accent: s.accent,
                          ar: s.rtl,
                          onTap: ok && !_busy ? () => _submit(s) : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      switch (s.authIntent) {
                        AuthIntent.signUp =>
                          _switchLine(s, prompt: a.have_account, action: a.pw_signin, to: AuthIntent.signIn),
                        AuthIntent.signIn =>
                          _switchLine(s, prompt: a.new_here, action: a.create_account, to: AuthIntent.signUp),
                        AuthIntent.deviceOnly => const SizedBox.shrink(),
                      },
                      if (s.authIntent != AuthIntent.signIn) ...[
                        const SizedBox(height: 8),
                        TermsLine(s: s),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Unlock (device-only cold start) ──────────────────────────
// [PatientAppState.load] boots a device-only account straight here instead
// of the welcome screen (and a pending merge too, before its merge screen).
// "Forgot password? Start over" removes the account and its data after two
// confirmations — the password can't be recovered. No DesignSync design exists for this screen
// yet — it is built from _PhoneScreen's own pieces (cream background, the
// password AuthInput with its show/hide eye, the device-only warning card) so it
// at least looks native meanwhile; ask for a real design before release (see
// docs/offline-account.md, "Unlock").
class _UnlockScreen extends ConsumerStatefulWidget {
  const _UnlockScreen();
  @override
  ConsumerState<_UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<_UnlockScreen> {
  final _pwCtrl = TextEditingController();
  bool _showPw = false;
  bool _busy = false;

  /// Set when [OfflineAccountService.unlock] refuses the password. Cleared on
  /// the next attempt.
  String? _error;

  /// Non-null while locked out; cleared once the countdown reaches zero.
  DateTime? _lockedUntil;
  int _secsLeft = 0;
  Timer? _timer;

  bool get _locked => _lockedUntil != null;

  @override
  void initState() {
    super.initState();
    unawaited(_checkLockout());
  }

  Future<void> _checkLockout() async {
    final locked = await ref.read(offlineAccountServiceProvider).lockout();
    if (!mounted || locked == null) return;
    _startLockout(locked.until);
  }

  /// Seeds the countdown from a single `DateTime.now()` read, then ticks the
  /// local counter down once a second rather than re-reading the clock on
  /// every tick. The seconds remaining round UP (a 29.9s wait still reads
  /// "30s") — never show less time than is actually left.
  void _startLockout(DateTime until) {
    _timer?.cancel();
    final ms = until.difference(DateTime.now().toUtc()).inMilliseconds;
    final secs = ms <= 0 ? 0 : (ms / 1000).ceil();
    if (secs <= 0) {
      setState(() => _lockedUntil = null);
      return;
    }
    setState(() {
      _lockedUntil = until;
      _secsLeft = secs;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secsLeft -= 1;
        if (_secsLeft <= 0) {
          _lockedUntil = null;
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_locked || _busy || _pwCtrl.text.isEmpty) return;
    final s = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(offlineAccountServiceProvider).unlock(_pwCtrl.text);
      if (!mounted) return;
      switch (result) {
        case Unlocked():
          _pwCtrl.clear();
          // A go-online that found an existing account is still waiting for
          // its merge-or-discard choice: that screen, not the app.
          final pendingMerge = await ref.read(offlineAccountServiceProvider).pendingMerge();
          if (!mounted) return;
          s.go(pendingMerge ? AppRoutes.mergeOrDiscard : AppRoutes.app);
        case WrongPassword():
          _pwCtrl.clear();
          setState(() => _error = s.strings.auth.unlock_wrong);
        case LockedUntil(:final until):
          _pwCtrl.clear();
          _startLockout(until);
      }
    } on Object catch (_) {
      // Never the exception's own text (could be a secure-storage failure —
      // no reason to surface or log its message); a generic retry is enough.
      if (mounted) {
        _pwCtrl.clear();
        setState(() => _error = s.strings.auth.unlock_failed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Forgot password? Start over": the password can't be recovered (spec
  /// §1, out of scope), so the only way forward is to delete the account and
  /// its data. Two explicit confirmations first.
  Future<void> _startOver() async {
    if (_busy) return;
    final s = AppScope.of(context);
    if (!await confirmRemoveDeviceAccount(context, s, forgotPassword: true) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await removeDeviceAccount(ref, s);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = s.strings.offline.merge_failed(s.gender);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ok = _pwCtrl.text.isNotEmpty && !_locked && !_busy;
    return ColoredBox(
      color: AppColors.cream50,
      child: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          maxHeight: kContentBlockMaxHeight,
          child: Column(
            children: [
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(header: true, child: Text(s.strings.auth.unlock_title, style: Typo.title(ar: s.rtl))),
                      const SizedBox(height: 8),
                      Text(s.strings.auth.unlock_help, style: Typo.body(ar: s.rtl)),
                      const SizedBox(height: 24),
                      _Label(s.strings.auth.pw_label, ar: s.rtl),
                      const SizedBox(height: 8),
                      AuthInput(
                        controller: _pwCtrl,
                        id: 'unlockPasswordField',
                        hint: s.strings.auth.pw_ph,
                        obscure: !_showPw,
                        forceLtr: true,
                        accent: s.accent,
                        autofillHints: const [AutofillHints.password],
                        suffixIcon: Semantics(
                          button: true,
                          label: _showPw ? s.strings.common.a11y_hide_pw : s.strings.common.a11y_show_pw,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _showPw = !_showPw),
                            child: Icon(
                              _showPw ? LucideIcons.eyeOff : LucideIcons.eye,
                              size: 17,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      _DeviceOnlyWarning(text: s.strings.auth.device_warning, ar: s.rtl),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 24),
                child: Column(
                  children: [
                    if (_locked)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            s.strings.auth.unlock_locked(_secsLeft.toString()),
                            textAlign: TextAlign.center,
                            style: Typo.meta(ar: s.rtl).copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    else if (_error case final error?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            textAlign: TextAlign.center,
                            style: Typo.meta(ar: s.rtl).copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    Opacity(
                      opacity: ok ? 1 : 0.4,
                      child: PButton(
                        s.strings.auth.unlock_btn,
                        large: true,
                        block: true,
                        accent: s.accent,
                        ar: s.rtl,
                        onTap: ok ? _submit : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    PButton(
                      s.strings.auth.unlock_forgot,
                      variant: BtnVariant.ghost,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: _busy ? null : _startOver,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Merge or discard (email already has an account) ──────────
// PROVISIONAL — pending the DesignSync design (spec §3); release stays blocked
// on it. Built from _UnlockScreen's pieces (cream background, title/help, the
// info card, a primary + secondary action) so it looks native meanwhile; see
// docs/offline-account.md, "Merge or discard".
//
// Reached from the go-online sheet, and at boot while `balsm.pending_merge`
// is set (PatientAppState.load), so a choice interrupted by a crash comes back
// here and is simply run again.
class _MergeOrDiscardScreen extends ConsumerStatefulWidget {
  const _MergeOrDiscardScreen();
  @override
  ConsumerState<_MergeOrDiscardScreen> createState() => _MergeOrDiscardScreenState();
}

class _MergeOrDiscardScreenState extends ConsumerState<_MergeOrDiscardScreen> {
  bool _busy = false;
  String? _error;

  /// A choice a previous attempt started and did not finish. Once one has
  /// begun only it is offered — e.g. after a merge's rows committed, Remove
  /// would delete the merged records' attachments.
  MergeChoice? _started;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStarted());
  }

  Future<void> _loadStarted() async {
    MergeChoice? c;
    try {
      c = await ref.read(goOnlineControllerProvider).pendingChoice();
    } on Object catch (_) {
      return;
    }
    if (mounted && c != _started) setState(() => _started = c);
  }

  Future<void> _merge() => _run((c) => c.merge());

  /// Destructive: a second, explicit confirmation before anything is deleted
  /// (also when finishing a discard that already started).
  Future<void> _discard() async {
    if (_busy) return;
    final s = AppScope.of(context);
    final ok = await showAppSheet<bool>(context, builder: (_) => _DiscardConfirmSheet(s: s));
    if (ok != true || !mounted) return;
    await _run((c) => c.discard());
  }

  Future<void> _run(Future<AppResult<void>> Function(GoOnlineController c) action) async {
    if (_busy) return;
    final s = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    AppResult<void>? r;
    try {
      r = await action(ref.read(goOnlineControllerProvider));
    } on Object catch (_) {
      // Never the exception's text; the choice can simply be made again.
      r = null;
    }
    if (!mounted) return;
    if (r != null && r.isSuccess) {
      s.setAccountMode(AccountMode.online);
      unawaited(HapticFeedback.lightImpact());
      await enterAfterSignIn(context, ref, s);
      if (mounted) setState(() => _busy = false);
      return;
    }
    unawaited(HapticFeedback.heavyImpact());
    setState(() {
      _busy = false;
      _error = s.strings.offline.merge_failed(s.gender);
    });
    await _loadStarted();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final st = s.strings.offline;
    return ColoredBox(
      color: AppColors.cream50,
      child: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          maxHeight: kContentBlockMaxHeight,
          child: Column(
            children: [
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(header: true, child: Text(st.merge_title, style: Typo.title(ar: s.rtl))),
                      const SizedBox(height: 8),
                      Text(st.merge_help(s.gender), style: Typo.body(ar: s.rtl)),
                      const SizedBox(height: 24),
                      _DeviceOnlyWarning(text: st.merge_note, ar: s.rtl),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 24),
                child: Column(
                  children: [
                    if (_error case final error?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            textAlign: TextAlign.center,
                            style: Typo.meta(ar: s.rtl).copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    Opacity(
                      opacity: _busy ? 0.4 : 1,
                      child: Column(
                        children: [
                          if (_started != MergeChoice.discard)
                            PButton(
                              st.merge_btn,
                              large: true,
                              block: true,
                              accent: s.accent,
                              ar: s.rtl,
                              onTap: _busy ? null : _merge,
                            ),
                          if (_started == null) const SizedBox(height: 10),
                          if (_started != MergeChoice.merge)
                            PButton(
                              st.discard_btn,
                              variant: BtnVariant.secondary,
                              large: true,
                              block: true,
                              accent: s.accent,
                              ar: s.rtl,
                              onTap: _busy ? null : _discard,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The discard's second step. Pops `true` only on the explicit Remove.
class _DiscardConfirmSheet extends StatelessWidget {
  const _DiscardConfirmSheet({required this.s});
  final PatientAppState s;

  @override
  Widget build(BuildContext context) {
    final st = s.strings.offline;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          const SheetGrab(),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, sheetBottomInset(context, base: 24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(st.discard_confirm_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  st.discard_confirm_body,
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textTertiary, height: 1.5),
                ),
                const SizedBox(height: 20),
                PButton(
                  st.discard_confirm_btn,
                  variant: BtnVariant.danger,
                  block: true,
                  accent: s.accent,
                  ar: s.rtl,
                  onTap: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 8),
                PButton(
                  s.strings.common.cancel,
                  variant: BtnVariant.secondary,
                  block: true,
                  accent: s.accent,
                  ar: s.rtl,
                  onTap: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Disclosure gate identity ─────────────────────────────────
// The consolidated privacy disclosure the post-sign-in gate enforces. Matches
// the id/version the disclosure module's routes default to (`consolidated` /
// `1`). Acceptance is tracked per (id, version), so bumping the version here
// re-gates every user until they accept the new notice (fail-closed).
const String kDisclosureId = 'consolidated';
const String kDisclosureVersion = '1';

/// How long [enterAfterSignIn] waits for the on-device acceptance record. A
/// local read answers in milliseconds; this only bounds a database that
/// cannot open.
const _disclosureReadTimeout = Duration(seconds: 10);

/// Fail-closed disclosure GATE — interposed between a successful sign-in and
/// reaching 'app'. Shared by BOTH the OTP-verify and the email+password
/// sign-in paths so neither can bypass it. A user who has not accepted the
/// CURRENT consolidated-disclosure version never reaches the app; a returning
/// user who already accepted this version skips straight through.
///
/// Reads the real on-device acceptance store (`DisclosureDao.watchAcceptance`);
/// presentation goes through [_DisclosureGateScreen], which — on accept — runs
/// the real `AcceptDisclosureUseCase` (persist + cloud sync + domain event) and
/// pops `true`. Only a persisted acceptance unlocks 'app'.
Future<void> enterAfterSignIn(BuildContext context, WidgetRef ref, PatientAppState s) async {
  final DisclosureAcceptance? accepted;
  try {
    accepted = await ref
        .read(disclosureDaoProvider)
        .watchAcceptance(
          const DisclosureId.value(kDisclosureId),
          kDisclosureVersion,
        )
        .first
        .timeout(_disclosureReadTimeout);
  } on Object catch (_) {
    // The on-device database did not answer: it could not be opened (#172:
    // its key went missing) or failed. Waiting would leave the patient on a
    // sign-in screen that looks dead; say so instead. Startup checks the key
    // again and offers to start fresh. Fails closed: nothing reaches 'app'.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.strings.boot.lost_unavailable)));
    }
    return;
  }
  if (!context.mounted) return;
  if (accepted != null) {
    s.go(AppRoutes.app);
    return;
  }
  // Not accepted → present the gate. Pushed over the current screen so backing
  // out (without accepting) simply returns here — no 'app' access is granted.
  final didAccept = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => _DisclosureGateScreen(state: s),
    ),
  );
  if (!context.mounted) return;
  if (didAccept == true) s.go(AppRoutes.app);
}

/// Asked once, after a code signed an EXISTING account in: should the password
/// typed a moment ago become this account's password?
///
/// Separate and explicit because the two things are not the same act. The code
/// proved the mailbox; it did not say "replace my credentials". Someone who
/// simply mistyped their password would otherwise lose the one they have.
class _AdoptPasswordSheet extends StatelessWidget {
  const _AdoptPasswordSheet({required this.s});
  final PatientAppState s;

  @override
  Widget build(BuildContext context) {
    final c = s.strings.emergency;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          const SheetGrab(),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, sheetBottomInset(context, base: 24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(c.em_adopt_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  c.em_adopt_help,
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textTertiary, height: 1.5),
                ),
                const SizedBox(height: 20),
                PButton(
                  c.em_adopt_yes,
                  block: true,
                  accent: s.accent,
                  ar: s.rtl,
                  onTap: () => Navigator.pop(context, true),
                ),
                const SizedBox(height: 8),
                PButton(
                  c.em_adopt_no,
                  variant: BtnVariant.secondary,
                  block: true,
                  accent: s.accent,
                  ar: s.rtl,
                  onTap: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── OTP ──────────────────────────────────────────────────────
class _OtpScreen extends ConsumerStatefulWidget {
  const _OtpScreen();
  @override
  ConsumerState<_OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<_OtpScreen> with WidgetsBindingObserver {
  // View state only: input + focus. Countdown/verify live in [OtpController].
  final ctrl = TextEditingController();
  final focus = FocusNode();

  /// Set when the session is fine but something after it was not — a password
  /// that failed to save. Not an auth error, so it does not clear the boxes.
  String? _notice;

  /// Asks whether to adopt the password typed before the code was requested.
  /// Null when the sheet is dismissed, which means no.
  Future<bool?> _askAdoptPassword(PatientAppState s) => showAppSheet<bool>(
        context,
        builder: (_) => _AdoptPasswordSheet(s: s),
      );

  int get secs => ref.read(otpControllerProvider).secs;
  bool get _verifying => ref.read(otpControllerProvider).verifying;

  String? get _error {
    final e = ref.read(otpControllerProvider).error;
    if (e == null) return null;
    final s = AppScope.of(context);
    return switch (e.kind) {
      AuthErrorKind.lockout => s.strings.auth.auth_locked_retry(e.lockoutSecs.toString()),
      AuthErrorKind.emailRegistered => s.strings.auth.signup_email_registered,
      _ => e.message,
    };
  }

  /// A fresh code makes whatever is in the boxes stale, so they empty.
  Future<void> _resend(PatientAppState s) async {
    final sent =
        await ref.read(otpControllerProvider.notifier).resend(email: s.authEmail, countryCode: s.country.value);
    if (sent && mounted) setState(ctrl.clear);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  /// Back from the mail app with the code: the OS closed the keyboard, but the
  /// hidden field kept focus, so nothing would open it again (#98).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    if (_verifying || ctrl.text.length >= 6) return;
    // Not over a sheet or dialog this screen opened.
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _showKeyboard();
  }

  void _showKeyboard() {
    ContextMenuController.removeAny();
    reopenCodeKeyboard(focus, mounted: () => mounted);
  }

  /// Fills the boxes from the clipboard; a whole code submits at once (#99).
  Future<void> _pasteCode() async {
    final code = await clipboardCode();
    if (code == null || !mounted || _verifying) return;
    setState(() => ctrl.text = code);
    if (code.length == 6) unawaited(_verify(code));
  }

  /// Verifies the 6-digit code against the real auth module. On success the
  /// use-case has already persisted tokens + `balsm.user_id` to secure storage;
  /// we then transition to the app. Lockout (423) / invalid / geofence (403)
  /// surface inline and reset the boxes.
  Future<void> _verify(String code) async {
    final s = AppScope.of(context);
    final isNewUser = await ref.read(otpControllerProvider.notifier).verify(email: s.authEmail, code: code);
    if (!mounted) return;
    unawaited(isNewUser == null ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact());
    if (isNewUser != null) {
      // The sign-up password is applied in _afterVerify; the account now
      // exists, so the credentials are worth saving.
      TextInput.finishAutofillContext();
      unawaited(_afterVerify(s, isNewUser: isNewUser));
    } else {
      setState(ctrl.clear); // error is in controller state; reset the boxes
    }
  }

  /// Post-verify navigation, and what becomes of the password that was typed
  /// before the code was asked for.
  ///
  /// A new account keeps it: they chose it a moment ago and never typed it
  /// twice. An existing account is ASKED. Verifying a code proves the mailbox,
  /// not an intent to change credentials — silently adopting whatever was in
  /// the password field would let a typo replace a working password for good.
  Future<void> _afterVerify(PatientAppState s, {required bool isNewUser}) async {
    final pw = s.authPassword;
    s.authPassword = null; // transient either way — never persisted
    if (pw != null && pw.isNotEmpty) {
      final apply = isNewUser || (await _askAdoptPassword(s) ?? false);
      if (!mounted) return;
      if (apply) {
        final result = await ref.read(signInUseCaseProvider).setPassword(password: pw);
        if (!mounted) return;
        if (result.isFailure) {
          // The account exists and the session is live; only the password did
          // not stick. Say so rather than let them find out next launch.
          setState(
            () => _notice = isNewUser ? s.strings.emergency.em_pw_set_failed : s.strings.emergency.em_adopt_failed,
          );
        }
      }
    }
    if (!mounted) return;
    // Design 2026-09: the profile-setup step left the registration flow. A new
    // account enters the app directly; the Profile tab derives its completion
    // card from the actually-missing mandatory fields, and everything
    // DOB-gated (QR mint) stays fail-closed until Personal details is saved.
    unawaited(enterAfterSignIn(context, ref, s));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ContextMenuController.removeAny();
    focus.dispose();
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(otpControllerProvider); // bridge getters read current state
    final s = AppScope.of(context);
    final code = ctrl.text;
    final contact = s.authEmail.isEmpty ? s.strings.auth.otp_your_email : s.authEmail;
    return ColoredBox(
      color: AppColors.cream50,
      child: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          maxHeight: kContentBlockMaxHeight,
          child: Column(
            children: [
              _AuthHeader(onBack: () => s.go(AppRoutes.phone), step: 2, total: 2),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // auth.jsx OtpScreen: this step only follows sign-up now.
                      Text(s.strings.auth.otp_confirm_title, style: Typo.title(ar: s.rtl)),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: Typo.body(ar: s.rtl),
                          children: [
                            // Says nothing about whether this address has an account.
                            // The screen is reached identically either way, and the copy
                            // is the last place that distinction could leak.
                            TextSpan(text: '${s.strings.auth.otp_sent_to} '),
                            TextSpan(
                              text: contact,
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(s.strings.auth.otp_existing_note, style: Typo.meta(ar: s.rtl).copyWith(height: 1.5)),
                      if (_notice case final notice?) ...[
                        const SizedBox(height: 12),
                        Text(
                          notice,
                          style: Typo.meta(ar: s.rtl)
                              .copyWith(color: AppColors.sun500, fontWeight: FontWeight.w600, height: 1.5),
                        ),
                      ],
                      const SizedBox(height: 28),
                      // Six painted boxes, one field. Read separately they are six
                      // unnamed containers: no name, no way to hear how many digits
                      // have landed, no sign it is an input at all. The boxes are
                      // excluded and the group carries the label and the count.
                      Semantics(
                        textField: true,
                        label: s.strings.common.a11y_code_field,
                        value: s.strings.common.a11y_code_progress('${code.length}'),
                        onTap: _showKeyboard,
                        onPaste: _pasteCode,
                        child: ExcludeSemantics(
                          child: GestureDetector(
                            // The gaps between boxes count as the field too.
                            behavior: HitTestBehavior.opaque,
                            onTap: _showKeyboard,
                            onLongPressStart: (d) => showCodePasteMenu(context, d.globalPosition, _pasteCode),
                            child: OtpBoxRow(code: code, accent: s.accent),
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: 0,
                        child: SizedBox(
                          height: 1,
                          width: 1,
                          child: TextField(
                            controller: ctrl,
                            focusNode: focus,
                            textDirection: TextDirection.ltr,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            maxLength: 6,
                            inputFormatters: const [CodeInputFormatter()],
                            onChanged: (v) {
                              setState(() {});
                              if (v.length == 6) unawaited(_verify(v));
                            },
                          ),
                        ),
                      ),
                      if (_error case final error?)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              error,
                              textAlign: TextAlign.center,
                              style:
                                  Typo.meta(ar: s.rtl).copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Center(
                        child: secs > 0
                            ? RichText(
                                text: TextSpan(
                                  style: Typo.meta(ar: s.rtl),
                                  children: [
                                    TextSpan(text: '${s.strings.auth.otp_in} '),
                                    TextSpan(
                                      text: '${secs}s',
                                      style: Typo.num(
                                        size: FontSizes.meta,
                                        weight: FontWeight.w700,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : PButton(
                                s.strings.auth.otp_resend,
                                variant: BtnVariant.ghost,
                                accent: s.accent,
                                ar: s.rtl,
                                onTap: ref.read(otpControllerProvider).resending ? null : () => _resend(s),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 24),
                child: Opacity(
                  opacity: code.length == 6 && !_verifying ? 1 : 0.4,
                  child: PButton(
                    _verifying ? s.strings.auth.otp_verifying : s.strings.auth.verify,
                    large: true,
                    block: true,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: code.length == 6 && !_verifying
                        ? () {
                            unawaited(_verify(code));
                          }
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Disclosure gate ──────────────────────────────────────────
// Governance step interposed AFTER a successful sign-in and BEFORE the app.
// The consumer-app design never covered this flow, so it is rendered in the
// prototype's own kit (cream surface, PButton, tokens) rather than the
// module's core-design-system ConsolidatedDisclosureScreen — whose success
// path hard-codes a `pushReplacementNamed('/home')` the prototype's
// route-state Navigator does not provide. ACCEPTANCE STILL RUNS THE REAL
// use-case: AcceptDisclosureUseCase → DisclosureDao.insert persists the
// country / supervisory-authority / language snapshots on-device (FR-040) and
// best-effort syncs to the cloud + publishes the domain event. Fail-closed:
// pops `true` only after the acceptance persists; backing out grants nothing.
class _DisclosureGateScreen extends ConsumerStatefulWidget {
  const _DisclosureGateScreen({required this.state});
  final PatientAppState state;
  @override
  ConsumerState<_DisclosureGateScreen> createState() => _DisclosureGateScreenState();
}

class _DisclosureGateScreenState extends ConsumerState<_DisclosureGateScreen> {
  final _scroll = ScrollController();
  bool _readToEnd = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Content shorter than the viewport can never scroll — treat as read once
    // laid out so the CTA is reachable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scroll.hasClients || _scroll.position.maxScrollExtent <= 0) {
        setState(() => _readToEnd = true);
      }
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Enable the CTA only once the patient has scrolled to the end of the
    // notice (mirrors the real screen's scroll-to-accept requirement).
    if (!_readToEnd && _scroll.hasClients && _scroll.position.pixels >= _scroll.position.maxScrollExtent - 4) {
      setState(() => _readToEnd = true);
    }
  }

  Future<void> _accept() async {
    final s = widget.state;
    final registry = ref.read(countryRegistryProvider);
    setState(() {
      _submitting = true;
      _error = null;
    });
    // Real use-case: on-device persist (FR-040 snapshots) + cloud sync + event.
    final result = await ref.read(acceptDisclosureUseCaseProvider).execute(
          disclosureId: const DisclosureId.value(kDisclosureId),
          version: kDisclosureVersion,
          countryCode: s.country.value,
          supervisoryAuthority: registry.supervisoryAuthority(s.country.value),
          preferredLanguage: s.lang.value,
        );
    if (!mounted) return;
    result.fold(
      (_) => Navigator.of(context).pop(true), // persisted → unlock 'app'
      (failure) => setState(() {
        _submitting = false;
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final authority = ref.watch(countryRegistryProvider).supervisoryAuthority(s.country.value);
    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          maxHeight: kContentBlockMaxHeight,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 4),
                child: Row(
                  children: [
                    RoundBtn(
                      icon: backArrow(context),
                      semanticLabel: s.strings.common.a11y_back,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: s.accent.bg, shape: BoxShape.circle),
                        child: Icon(LucideIcons.shieldCheck, size: 34, color: s.accent.main),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        s.strings.privacy.pv_title,
                        style: Typo.display(ar: s.rtl),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.strings.privacy.pv_intro_body,
                        style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      _GateSection(
                        s,
                        LucideIcons.database,
                        s.strings.privacy.pv_collect,
                        s.strings.privacy.pv_collect_body,
                      ),
                      _GateSection(
                        s,
                        LucideIcons.lock,
                        s.strings.privacy.pv_protect,
                        s.strings.privacy.pv_protect_body,
                      ),
                      _GateSection(
                        s,
                        LucideIcons.scale,
                        s.strings.privacy.pv_rights,
                        s.strings.privacy.pv_rights_body,
                      ),
                      _GateSection(
                        s,
                        LucideIcons.landmark,
                        s.strings.privacy.pv_authority,
                        s.strings.privacy.pv_authority_body(authority),
                      ),
                      _GateSection(
                        s,
                        LucideIcons.share2,
                        s.strings.privacy.pv_sharing2,
                        s.strings.privacy.pv_sharing_body,
                      ),
                      _GateSection(
                        s,
                        LucideIcons.trash2,
                        s.strings.privacy.pv_deletion,
                        s.strings.privacy.pv_deletion_body,
                      ),
                      const SizedBox(height: 8),
                      if (!_readToEnd)
                        Center(
                          child: Text(
                            s.strings.privacy.pv_scroll_hint,
                            style: Typo.meta(ar: s.rtl),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 24),
                child: Column(
                  children: [
                    if (_error case final error?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            textAlign: TextAlign.center,
                            style: Typo.meta(ar: s.rtl).copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    Opacity(
                      opacity: _readToEnd && !_submitting ? 1 : 0.4,
                      child: PButton(
                        _submitting ? (s.strings.privacy.pv_saving) : (s.strings.privacy.pv_agree),
                        large: true,
                        block: true,
                        accent: s.accent,
                        ar: s.rtl,
                        onTap: _readToEnd && !_submitting ? _accept : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile setup ────────────────────────────────────────────
class _ProfileSetupScreen extends ConsumerStatefulWidget {
  const _ProfileSetupScreen();
  @override
  ConsumerState<_ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<_ProfileSetupScreen> {
  final first = TextEditingController();
  final last = TextEditingController();
  final handle = TextEditingController();
  final dob = TextEditingController();
  DateTime? _dobDate;
  Gender gender = Gender.female;
  UsernameStatus unStatus = UsernameStatus.idle;
  Timer? debounce;
  static const _taken = {
    'layla',
    'hassan',
    'balsm',
    'admin',
    'doctor',
    'health',
    'user',
    'omar',
    'sara',
    'mona',
    'ahmed',
  };

  void _setHandle(String raw) {
    final v = raw.toLowerCase().replaceAll(RegExp('[^a-z0-9_]'), '');
    if (handle.text != v) {
      handle.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
    }
    debounce?.cancel();
    if (v.isEmpty) {
      setState(() => unStatus = UsernameStatus.idle);
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(v)) {
      setState(() => unStatus = UsernameStatus.invalid);
      return;
    }
    setState(() => unStatus = UsernameStatus.checking);
    debounce = Timer(
      const Duration(milliseconds: 700),
      () => setState(() => unStatus = _taken.contains(v) ? UsernameStatus.taken : UsernameStatus.available),
    );
  }

  bool get ok =>
      '${first.text} ${last.text}'.trim().length > 1 &&
      _dobDate != null &&
      (unStatus == UsernameStatus.available || unStatus == UsernameStatus.idle);

  String _fmtDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';

  /// Wire format for the server (`yyyy-MM-dd`).
  String _isoDob(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _creating = false;

  Future<void> _pickDob() async {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final picked = await showBalsmDatePicker(
      context,
      initial: _dobDate,
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      title: s.strings.onboarding.dob_title,
      confirmLabel: s.strings.onboarding.dob_confirm,
      months: s.strings.settings.cal_months.split('|'),
      weekdays: s.strings.settings.cal_weekdays.split('|'),
      rtl: s.rtl,
      accent: s.accent.main,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dobDate = picked;
      dob.text = _fmtDob(picked);
    });
  }

  /// Design-aligned age gate: it runs HERE, on a NEW account, not before the
  /// OTP. Under-18 → soft-block screen; otherwise persist the onboarding
  /// identity and complete sign-up through the shared fail-closed disclosure
  /// gate.
  Future<void> _createAccount() async {
    if (_creating) return;
    final s = AppScope.of(context);
    final d = _dobDate;
    if (d == null) return;
    final ageResult = ref.read(ageGateUseCaseProvider).validate(d);
    if (ageResult.isFailure) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const _UnderEighteenScreen(),
        ),
      );
      return;
    }
    // The OTP-verify step already established the session (bearer token
    // persisted), so persist the collected identity to the server now. Without
    // this PATCH the display name, DOB, and gender were dropped on the floor and
    // GET /account/self came back empty — a blank account-details screen.
    setState(() => _creating = true);
    await ref.read(accountProfileUseCaseProvider).update(
          UpdateProfileInput(
            firstName: first.text.trim(),
            lastName: last.text.trim(),
            gender: gender,
            dateOfBirth: _isoDob(d),
          ),
        );
    // Claim the chosen handle (best-effort — a genuinely-taken handle can be
    // changed later from account details; onboarding must not hard-block on it).
    final wantedHandle = handle.text.trim();
    if (wantedHandle.isNotEmpty) {
      await ref.read(claimHandleUseCaseProvider).execute(wantedHandle);
    }
    // Refresh the app-wide summary so the profile head shows the new name.
    await refreshAccountSummary(ref);
    if (!mounted) return;
    setState(() => _creating = false);
    unawaited(enterAfterSignIn(context, ref, s));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ColoredBox(
      color: AppColors.cream50,
      child: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          maxHeight: kContentBlockMaxHeight,
          child: Column(
            children: [
              _AuthHeader(onBack: () => s.go(AppRoutes.otp), step: 3),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(s.strings.onboarding.pf_title, style: Typo.title(ar: s.rtl)),
                      const SizedBox(height: 8),
                      Text(s.strings.onboarding.pf_help, style: Typo.body(ar: s.rtl)),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: s.strings.onboarding.pf_fname,
                              ar: s.rtl,
                              child: AuthInput(
                                controller: first,
                                hint: s.strings.onboarding.pf_fname_ph,
                                accent: s.accent,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              label: s.strings.onboarding.pf_lname,
                              ar: s.rtl,
                              child: AuthInput(
                                controller: last,
                                hint: s.strings.onboarding.pf_lname_ph,
                                accent: s.accent,
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _UsernameField(controller: handle, status: unStatus, onChanged: _setHandle, s: s),
                      const SizedBox(height: 16),
                      _Field(
                        label: s.strings.onboarding.pf_dob,
                        ar: s.rtl,
                        child: GestureDetector(
                          onTap: _pickDob,
                          child: AbsorbPointer(
                            child: AuthInput(
                              controller: dob,
                              hint: 'DD / MM / YYYY',
                              mono: true,
                              forceLtr: true,
                              accent: s.accent,
                              prefixIcon: const Icon(LucideIcons.calendar, size: 18, color: AppColors.textTertiary),
                              suffixIcon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textHint),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        label: s.strings.onboarding.pf_gender,
                        ar: s.rtl,
                        child: _Segmented<Gender>(
                          left: s.strings.onboarding.pf_female,
                          right: s.strings.onboarding.pf_male,
                          leftValue: Gender.female,
                          rightValue: Gender.male,
                          value: gender,
                          onChanged: (g) => setState(() => gender = g),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 24),
                child: Column(
                  children: [
                    Opacity(
                      opacity: ok && !_creating ? 1 : 0.4,
                      child: PButton(
                        _creating ? s.strings.onboarding.pf_creating : s.strings.onboarding.pf_create,
                        large: true,
                        block: true,
                        accent: s.accent,
                        ar: s.rtl,
                        onTap: ok && !_creating ? _createAccount : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 6),
                        Text(s.strings.onboarding.pf_secure, style: Typo.meta(ar: s.rtl)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsernameField extends StatelessWidget {
  const _UsernameField({required this.controller, required this.status, required this.onChanged, required this.s});
  final TextEditingController controller;
  final UsernameStatus status;
  final ValueChanged<String> onChanged;
  final PatientAppState s;
  @override
  Widget build(BuildContext context) {
    final (icon, col, msg) = switch (status) {
      UsernameStatus.checking => (LucideIcons.loader, AppColors.textTertiary, s.strings.auth.un_checking),
      UsernameStatus.available => (LucideIcons.checkCircle2, AppColors.hueMint600, s.strings.auth.un_avail),
      UsernameStatus.taken => (LucideIcons.xCircle, AppColors.danger, s.strings.auth.un_taken),
      UsernameStatus.invalid => (LucideIcons.alertCircle, AppColors.sun500, s.strings.auth.un_invalid),
      _ => (null, AppColors.textHint, ''),
    };
    return _Field(
      label: s.strings.auth.un_label,
      ar: s.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              AuthInput(
                controller: controller,
                hint: s.strings.auth.un_ph,
                mono: true,
                forceLtr: true,
                accent: s.accent,
                prefix: '@',
                onChanged: onChanged,
              ),
              if (status == UsernameStatus.checking)
                const PositionedDirectional(end: 12, child: Spinner(size: 16, stroke: 2, color: AppColors.textTertiary))
              else if (icon != null)
                PositionedDirectional(end: 12, child: Icon(icon, size: 17, color: col)),
            ],
          ),
          if (msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(msg, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: col)),
            ),
          if (controller.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(LucideIcons.link, size: 12, color: AppColors.textHint),
                  const SizedBox(width: 5),
                  Text(
                    s.strings.profile.pd_handle_hint,
                    style: Typo.num(size: FontSizes.meta, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────
/// Two-option segmented control. Generic over the selected value `T`: the
/// caller supplies the [leftValue]/[rightValue] each segment stands for and the
/// current [value]; the active segment is the one whose value equals [value].
/// Use `_Segmented<bool>` for a plain toggle, `_Segmented<Gender>` for a typed
/// choice, etc. (Param is `V`, not `T` — `T` is the design-tokens class.)
class _Segmented<V> extends StatelessWidget {
  const _Segmented({
    required this.left,
    required this.right,
    required this.leftValue,
    required this.rightValue,
    required this.value,
    required this.onChanged,
    this.leftIcon,
    this.rightIcon,
  });
  final String left;
  final String right;
  final IconData? leftIcon;
  final IconData? rightIcon;
  final V leftValue;
  final V rightValue;
  final V value;
  final ValueChanged<V> onChanged;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // `.segmented button` — active pill bg/shadow animate over --dur-base.
    // The pill itself stays the design's height; `MinTapTarget` grows only the
    // tap/semantics area to the 48px platform minimum, same pattern as
    // `RoundBtn` — nothing painted changes.
    Widget seg(String label, IconData? icon, bool active, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            selected: active,
            label: label,
            // The node itself must carry the tap action — `excludeSemantics`
            // below hides the GestureDetector's own semantics (which would
            // otherwise duplicate the label), so without this the node has no
            // SemanticsAction.tap and a screen reader's activate gesture does
            // nothing.
            onTap: onTap,
            excludeSemantics: true,
            child: MinTapTarget(
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.easeOut,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? AppColors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.segment),
                    boxShadow: active ? AppShadows.xs : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 14, color: active ? AppColors.textPrimary : AppColors.textTertiary),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        label,
                        style: Typo.bodySm(ar: s.rtl).copyWith(
                          fontWeight: FontWeight.w600,
                          color: active ? AppColors.textPrimary : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.ink50,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          seg(left, leftIcon, value == leftValue, () => onChanged(leftValue)),
          const SizedBox(width: 6),
          seg(right, rightIcon, value == rightValue, () => onChanged(rightValue)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.ar});
  final String text;
  final bool ar;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary));
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, required this.ar});
  final String label;
  final Widget child;
  final bool ar;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label, ar: ar),
          const SizedBox(height: 8),
          child,
        ],
      );
}

/// Device-only sign-in's unrecoverable-password notice — same info-card shape
/// used elsewhere in the app (icon + cream-50 fill), under the password field.
class _DeviceOnlyWarning extends StatelessWidget {
  const _DeviceOnlyWarning({required this.text, required this.ar});
  final String text;
  final bool ar;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.cream50, borderRadius: BorderRadius.circular(AppRadii.lg)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(LucideIcons.info, size: 16, color: AppColors.textTertiary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: Typo.bodySm(ar: ar).copyWith(color: AppColors.textSecondary, height: 1.45)),
            ),
          ],
        ),
      );
}

// ── Forgot-password (email-only reset via OTP code) ──────────
class _ForgotPasswordSheet extends ConsumerStatefulWidget {
  const _ForgotPasswordSheet({required this.initialEmail, required this.s});
  final String initialEmail;
  final PatientAppState s;
  @override
  ConsumerState<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends ConsumerState<_ForgotPasswordSheet> {
  // View state only: text controllers + visibility toggle. The step machine
  // lives in [PasswordResetController].
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _newPw = TextEditingController();
  bool _showPw = false;

  ResetStep get _step => ref.read(passwordResetControllerProvider).step;
  bool get _busy => ref.read(passwordResetControllerProvider).busy;
  String? get _error => ref.read(passwordResetControllerProvider).error?.message;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPw.dispose();
    super.dispose();
  }

  bool get _emailOk => isPlausibleEmail(_email.text);
  bool get _resetOk => _code.text.trim().length >= 4 && _newPw.text.length >= 8;

  // Forgot-password reuses the OTP-request endpoint to send the reset code.
  Future<void> _sendCode() async {
    if (!_emailOk) return;
    await ref
        .read(passwordResetControllerProvider.notifier)
        .sendCode(email: _email.text.trim(), countryCode: widget.s.country.value);
  }

  Future<void> _reset() async {
    if (!_resetOk) return;
    await ref.read(passwordResetControllerProvider.notifier).reset(
          email: _email.text.trim(),
          code: _code.text.trim(),
          newPassword: _newPw.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(passwordResetControllerProvider); // bridge getters read current state
    final s = widget.s;
    return Directionality(
      textDirection: s.dir,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetGrab()),
              const SizedBox(height: 16),
              Text(
                _step == ResetStep.done ? s.strings.auth.fp_success : s.strings.auth.fp_title,
                style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (_step == ResetStep.email) ...[
                Text(s.strings.auth.fp_help, style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                AuthInput(
                  controller: _email,
                  hint: s.strings.emergency.em_ph,
                  keyboard: TextInputType.emailAddress,
                  forceLtr: true,
                  accent: s.accent,
                  onChanged: (_) => setState(() {}),
                ),
              ] else if (_step == ResetStep.code) ...[
                RichText(
                  text: TextSpan(
                    style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textSecondary),
                    children: [
                      TextSpan(text: '${s.strings.auth.fp_sent_help} '),
                      TextSpan(
                        text: _email.text.trim(),
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Label(s.strings.auth.fp_code_label, ar: s.rtl),
                const SizedBox(height: 8),
                AuthInput(
                  controller: _code,
                  hint: '••••••',
                  keyboard: TextInputType.number,
                  mono: true,
                  forceLtr: true,
                  accent: s.accent,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                _Label(s.strings.auth.fp_new_pw, ar: s.rtl),
                const SizedBox(height: 8),
                AuthInput(
                  controller: _newPw,
                  hint: s.strings.auth.pw_ph,
                  obscure: !_showPw,
                  forceLtr: true,
                  accent: s.accent,
                  suffixIcon: Semantics(
                    button: true,
                    label: _showPw ? s.strings.common.a11y_hide_pw : s.strings.common.a11y_show_pw,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _showPw = !_showPw),
                      child:
                          Icon(_showPw ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: AppColors.textTertiary),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: Typo.meta(ar: s.rtl).copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (_step == ResetStep.email)
                Opacity(
                  opacity: _emailOk && !_busy ? 1 : 0.4,
                  child: PButton(
                    s.strings.auth.fp_send,
                    large: true,
                    block: true,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: _emailOk && !_busy ? _sendCode : null,
                  ),
                )
              else if (_step == ResetStep.code)
                Opacity(
                  opacity: _resetOk && !_busy ? 1 : 0.4,
                  child: PButton(
                    s.strings.auth.fp_reset,
                    large: true,
                    block: true,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: _resetOk && !_busy ? _reset : null,
                  ),
                )
              else
                PButton(
                  s.strings.auth.fp_done,
                  large: true,
                  block: true,
                  accent: s.accent,
                  ar: s.rtl,
                  onTap: () => Navigator.pop(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Holds [child] to at least [lines] lines of [style], centred inside.
///
/// The welcome column is bottom-anchored, so its height is its text: Arabic
/// sets the title on one line and the sub on two where English takes two and
/// three, and switching language moved the logo and everything above the
/// buttons by about 60dp. Reserving the English line counts keeps both
/// languages in the same place; longer copy or larger system text still grows.
class _SteadyLines extends StatelessWidget {
  const _SteadyLines({required this.lines, required this.style, required this.child});
  final int lines;
  final TextStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final line = MediaQuery.textScalerOf(context).scale(style.fontSize!) * (style.height ?? 1.2);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: line * lines),
      child: Align(heightFactor: 1, child: child),
    );
  }
}

class _Trust extends StatelessWidget {
  const _Trust(this.s, this.icon, this.label);
  final PatientAppState s;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 84,
        child: Column(
          children: [
            Icon(icon, size: 22, color: s.accent.main),
            const SizedBox(height: 6),
            // Two lines held in both languages ("Private by / default" wraps in
            // English only), so the row does not change height on a switch.
            _SteadyLines(
              lines: 2,
              style: Typo.meta(ar: s.rtl).copyWith(fontSize: FontSizes.eyebrow),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Typo.meta(ar: s.rtl)
                    .copyWith(fontSize: FontSizes.eyebrow, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      );
}

class _GateSection extends StatelessWidget {
  const _GateSection(this.s, this.icon, this.title, this.body);
  final PatientAppState s;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: s.accent.main),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Typo.subhead(ar: s.rtl).copyWith(fontSize: FontSizes.bodyLg, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(body, style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
