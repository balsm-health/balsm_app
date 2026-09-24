import 'dart:async';
import 'package:account/account.dart';
import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:disclosure/disclosure.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app_state.dart';
import '../auth/auth_flow_controllers.dart';
import '../dev/shake_to_dev_config.dart';
import '../routes.dart';
import '../assets.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/legal_sheet.dart';
import 'walkthrough_screen.dart';

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
  bool _busyGoogle = false;
  String? _error;

  /// Google sign-in ships on Android, web and macOS only. iOS deliberately
  /// has NO third-party sign-in: offering one there triggers App Review
  /// guideline 4.8 (Sign in with Apple becomes mandatory), and the Apple
  /// provider stays off until team ownership is settled (account ids are
  /// team-scoped — a transfer would strand every Apple user). Windows/Linux
  /// have no google_sign_in SDK implementation yet.
  bool get _googleAvailable {
    if (!FlavorConfig.current.socialSignInEnabled) return false;
    if (FlavorConfig.current.googleServerClientId.isEmpty) return false;
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Native Google flow, then the Balsm token exchange. A new account enters
  /// the app directly — the Profile tab's gaps card owns completion, and
  /// everything DOB-gated stays fail-closed until details are saved.
  Future<void> _signInGoogle(PatientAppState s) async {
    if (_busyGoogle) return;
    setState(() {
      _busyGoogle = true;
      _error = null;
    });

    final credentials = await ref.read(googleCredentialsPortProvider).obtain();
    if (!mounted) return;

    switch (credentials) {
      case SocialCredentialsCancelled():
        // The user backed out of the provider sheet — say nothing.
        setState(() => _busyGoogle = false);
        return;
      case SocialCredentialsFailure(:final missingToken):
        setState(() {
          _busyGoogle = false;
          _error = missingToken ? s.strings.auth.social_unavailable : s.strings.auth.social_failed;
        });
        return;
      case SocialCredentials():
        break;
    }

    final result = await ref.read(signInUseCaseProvider).signInWithGoogle(
          idToken: credentials.idToken,
          email: credentials.email,
          countryCode: s.country.value,
        );
    if (!mounted) return;
    setState(() => _busyGoogle = false);

    result.fold(
      (signInResult) {
        switch (signInResult) {
          case SignInSuccess(:final isNewUser):
            if (isNewUser) {
              // Google hands the name over now — prefill Personal details.
              s.setSocialName(givenName: credentials.givenName, familyName: credentials.familyName);
            }
            unawaited(enterAfterSignIn(context, ref, s));
          case SignInLockout(:final session):
            final secsLeft = session.until.difference(DateTime.now()).inSeconds.clamp(0, 3600);
            setState(() => _error = s.strings.auth.auth_locked_retry(secsLeft.toString()));
        }
      },
      (failure) => setState(() => _error = failure.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return BalsmWelcomeBackground(
      child: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          maxHeight: kContentBlockMaxHeight,
          child: Column(children: [
            // `.wbody { margin-top: auto }` — lockup + CTAs sit on the cream
            // fade; watercolor fills the space above.
            // `.wbody { margin-top: auto }` with a safety valve. The design's
            // 168px lockup assumes the prototype's welcome, which has no social
            // buttons; Flutter still shows Google on Android/web/macOS, and that
            // extra block plus an error line overflows a 402x900 viewport.
            // reverse: true keeps the content bottom-anchored exactly as the
            // Spacer did, and scrolls instead of clipping when it cannot fit.
            Expanded(
              child: SingleChildScrollView(
                reverse: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                  child: Column(children: [
                    SvgPicture.asset(Assets.brand_logo_vertical, width: 168, height: 168, fit: BoxFit.contain),
                    const SizedBox(height: 26),
                    Text(s.strings.onboarding.w_title, textAlign: TextAlign.center, style: Typo.display(ar: s.rtl)),
                    const SizedBox(height: 14),
                    // `.wsub { max-width: 34ch }` — hold the sub to a comfortable
                    // measure instead of the full 28px-gutter width. 34ch against
                    // the 16px body face is ~326 logical px.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 326),
                      child: Text(s.strings.onboarding.w_sub,
                          textAlign: TextAlign.center, style: Typo.body(ar: s.rtl).copyWith(color: T.fg2)),
                    ),
                    const SizedBox(height: 30),
                    PButton(s.strings.onboarding.w_start(s.gender),
                        variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: s.rtl, onTap: () {
                      s.go(AppRoutes.phone);
                    }),
                    const SizedBox(height: 16),
                    if (_googleAvailable) ...[
                      _OrDivider(label: s.strings.onboarding.w_or, ar: s.rtl),
                      const SizedBox(height: 14),
                      _SocialButton(
                          label: s.strings.onboarding.w_google,
                          dark: false,
                          googleG: true,
                          busy: _busyGoogle,
                          onTap: _busyGoogle ? null : () => unawaited(_signInGoogle(s))),
                      const SizedBox(height: 14),
                    ] else
                      // No social button on this platform, so no separator either —
                      // an "or" with nothing after it reads as a missing control.
                      // The design dropped the divider with the buttons (auth.jsx
                      // WelcomeScreen): email is the only route where social is off.
                      const SizedBox(height: 18),
                    if (_error != null) ...[
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: Typo.meta(ar: s.rtl).copyWith(color: T.danger, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                    ],
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  // Labels are translated and wrap to different line counts;
                  // top alignment keeps the three icons on one baseline.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _trust(s, LucideIcons.smartphone, s.strings.settings.trust_device),
                    const SizedBox(width: 22),
                    _trust(s, LucideIcons.lock, s.strings.settings.trust_private),
                    const SizedBox(width: 22),
                    _trust(s, LucideIcons.cloudOff, s.strings.settings.trust_offline),
                  ]),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Pressable(
                onTap: () => s.setLang(s.lang == LanguageCode.ar ? LanguageCode.en : LanguageCode.ar),
                child: Semantics(
                  button: true,
                  label: s.lang == LanguageCode.ar ? s.strings.onboarding.lang_to_en : s.strings.onboarding.lang_to_ar,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0x6B1A1A17),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x52FFFFFF)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(LucideIcons.languages, size: 17, color: Colors.white),
                      const SizedBox(width: 7),
                      Text(
                        s.lang == LanguageCode.ar ? LanguageCode.en.nativeName : LanguageCode.ar.nativeName,
                        style: (s.lang == LanguageCode.ar ? Typo.bodySm() : Typo.bodySm(ar: true))
                            .copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ]),
                  ),
                ),
              ),
              // Dev Config, reachable before anyone signs in. The shake gesture
              // opens the same screen, but a shake is not available on a
              // simulator and not discoverable on a device, and the server this
              // build talks to is the first thing that goes wrong. Never in
              // prod: `serverSwitchingEnabled` is dev + staging only.
              if (FlavorConfig.current.serverSwitchingEnabled) ...[
                const SizedBox(width: 8),
                _DevConfigPill(onClosed: () => setState(() {})),
              ],
            ]),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  Widget _trust(PatientAppState s, IconData icon, String label) => SizedBox(
        width: 84,
        child: Column(children: [
          Icon(icon, size: 22, color: s.accent.main),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs2, fontWeight: FontWeight.w600, color: T.fg3)),
        ]),
      );
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
    } catch (_) {
      base = FlavorConfig.current.defaultServer.apiBaseUrl;
    }
    final url = Uri.tryParse(base);
    final label = url == null || url.host.isEmpty ? '?' : (url.hasPort ? '${url.host}:${url.port}' : url.host);

    return Pressable(
      onTap: () async {
        await openDevConfig(context);
        onClosed();
      },
      child: Semantics(
        button: true,
        label: 'Dev config',
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0x6B1A1A17),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x52FFFFFF)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.wrench, size: 16, color: Colors.white),
            const SizedBox(width: 7),
            // Narrow enough to sit beside the language pill on a 402px screen;
            // a long staging host ellipsises rather than overflowing the row.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.bodySm().copyWith(fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Welcome `.wactions` hairline divider — `or` between 28% white rules.
class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label, required this.ar});
  final String label;
  final bool ar;
  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: ColoredBox(color: Color(0x47FFFFFF), child: SizedBox(height: 1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label,
              style: Typo.meta(ar: ar).copyWith(color: const Color(0xB3FFFFFF), fontWeight: FontWeight.w500)),
        ),
        const Expanded(child: ColoredBox(color: Color(0x47FFFFFF), child: SizedBox(height: 1))),
      ]);
}

// ── Auth header with step dots ───────────────────────────────
class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.onBack, required this.step});
  final VoidCallback onBack;
  final int step; // 1..3
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Row(children: [
        RoundBtn(icon: backArrow(context), onTap: onBack),
        const Spacer(),
        Row(children: [
          for (var i = 0; i < 3; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(left: 4),
              width: i == step - 1 ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i <= step - 1 ? s.accent.main : T.ink200,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
        ]),
      ]),
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
      backgroundColor: T.cream50,
      body: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          maxHeight: kContentBlockMaxHeight,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(children: [
                RoundBtn(icon: backArrow(context), onTap: () => Navigator.of(context).maybePop()),
              ]),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
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
                  style: Typo.body(ar: s.rtl).copyWith(color: T.fg2),
                ),
                const SizedBox(height: 28),
                PButton(
                  s.strings.settings.na_notify_me,
                  variant: BtnVariant.primary,
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
              ]),
            ),
            const Spacer(),
          ]),
        ),
      ),
    );
  }
}

// ── Email + password ─────────────────────────────────────────
// Claude Design `PhoneScreen` is email-only in this phase (no mobile
// signup/login). Collects email + password; sign-up still verifies by OTP
// before a session exists; sign-in uses the password path.
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

  /// Set when the password was refused: the screen then asks whether to send a
  /// code rather than sending one on its own.
  bool _offerCode = false;
  bool _showPw = false;

  bool get _submitting => ref.read(credentialsControllerProvider).submitting;

  String? get _error {
    final e = ref.read(credentialsControllerProvider).error;
    if (e == null) return null;
    final s = AppScope.of(context);
    return switch (e.kind) {
      AuthErrorKind.lockout => s.strings.auth.auth_locked_retry(e.lockoutSecs.toString()),
      AuthErrorKind.invalidCredentials => s.strings.auth.pw_invalid_creds,
      AuthErrorKind.server => e.message,
    };
  }

  @override
  void dispose() {
    ctrl.dispose();
    pwCtrl.dispose();
    super.dispose();
  }

  bool get ok {
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(ctrl.text.trim());
    return emailOk && pwCtrl.text.length >= 8;
  }

  void _showForgotPassword(String email) {
    final s = AppScope.of(context);
    showAppSheet<void>(
      context,
      builder: (_) => _ForgotPasswordSheet(initialEmail: email, s: s),
    );
  }

  /// One entry for everyone: try the password, and on a plain refusal offer a
  /// code instead.
  ///
  /// The refusal covers three server-side realities — no account, an account
  /// with no password, a wrong password — and deliberately does not say which.
  /// So this branches on "sign-in failed", never on "account exists", and the
  /// step that follows reads identically in every case.
  Future<void> _continue() async {
    final s = AppScope.of(context);
    final address = ctrl.text.trim();
    final controller = ref.read(credentialsControllerProvider.notifier);

    final ok = await controller.signIn(email: address, password: pwCtrl.text);
    if (!mounted) return;
    if (ok) {
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

    // A lockout is not an invalid credential, and neither is an unreachable
    // server. Offering a code for either would walk around the lockout, or
    // email someone because the Wi-Fi dropped.
    final error = ref.read(credentialsControllerProvider).error;
    if (error == null || error.kind != AuthErrorKind.invalidCredentials) return;

    setState(() => _offerCode = true);
  }

  /// Sends the code the patient just asked for, then moves to the code step.
  Future<void> _sendCode() async {
    final s = AppScope.of(context);
    final address = ctrl.text.trim();
    final ok = await ref
        .read(credentialsControllerProvider.notifier)
        .requestContinueOtp(email: address, countryCode: s.country.value);
    if (!mounted || !ok) return;
    s.setAuthContact(method: AuthMethod.email, email: address);
    // Held only for the length of the flow: if the code proves a NEW account
    // it becomes that account's password, and if it proves an existing one the
    // patient is asked whether to adopt it. Cleared either way.
    s.setAuthPassword(pwCtrl.text);
    setState(() => _offerCode = false);
    s.go(AppRoutes.otp);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // Subscribe: the bridge getters above read this provider's current state.
    ref.watch(credentialsControllerProvider);
    return Container(
      color: T.cream50,
      // Groups the email and password fields into one credential set, so the
      // platform manager saves them as a pair rather than two loose values.
      child: AutofillGroup(
          child: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          maxHeight: kContentBlockMaxHeight,
          child: Column(children: [
            _AuthHeader(onBack: () => s.go(AppRoutes.welcome), step: 1),
            Expanded(
                child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 18),
                // One title for both audiences. Which one this patient is, the
                // screen is not told and must not imply.
                Text(s.strings.emergency.em_one_title, style: Typo.title(ar: s.rtl)),
                const SizedBox(height: 8),
                Text(s.strings.emergency.em_one_help, style: Typo.body(ar: s.rtl)),
                const SizedBox(height: 24),
                _Label(s.strings.emergency.em_label, ar: s.rtl),
                const SizedBox(height: 8),
                _Input(
                    controller: ctrl,
                    id: 'emailField',
                    hint: s.strings.emergency.em_ph,
                    keyboard: TextInputType.emailAddress,
                    forceLtr: true,
                    accent: s.accent,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    onChanged: (_) => setState(() {})),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _Label(s.strings.auth.pw_label, ar: s.rtl),
                  // Shown to everyone now: the screen does not know whether
                  // this address has a password to forget.
                  GestureDetector(
                    onTap: _submitting ? null : () => _showForgotPassword(ctrl.text.trim()),
                    child: Text(s.strings.auth.forgot_pw,
                        style: Typo.meta(ar: s.rtl).copyWith(color: s.accent.main, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 8),
                _Input(
                    controller: pwCtrl,
                    id: 'passwordField',
                    hint: s.strings.auth.pw_ph,
                    obscure: !_showPw,
                    forceLtr: true,
                    accent: s.accent,
                    // `password`, not `newPassword`: the screen cannot know
                    // this is a signup, and asking iOS to generate a strong one
                    // for a returning patient would fight their saved entry.
                    autofillHints: const [AutofillHints.password],
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _showPw = !_showPw),
                      child: Icon(_showPw ? LucideIcons.eyeOff : LucideIcons.eye, size: 17, color: T.fg3),
                    ),
                    onChanged: (_) => setState(() {})),
              ]),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              child: Column(children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: Typo.meta(ar: s.rtl).copyWith(color: T.danger, fontWeight: FontWeight.w600)),
                  ),
                // The password was refused. Ask before sending anything: a
                // mistyped password would otherwise email whoever owns that
                // address, every time.
                if (_offerCode) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      s.strings.emergency.em_send_code_q(ctrl.text.trim()),
                      textAlign: TextAlign.center,
                      style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2, height: 1.5),
                    ),
                  ),
                  PButton(
                    s.strings.emergency.em_send_code,
                    variant: BtnVariant.primary,
                    large: true,
                    block: true,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: _submitting ? null : _sendCode,
                  ),
                  const SizedBox(height: 10),
                ],
                Opacity(
                    opacity: ok && !_submitting ? 1 : 0.4,
                    child: PButton(_submitting ? s.strings.auth.pw_signing_in : s.strings.auth.pw_continue,
                        variant: _offerCode ? BtnVariant.secondary : BtnVariant.primary,
                        large: true,
                        block: true,
                        accent: s.accent,
                        ar: s.rtl,
                        onTap: ok && !_submitting
                            ? () {
                                _continue();
                              }
                            : null)),
                const SizedBox(height: 14),
                TermsLine(s: s),
              ]),
            ),
          ]),
        ),
      )),
    );
  }
}

// ── Disclosure gate identity ─────────────────────────────────
// The consolidated privacy disclosure the post-sign-in gate enforces. Matches
// the id/version the disclosure module's routes default to (`consolidated` /
// `1`). Acceptance is tracked per (id, version), so bumping the version here
// re-gates every user until they accept the new notice (fail-closed).
const String _kDisclosureId = 'consolidated';
const String _kDisclosureVersion = '1';

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
  final accepted = await ref
      .read(disclosureDaoProvider)
      .watchAcceptance(
        const DisclosureId.value(_kDisclosureId),
        _kDisclosureVersion,
      )
      .first;
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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        const SheetGrab(),
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, sheetBottomInset(context, base: 24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(c.em_adopt_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(c.em_adopt_help, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3, height: 1.5)),
            const SizedBox(height: 20),
            PButton(
              c.em_adopt_yes,
              variant: BtnVariant.primary,
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
          ]),
        ),
      ]),
    );
  }
}

// ── OTP ──────────────────────────────────────────────────────
class _OtpScreen extends ConsumerStatefulWidget {
  const _OtpScreen();
  @override
  ConsumerState<_OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<_OtpScreen> {
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
      _ => e.message,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  /// Verifies the 6-digit code against the real auth module. On success the
  /// use-case has already persisted tokens + `balsm.user_id` to secure storage;
  /// we then transition to the app. Lockout (423) / invalid / geofence (403)
  /// surface inline and reset the boxes.
  Future<void> _verify(String code) async {
    final s = AppScope.of(context);
    final isNewUser = await ref.read(otpControllerProvider.notifier).verify(email: s.authEmail, code: code);
    if (!mounted) return;
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
    s.setAuthPassword(null); // transient either way — never persisted
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
              () => _notice = isNewUser ? s.strings.emergency.em_pw_set_failed : s.strings.emergency.em_adopt_failed);
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
    focus.dispose();
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(otpControllerProvider); // bridge getters read current state
    final s = AppScope.of(context);
    final code = ctrl.text;
    final contact = s.authEmail.isEmpty ? 'you@example.com' : s.authEmail;
    return Container(
      color: T.cream50,
      child: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          maxHeight: kContentBlockMaxHeight,
          child: Column(children: [
            _AuthHeader(onBack: () => s.go(AppRoutes.phone), step: 2),
            Expanded(
                child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),
                Text(s.strings.auth.otp_title, style: Typo.title(ar: s.rtl)),
                const SizedBox(height: 8),
                RichText(
                    text: TextSpan(style: Typo.body(ar: s.rtl), children: [
                  // Says nothing about whether this address has an account.
                  // The screen is reached identically either way, and the copy
                  // is the last place that distinction could leak.
                  TextSpan(text: '${s.strings.emergency.em_otp_neutral_h} '),
                  TextSpan(text: contact, style: const TextStyle(color: T.fg1, fontWeight: FontWeight.w700)),
                ])),
                if (_notice != null) ...[
                  const SizedBox(height: 12),
                  Text(_notice!,
                      style: Typo.meta(ar: s.rtl).copyWith(color: T.sun500, fontWeight: FontWeight.w600, height: 1.5)),
                ],
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () => focus.requestFocus(),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < 6; i++)
                      _OtpBox(
                        char: i < code.length ? code[i] : '',
                        active: code.length == i,
                        accent: s.accent,
                      ),
                  ]),
                ),
                Opacity(
                    opacity: 0,
                    child: SizedBox(
                        height: 1,
                        width: 1,
                        child: TextField(
                          controller: ctrl,
                          focusNode: focus,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6)
                          ],
                          onChanged: (v) {
                            setState(() {});
                            if (v.length == 6) _verify(v);
                          },
                        ))),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: Typo.meta(ar: s.rtl).copyWith(color: T.danger, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 24),
                Center(
                    child: secs > 0
                        ? RichText(
                            text: TextSpan(style: Typo.meta(ar: s.rtl), children: [
                            TextSpan(text: '${s.strings.auth.otp_in} '),
                            TextSpan(
                                text: '${secs}s', style: Typo.num(size: FS.xs, weight: FontWeight.w700, color: T.fg3)),
                          ]))
                        : PButton(s.strings.auth.otp_resend,
                            variant: BtnVariant.ghost,
                            accent: s.accent,
                            ar: s.rtl,
                            onTap: () => ref.read(otpControllerProvider.notifier).resend())),
              ]),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Opacity(
                  opacity: code.length == 6 && !_verifying ? 1 : 0.4,
                  child: PButton(_verifying ? s.strings.auth.otp_verifying : s.strings.auth.verify,
                      variant: BtnVariant.primary,
                      large: true,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: code.length == 6 && !_verifying
                          ? () {
                              _verify(code);
                            }
                          : null)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.char, required this.active, required this.accent});
  final String char;
  final bool active;
  final Accent accent;
  @override
  Widget build(BuildContext context) {
    final filled = char.isNotEmpty;
    // `.otp-box` — border + focus ring animate over --dur-base ease-out.
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.easeOut,
      width: 48,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(T.rMd),
        border: Border.all(color: active || filled ? accent.main : T.border, width: 1.5),
        boxShadow: active ? [BoxShadow(color: accent.bg, blurRadius: 0, spreadRadius: 4)] : null,
      ),
      child: Text(char, style: Typo.num(size: FS.xl2, weight: FontWeight.w600)),
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
          disclosureId: const DisclosureId.value(_kDisclosureId),
          version: _kDisclosureVersion,
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
      backgroundColor: T.cream50,
      body: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          maxHeight: kContentBlockMaxHeight,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
              child: Row(children: [
                RoundBtn(icon: backArrow(context), onTap: () => Navigator.of(context).maybePop()),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    style: Typo.body(ar: s.rtl).copyWith(color: T.fg2),
                  ),
                  const SizedBox(height: 20),
                  _gateSection(
                    s,
                    LucideIcons.database,
                    s.strings.privacy.pv_collect,
                    s.strings.privacy.pv_collect_body,
                  ),
                  _gateSection(
                    s,
                    LucideIcons.lock,
                    s.strings.privacy.pv_protect,
                    s.strings.privacy.pv_protect_body,
                  ),
                  _gateSection(
                    s,
                    LucideIcons.scale,
                    s.strings.privacy.pv_rights,
                    s.strings.privacy.pv_rights_body,
                  ),
                  _gateSection(
                    s,
                    LucideIcons.landmark,
                    s.strings.privacy.pv_authority,
                    s.strings.privacy.pv_authority_body(authority),
                  ),
                  _gateSection(
                    s,
                    LucideIcons.share2,
                    s.strings.privacy.pv_sharing2,
                    s.strings.privacy.pv_sharing_body,
                  ),
                  _gateSection(
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
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: Typo.meta(ar: s.rtl).copyWith(color: T.danger, fontWeight: FontWeight.w600)),
                  ),
                Opacity(
                  opacity: _readToEnd && !_submitting ? 1 : 0.4,
                  child: PButton(
                    _submitting ? (s.strings.privacy.pv_saving) : (s.strings.privacy.pv_agree),
                    variant: BtnVariant.primary,
                    large: true,
                    block: true,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: _readToEnd && !_submitting
                        ? () {
                            _accept();
                          }
                        : null,
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _gateSection(PatientAppState s, IconData icon, String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(T.rLg),
        border: Border.all(color: T.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: s.accent.main),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Typo.subhead(ar: s.rtl).copyWith(fontSize: FS.base, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2)),
          ]),
        ),
      ]),
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
    'ahmed'
  };

  void _setHandle(String raw) {
    final v = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
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
    debounce = Timer(const Duration(milliseconds: 700),
        () => setState(() => unStatus = _taken.contains(v) ? UsernameStatus.taken : UsernameStatus.available));
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
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const _UnderEighteenScreen(),
      ));
      return;
    }
    // The OTP-verify step already established the session (bearer token
    // persisted), so persist the collected identity to the server now. Without
    // this PATCH the display name, DOB, and gender were dropped on the floor and
    // GET /account/self came back empty — a blank account-details screen.
    setState(() => _creating = true);
    await ref.read(accountProfileUseCaseProvider).update(UpdateProfileInput(
          firstName: first.text.trim(),
          lastName: last.text.trim(),
          gender: gender,
          dateOfBirth: _isoDob(d),
        ));
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
    return Container(
      color: T.cream50,
      child: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          maxHeight: kContentBlockMaxHeight,
          child: Column(children: [
            _AuthHeader(onBack: () => s.go(AppRoutes.otp), step: 3),
            Expanded(
                child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),
                Text(s.strings.onboarding.pf_title, style: Typo.title(ar: s.rtl)),
                const SizedBox(height: 8),
                Text(s.strings.onboarding.pf_help, style: Typo.body(ar: s.rtl)),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                      child: _Field(
                          label: s.strings.onboarding.pf_fname,
                          ar: s.rtl,
                          child: _Input(
                              controller: first,
                              hint: s.strings.onboarding.pf_fname_ph,
                              accent: s.accent,
                              onChanged: (_) => setState(() {})))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _Field(
                          label: s.strings.onboarding.pf_lname,
                          ar: s.rtl,
                          child: _Input(
                              controller: last,
                              hint: s.strings.onboarding.pf_lname_ph,
                              accent: s.accent,
                              onChanged: (_) => setState(() {})))),
                ]),
                const SizedBox(height: 16),
                _UsernameField(controller: handle, status: unStatus, onChanged: _setHandle, s: s),
                const SizedBox(height: 16),
                _Field(
                    label: s.strings.onboarding.pf_dob,
                    ar: s.rtl,
                    child: GestureDetector(
                      onTap: _pickDob,
                      child: AbsorbPointer(
                        child: _Input(
                            controller: dob,
                            hint: 'DD / MM / YYYY',
                            mono: true,
                            forceLtr: true,
                            accent: s.accent,
                            prefixIcon: const Icon(LucideIcons.calendar, size: 18, color: T.fg3),
                            suffixIcon: const Icon(LucideIcons.chevronDown, size: 18, color: T.fg4)),
                      ),
                    )),
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
                    )),
              ]),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(children: [
                Opacity(
                    opacity: ok && !_creating ? 1 : 0.4,
                    child: PButton(_creating ? s.strings.onboarding.pf_creating : s.strings.onboarding.pf_create,
                        variant: BtnVariant.primary,
                        large: true,
                        block: true,
                        accent: s.accent,
                        ar: s.rtl,
                        onTap: ok && !_creating ? _createAccount : null)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(LucideIcons.shieldCheck, size: 14, color: T.fg3),
                  const SizedBox(width: 6),
                  Text(s.strings.onboarding.pf_secure, style: Typo.meta(ar: s.rtl)),
                ]),
              ]),
            ),
          ]),
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
      UsernameStatus.checking => (LucideIcons.loader, T.fg3, s.strings.auth.un_checking),
      UsernameStatus.available => (LucideIcons.checkCircle2, T.hueMint600, s.strings.auth.un_avail),
      UsernameStatus.taken => (LucideIcons.xCircle, T.danger, s.strings.auth.un_taken),
      UsernameStatus.invalid => (LucideIcons.alertCircle, T.sun500, s.strings.auth.un_invalid),
      _ => (null, T.fg4, ''),
    };
    return _Field(
        label: s.strings.auth.un_label,
        ar: s.rtl,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(alignment: Alignment.centerLeft, children: [
            _Input(
                controller: controller,
                hint: s.strings.auth.un_ph,
                mono: true,
                forceLtr: true,
                accent: s.accent,
                prefix: '@',
                onChanged: onChanged),
            if (status == UsernameStatus.checking)
              const Positioned(right: 12, child: Spinner(size: 16, stroke: 2, color: T.fg3))
            else if (icon != null)
              Positioned(right: 12, child: Icon(icon, size: 17, color: col)),
          ]),
          if (msg.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(msg, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: col))),
          if (controller.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                const Icon(LucideIcons.link, size: 12, color: T.fg4),
                const SizedBox(width: 5),
                Text(s.strings.profile.pd_handle_hint, style: Typo.num(size: FS.xs, color: T.fg3)),
              ]),
            ),
        ]));
  }
}

// ── Shared small widgets ─────────────────────────────────────
/// Two-option segmented control. Generic over the selected value [T]: the
/// caller supplies the [leftValue]/[rightValue] each segment stands for and the
/// current [value]; the active segment is the one whose value equals [value].
/// Use `_Segmented<bool>` for a plain toggle, `_Segmented<Gender>` for a typed
/// choice, etc. (Param is `V`, not `T` — `T` is the design-tokens class.)
class _Segmented<V> extends StatelessWidget {
  const _Segmented(
      {required this.left,
      required this.right,
      this.leftIcon,
      this.rightIcon,
      required this.leftValue,
      required this.rightValue,
      required this.value,
      required this.onChanged});
  final String left, right;
  final IconData? leftIcon, rightIcon;
  final V leftValue, rightValue;
  final V value;
  final ValueChanged<V> onChanged;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // `.segmented button` — active pill bg/shadow animate over --dur-base.
    Widget seg(String label, IconData? icon, bool active, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: Motion.base,
              curve: Motion.easeOut,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: active ? T.shadowXs : null),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 14, color: active ? T.fg1 : T.fg3), const SizedBox(width: 5)],
                Text(label,
                    style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: active ? T.fg1 : T.fg3)),
              ]),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
          color: T.ink50, borderRadius: BorderRadius.circular(T.rMd), border: Border.all(color: T.border)),
      child: Row(children: [
        seg(left, leftIcon, value == leftValue, () => onChanged(leftValue)),
        const SizedBox(width: 6),
        seg(right, rightIcon, value == rightValue, () => onChanged(rightValue)),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.ar});
  final String text;
  final bool ar;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: T.fg2));
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, required this.ar});
  final String label;
  final Widget child;
  final bool ar;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Label(label, ar: ar),
        const SizedBox(height: 8),
        child,
      ]);
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

  bool get _emailOk => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());
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
              color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Center(child: SheetGrab()),
            const SizedBox(height: 16),
            Text(_step == ResetStep.done ? s.strings.auth.fp_success : s.strings.auth.fp_title,
                style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_step == ResetStep.email) ...[
              Text(s.strings.auth.fp_help, style: Typo.body(ar: s.rtl).copyWith(color: T.fg2)),
              const SizedBox(height: 16),
              _Input(
                  controller: _email,
                  hint: s.strings.emergency.em_ph,
                  keyboard: TextInputType.emailAddress,
                  forceLtr: true,
                  accent: s.accent,
                  onChanged: (_) => setState(() {})),
            ] else if (_step == ResetStep.code) ...[
              RichText(
                  text: TextSpan(style: Typo.body(ar: s.rtl).copyWith(color: T.fg2), children: [
                TextSpan(text: '${s.strings.auth.fp_sent_help} '),
                TextSpan(text: _email.text.trim(), style: const TextStyle(color: T.fg1, fontWeight: FontWeight.w700)),
              ])),
              const SizedBox(height: 16),
              _Label(s.strings.auth.fp_code_label, ar: s.rtl),
              const SizedBox(height: 8),
              _Input(
                  controller: _code,
                  hint: '••••••',
                  keyboard: TextInputType.number,
                  mono: true,
                  forceLtr: true,
                  accent: s.accent,
                  onChanged: (_) => setState(() {})),
              const SizedBox(height: 14),
              _Label(s.strings.auth.fp_new_pw, ar: s.rtl),
              const SizedBox(height: 8),
              _Input(
                  controller: _newPw,
                  hint: s.strings.auth.pw_ph,
                  obscure: !_showPw,
                  forceLtr: true,
                  accent: s.accent,
                  suffixIcon: GestureDetector(
                      onTap: () => setState(() => _showPw = !_showPw),
                      child: Icon(_showPw ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: T.fg3)),
                  onChanged: (_) => setState(() {})),
            ],
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      style: Typo.meta(ar: s.rtl).copyWith(color: T.danger, fontWeight: FontWeight.w600))),
            const SizedBox(height: 20),
            if (_step == ResetStep.email)
              Opacity(
                  opacity: _emailOk && !_busy ? 1 : 0.4,
                  child: PButton(s.strings.auth.fp_send,
                      variant: BtnVariant.primary,
                      large: true,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: _emailOk && !_busy
                          ? () {
                              _sendCode();
                            }
                          : null))
            else if (_step == ResetStep.code)
              Opacity(
                  opacity: _resetOk && !_busy ? 1 : 0.4,
                  child: PButton(s.strings.auth.fp_reset,
                      variant: BtnVariant.primary,
                      large: true,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: _resetOk && !_busy
                          ? () {
                              _reset();
                            }
                          : null))
            else
              PButton(s.strings.auth.fp_done,
                  variant: BtnVariant.primary,
                  large: true,
                  block: true,
                  accent: s.accent,
                  ar: s.rtl,
                  onTap: () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input(
      {required this.controller,
      required this.hint,
      this.id,
      this.keyboard,
      this.mono = false,
      this.forceLtr = false,
      this.obscure = false,
      this.prefix,
      this.prefixIcon,
      this.suffixIcon,
      required this.accent,
      this.onChanged,
      this.autofillHints});
  final TextEditingController controller;
  final String hint;

  /// Stable test selector. Set it and the field becomes addressable by both
  /// drivers: Patrol matches the Flutter [Key], Maestro matches the platform
  /// accessibility identifier the semantics node exposes. Label text is not a
  /// usable selector — it is translated, so an Arabic run would miss it.
  final String? id;
  final TextInputType? keyboard;
  final bool mono;
  final bool forceLtr;
  final bool obscure;
  final String? prefix;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Accent accent;
  final ValueChanged<String>? onChanged;

  /// Tells the OS what this field holds, so the platform password manager can
  /// fill it and offer to save it. Null for fields that are not credentials —
  /// an OTP code or a display name must never be offered to a keychain.
  final List<String>? autofillHints;
  @override
  Widget build(BuildContext context) {
    final style = mono ? Typo.num(size: FS.lg) : Typo.body(ar: false).copyWith(fontSize: FS.lg, color: T.fg1);
    final field = TextField(
      key: id == null ? null : Key(id!),
      controller: controller,
      keyboardType: keyboard,
      onChanged: onChanged,
      obscureText: obscure,
      autofillHints: autofillHints,
      textDirection: forceLtr ? TextDirection.ltr : null,
      style: style,
      decoration: InputDecoration(
        isDense: true,
        prefixText: prefix,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        prefixStyle: Typo.num(size: FS.sm, weight: FontWeight.w700, color: T.fg3),
        hintText: hint,
        hintStyle: (mono ? Typo.num(size: FS.lg, color: T.fg4) : Typo.body().copyWith(fontSize: FS.lg, color: T.fg4)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: accent.main, width: 1.5)),
      ),
    );
    // Maestro selects on the platform accessibility identifier, which only
    // exists if a semantics node carries one; Patrol selects on the Key above.
    return id == null ? field : Semantics(identifier: id, child: field);
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton(
      {required this.label, required this.dark, this.googleG = false, this.busy = false, required this.onTap});
  final String label;
  final bool dark;
  final bool googleG;

  /// Spinner in place of the mark + label while this provider's flow runs.
  final bool busy;

  /// Null while any provider flow is in flight, so neither button re-enters.
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1A1A17) : Colors.white,
          borderRadius: BorderRadius.circular(T.rMd),
          border: dark ? null : Border.all(color: const Color(0x2E3C3C3A), width: 1.5),
        ),
        child: busy
            ? Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: dark ? Colors.white : const Color(0xFF3C3C3A)),
                ),
              )
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (googleG) const _GoogleMark(),
                const SizedBox(width: 10),
                // Flexible, not bare: the label is translated and text-scaled,
                // so a fixed-width row overflows on a narrow phone in Arabic.
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Typo.body(ar: s.rtl)
                          .copyWith(fontWeight: FontWeight.w600, color: dark ? Colors.white : const Color(0xFF3C3C3A))),
                ),
              ]),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => SvgPicture.string(_kGoogleGSvg, width: 18, height: 18);
}

const _kGoogleGSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
  <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
  <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z"/>
  <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
</svg>
''';
