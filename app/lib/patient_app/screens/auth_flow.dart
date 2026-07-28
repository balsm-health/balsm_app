import 'dart:async';
import 'package:auth/auth.dart'
    show
        ageGateUseCaseProvider,
        signUpUseCaseProvider,
        signInUseCaseProvider,
        SignInSuccess,
        SignInLockout;
import 'package:core/core.dart'
    show
        countryRegistryProvider,
        StatusScreen,
        CountryCode,
        CountryCodeL10n,
        LanguageCode;
import 'package:disclosure/disclosure.dart'
    show acceptDisclosureUseCaseProvider, disclosureDaoProvider, DisclosureId;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/balsm_flower.dart';

/// Routes the auth flow by `state.route`.
class AuthRouter extends StatelessWidget {
  const AuthRouter({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return switch (s.route) {
      'phone' => const _PhoneScreen(),
      'otp' => const _OtpScreen(),
      'profile' => const _ProfileSetupScreen(),
      _ => const _WelcomeScreen(),
    };
  }
}

// ── Welcome ──────────────────────────────────────────────────
class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [T.cream50, T.cream100, T.cream50]),
      ),
      child: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          child: Column(children: [
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
            child: Column(children: [
              const BalsmFlower(size: 84),
              const SizedBox(height: 22),
              Text(s.strings.onboarding.w_title, textAlign: TextAlign.center, style: Typo.display(ar: s.rtl)),
              const SizedBox(height: 12),
              Text(s.strings.onboarding.w_sub, textAlign: TextAlign.center, style: Typo.body(ar: s.rtl).copyWith(color: T.fg2)),
              const SizedBox(height: 28),
              PButton(s.g(s.strings.onboarding.w_start_select),
                  variant: BtnVariant.primary,
                  large: true,
                  block: true,
                  accent: s.accent,
                  ar: s.rtl,
                  onTap: () {
                    s.setAuthIntent('signup');
                    s.go('phone');
                  }),
              const SizedBox(height: 14),
              Row(children: [
                const Expanded(child: Divider(color: T.ink200)),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(s.strings.onboarding.w_or, style: Typo.meta(ar: s.rtl))),
                const Expanded(child: Divider(color: T.ink200)),
              ]),
              const SizedBox(height: 14),
              // Social sign-in has no real backend wired here (no google_sign_in /
              // sign_in_with_apple tokens available), and must NOT bypass the
              // fail-closed DOB/age gate. Funnel into the real email sign-up flow.
              _SocialButton(label: s.strings.onboarding.w_apple, dark: true, icon: Icons.apple, onTap: () {
                s.setAuthIntent('signup');
                s.go('phone');
              }),
              const SizedBox(height: 12),
              _SocialButton(label: s.strings.onboarding.w_google, dark: false, googleG: true, onTap: () {
                s.setAuthIntent('signup');
                s.go('phone');
              }),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {
                  s.setAuthIntent('signin');
                  s.go('phone');
                },
                child: RichText(
                    text: TextSpan(style: Typo.body(ar: s.rtl).copyWith(color: T.fg2), children: [
                  TextSpan(text: '${s.strings.onboarding.w_have} '),
                  TextSpan(text: s.strings.onboarding.w_signin, style: TextStyle(color: s.accent.main, fontWeight: FontWeight.w700)),
                ])),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _trust(s, LucideIcons.smartphone, s.strings.settings.trust_device),
              _trust(s, LucideIcons.lock, s.strings.settings.trust_private),
              _trust(s, LucideIcons.cloudOff, s.strings.settings.trust_offline),
            ]),
          ),
          const SizedBox(height: 16),
          // Language toggle pill (AR ⇄ EN) — updated design.
          Center(
            child: GestureDetector(
              onTap: () => s.setLang(
                  s.lang == LanguageCode.ar ? LanguageCode.en : LanguageCode.ar),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: T.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.languages, size: 17, color: T.fg2),
                  const SizedBox(width: 7),
                  // Endonym of the OTHER language — the toggle's target.
                  Text((s.lang == LanguageCode.ar ? LanguageCode.en : LanguageCode.ar).nativeName,
                      style: Typo.bodySm(ar: s.lang != LanguageCode.ar)
                          .copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 22),
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
              style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs2, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.dark, this.icon, this.googleG = false, required this.onTap});
  final String label;
  final bool dark;
  final IconData? icon;
  final bool googleG;
  final VoidCallback onTap;
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
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (googleG)
            Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                child: const Text('G',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF4285F4))))
          else
            Icon(icon, size: 19, color: Colors.white),
          const SizedBox(width: 10),
          Text(label,
              style: Typo.body(ar: s.rtl)
                  .copyWith(fontWeight: FontWeight.w600, color: dark ? Colors.white : const Color(0xFF3C3C3A))),
        ]),
      ),
    );
  }
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
        RoundBtn(icon: LucideIcons.arrowLeft, onTap: onBack),
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
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(children: [
                RoundBtn(icon: LucideIcons.arrowLeft, onTap: () => Navigator.of(context).maybePop()),
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

// ── Phone / email ────────────────────────────────────────────
// Sign-up step (real auth). Collects the contact + date of birth, runs the
// fail-closed age gate BEFORE any session can exist, and — on the email path —
// requests a real OTP via [signUpUseCaseProvider]. The phone path has no OTP
// backend (email + social only) so it is blocked rather than faked.
class _PhoneScreen extends ConsumerStatefulWidget {
  const _PhoneScreen();
  @override
  ConsumerState<_PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<_PhoneScreen> {
  bool email = true; // Email is the only path with a real OTP/password backend.
  String emailAuth = 'password'; // email sub-mode: 'password' | 'code'
  final ctrl = TextEditingController();
  final pwCtrl = TextEditingController();
  bool _showPw = false;
  String? _error;
  bool _submitting = false;
  // Selected phone dial-code country; defaults to the home country (EG).
  CountryCode _dialCountry = kHomeCountry;

  /// Email + password sign-in sub-mode (returning users). Phone + the email
  /// one-time-code path are NOT password mode.
  bool get isPw => email && emailAuth == 'password';

  @override
  void dispose() {
    ctrl.dispose();
    pwCtrl.dispose();
    super.dispose();
  }

  bool get ok {
    final v = ctrl.text.trim();
    final contactOk = email
        ? RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
        : v.replaceAll(RegExp(r'\D'), '').length >= 10;
    // Password sign-in also needs a password (>=8). The one-time-code path
    // needs only a valid contact — the age gate runs at profile setup.
    return isPw ? contactOk && pwCtrl.text.length >= 8 : contactOk;
  }

  Future<void> _pickDialCode(PatientAppState s) async {
    final picked = await showModalBottomSheet<CountryCode>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5C2B2B25),
      isScrollControlled: true,
      builder: (_) => _DialCodeSheet(current: _dialCountry, s: s),
    );
    if (picked != null && mounted) setState(() => _dialCountry = picked);
  }

  void _showForgotPassword(String email) {
    final s = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5C2B2B25),
      isScrollControlled: true,
      builder: (_) => _ForgotPasswordSheet(initialEmail: email, s: s),
    );
  }

  Future<void> _continue() async {
    final s = AppScope.of(context);
    final isSignup = s.authIntent == 'signup';

    // ── Email + password → sign IN a returning user. No DOB / age gate here
    // (the account passed it at sign-up); still routed through the shared
    // fail-closed disclosure gate before 'app'. Sign-UP with a password takes
    // the OTP path below, then applies setPassword after verify.
    if (isPw && !isSignup) {
      final address = ctrl.text.trim();
      setState(() {
        _submitting = true;
        _error = null;
      });
      final result = await ref
          .read(signInUseCaseProvider)
          .passwordSignIn(email: address, password: pwCtrl.text);
      if (!mounted) return;
      setState(() => _submitting = false);
      result.fold(
        (signIn) {
          switch (signIn) {
            case SignInSuccess():
              s.setAuthContact(method: 'email', email: address);
              unawaited(enterAfterSignIn(context, ref, s));
            case SignInLockout(:final session):
              final secsLeft = session.until
                  .difference(DateTime.now())
                  .inSeconds
                  .clamp(0, 3600);
              setState(() =>
                  _error = s.strings.auth.auth_locked_retry(secsLeft.toString()));
          }
        },
        // Uniform message — never reveal whether the account or password is wrong.
        (_) => setState(() => _error = s.strings.auth.pw_invalid_creds),
      );
      return;
    }

    // One-time-code path (email or phone). No age gate here — it runs at
    // profile setup for a NEW account (design-aligned): a returning user
    // signing in with a code isn't asked for DOB.

    // Phone OTP is not backed by the real API (email + Google/Apple only).
    if (!email) {
      setState(() => _error = s.strings.auth.auth_phone_soon);
      return;
    }

    // Email path — request a real OTP via the auth module.
    final address = ctrl.text.trim();
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref
        .read(signUpUseCaseProvider)
        .requestEmailOtp(address, s.country.value);
    if (!mounted) return;
    setState(() => _submitting = false);
    result.fold(
      (_) {
        s.setAuthContact(method: 'email', email: address);
        // Password sign-up: stash the chosen password; applied via setPassword
        // once OTP verify establishes the session.
        s.setAuthPassword(isPw ? pwCtrl.text : null);
        s.go('otp');
      },
      (failure) => setState(() => _error = failure.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      color: T.cream50,
      child: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          child: Column(children: [
          _AuthHeader(onBack: () => s.go('welcome'), step: 1),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 10),
              _Segmented(
                left: s.strings.auth.ph_label,
                leftIcon: LucideIcons.phone,
                right: s.strings.emergency.em_label,
                rightIcon: LucideIcons.mail,
                rightActive: email,
                onChanged: (r) => setState(() {
                  email = r;
                  ctrl.clear();
                  pwCtrl.clear();
                  _error = null;
                }),
              ),
              const SizedBox(height: 24),
              Text(
                  isPw
                      ? s.strings.emergency.em_pw_title
                      : (email ? s.strings.emergency.em_title : s.strings.auth.ph_title),
                  style: Typo.title(ar: s.rtl)),
              const SizedBox(height: 8),
              Text(
                  isPw
                      ? s.strings.emergency.em_pw_help
                      : (email ? s.strings.emergency.em_help : s.strings.auth.ph_help),
                  style: Typo.body(ar: s.rtl)),
              const SizedBox(height: 24),
              _Label(email ? s.strings.emergency.em_label : s.strings.auth.ph_label, ar: s.rtl),
              const SizedBox(height: 8),
              if (email)
                _Input(
                    controller: ctrl,
                    hint: s.strings.emergency.em_ph,
                    keyboard: TextInputType.emailAddress,
                    forceLtr: true,
                    accent: s.accent,
                    onChanged: (_) => setState(() {}))
              else
                Row(children: [
                  _DialCodeButton(
                    country: _dialCountry,
                    onTap: _submitting
                        ? null
                        : () => _pickDialCode(s),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Input(
                          controller: ctrl,
                          hint: '10 1234 5678',
                          keyboard: TextInputType.phone,
                          mono: true,
                          forceLtr: true,
                          accent: s.accent,
                          onChanged: (_) => setState(() {}))),
                ]),

              // Email + password → password field + forgot link.
              if (isPw) ...[
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _Label(s.strings.auth.pw_label, ar: s.rtl),
                  // No "forgot password" on sign-up — nothing to recover yet.
                  if (s.authIntent != 'signup')
                    GestureDetector(
                      onTap: _submitting
                          ? null
                          : () => _showForgotPassword(ctrl.text.trim()),
                      child: Text(s.strings.auth.forgot_pw,
                          style: Typo.meta(ar: s.rtl)
                              .copyWith(color: s.accent.main, fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 8),
                _Input(
                    controller: pwCtrl,
                    hint: s.strings.auth.pw_ph,
                    obscure: !_showPw,
                    forceLtr: true,
                    accent: s.accent,
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _showPw = !_showPw),
                      child: Icon(_showPw ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 18, color: T.fg3),
                    ),
                    onChanged: (_) => setState(() {})),
              ],

              // Email: switch between password sign-in and one-time-code sign-up.
              if (email) ...[
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _submitting
                        ? null
                        : () => setState(() {
                              emailAuth = isPw ? 'code' : 'password';
                              _error = null;
                            }),
                    child: Text(isPw ? s.strings.auth.use_code : s.strings.auth.use_password,
                        style: Typo.bodySm(ar: s.rtl)
                            .copyWith(color: s.accent.main, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style: Typo.meta(ar: s.rtl).copyWith(color: T.danger, fontWeight: FontWeight.w600)),
                ),
              Opacity(
                  opacity: ok && !_submitting ? 1 : 0.4,
                  child: PButton(isPw && s.authIntent != 'signup' ? s.strings.auth.pw_signin : s.strings.common.continue_,
                      variant: BtnVariant.primary,
                      large: true,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: ok && !_submitting ? () { _continue(); } : null)),
              const SizedBox(height: 14),
              Text(s.strings.auth.ph_terms, textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
            ]),
          ),
        ]),
        ),
      ),
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
Future<void> enterAfterSignIn(
    BuildContext context, WidgetRef ref, PatientAppState s) async {
  final accepted = await ref
      .read(disclosureDaoProvider)
      .watchAcceptance(
        const DisclosureId.value(_kDisclosureId),
        _kDisclosureVersion,
      )
      .first;
  if (!context.mounted) return;
  if (accepted != null) {
    s.go('app');
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
  if (didAccept == true) s.go('app');
}

// ── OTP ──────────────────────────────────────────────────────
class _OtpScreen extends ConsumerStatefulWidget {
  const _OtpScreen();
  @override
  ConsumerState<_OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<_OtpScreen> {
  final ctrl = TextEditingController();
  final focus = FocusNode();
  int secs = 28;
  Timer? timer;
  String? _error;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
    _tick();
  }

  /// Verifies the 6-digit code against the real auth module. On success the
  /// use-case has already persisted tokens + `balsm.user_id` to secure storage;
  /// we then transition to the app. Lockout (423) / invalid / geofence (403)
  /// surface inline and reset the boxes.
  Future<void> _verify(String code) async {
    if (_verifying) return;
    final s = AppScope.of(context);
    setState(() {
      _verifying = true;
      _error = null;
    });
    final result = await ref
        .read(signInUseCaseProvider)
        .verifyEmailOtp(email: s.authEmail, code: code);
    if (!mounted) return;
    setState(() => _verifying = false);
    result.fold(
      (signInResult) {
        switch (signInResult) {
          case SignInSuccess(:final isNewUser):
            unawaited(_afterVerify(s, isNewUser: isNewUser));
          case SignInLockout(:final session):
            final secsLeft =
                session.until.difference(DateTime.now()).inSeconds.clamp(0, 3600);
            setState(() {
              _error = s.strings.auth.auth_locked_retry(secsLeft.toString());
              ctrl.clear();
            });
        }
      },
      (failure) => setState(() {
        _error = failure.message;
        ctrl.clear();
      }),
    );
  }

  /// Post-verify navigation. On the password sign-up path a password was stashed
  /// on the app state — the session now exists, so apply it via setPassword
  /// (best-effort: the account is already usable regardless) before routing.
  Future<void> _afterVerify(PatientAppState s, {required bool isNewUser}) async {
    final pw = s.authPassword;
    if (pw != null && pw.isNotEmpty) {
      await ref.read(signInUseCaseProvider).setPassword(password: pw);
      s.setAuthPassword(null); // clear the transient password
    }
    if (!mounted) return;
    // New account → profile setup (name/handle/DOB + the fail-closed age gate).
    // Returning user → straight to the disclosure gate.
    if (isNewUser) {
      s.go('profile');
    } else {
      unawaited(enterAfterSignIn(context, ref, s));
    }
  }

  void _tick() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secs <= 0) {
        t.cancel();
        return;
      }
      setState(() => secs--);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    focus.dispose();
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final code = ctrl.text;
    final contact =
        s.authMethod == 'email' ? (s.authEmail.isEmpty ? 'you@example.com' : s.authEmail) : '+20 10 1234 5678';
    return Container(
      color: T.cream50,
      child: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          child: Column(children: [
          _AuthHeader(onBack: () => s.go('phone'), step: 2),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              Text(s.strings.auth.otp_title, style: Typo.title(ar: s.rtl)),
              const SizedBox(height: 8),
              RichText(
                  text: TextSpan(style: Typo.body(ar: s.rtl), children: [
                TextSpan(text: '${s.strings.auth.otp_help} '),
                TextSpan(text: contact, style: const TextStyle(color: T.fg1, fontWeight: FontWeight.w700)),
              ])),
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
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
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
                      : PButton(s.strings.auth.otp_resend, variant: BtnVariant.ghost, accent: s.accent, ar: s.rtl, onTap: () {
                          setState(() => secs = 28);
                          _tick();
                        })),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Opacity(
                opacity: code.length == 6 && !_verifying ? 1 : 0.4,
                child: PButton(s.strings.auth.verify,
                    variant: BtnVariant.primary,
                    large: true,
                    block: true,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: code.length == 6 && !_verifying ? () { _verify(code); } : null)),
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
  ConsumerState<_DisclosureGateScreen> createState() =>
      _DisclosureGateScreenState();
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
    if (!_readToEnd &&
        _scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 4) {
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
    final authority =
        ref.watch(countryRegistryProvider).supervisoryAuthority(s.country.value);
    return Scaffold(
      backgroundColor: T.cream50,
      body: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
              child: Row(children: [
                RoundBtn(
                    icon: LucideIcons.arrowLeft,
                    onTap: () => Navigator.of(context).maybePop()),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: s.accent.bg, shape: BoxShape.circle),
                        child: Icon(LucideIcons.shieldCheck,
                            size: 34, color: s.accent.main),
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
                        style: Typo.meta(ar: s.rtl)
                            .copyWith(color: T.danger, fontWeight: FontWeight.w600)),
                  ),
                Opacity(
                  opacity: _readToEnd && !_submitting ? 1 : 0.4,
                  child: PButton(
                    _submitting
                        ? (s.strings.privacy.pv_saving)
                        : (s.strings.privacy.pv_agree),
                    variant: BtnVariant.primary,
                    large: true,
                    block: true,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: _readToEnd && !_submitting ? () { _accept(); } : null,
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _gateSection(
      PatientAppState s, IconData icon, String title, String body) {
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
            Text(title,
                style: Typo.subhead(ar: s.rtl)
                    .copyWith(fontSize: FS.base, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(body,
                style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2)),
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
  String gender = 'female';
  String unStatus = 'idle'; // idle | checking | available | taken | invalid
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
      setState(() => unStatus = 'idle');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(v)) {
      setState(() => unStatus = 'invalid');
      return;
    }
    setState(() => unStatus = 'checking');
    debounce = Timer(
        const Duration(milliseconds: 700), () => setState(() => unStatus = _taken.contains(v) ? 'taken' : 'available'));
  }

  bool get ok =>
      '${first.text} ${last.text}'.trim().length > 1 &&
      _dobDate != null &&
      (unStatus == 'available' || unStatus == 'idle');

  String _fmtDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';

  Future<void> _pickDob() async {
    final s = AppScope.of(context);
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5C2B2B25),
      isScrollControlled: true,
      builder: (_) => _DobCalendarSheet(initial: _dobDate, s: s),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dobDate = picked;
      dob.text = _fmtDob(picked);
    });
  }

  /// Design-aligned age gate: it runs HERE, on a NEW account, not before the
  /// OTP. Under-18 → soft-block screen; otherwise complete sign-up through the
  /// shared fail-closed disclosure gate.
  void _createAccount() {
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
          child: Column(children: [
          _AuthHeader(onBack: () => s.go('otp'), step: 3),
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
                  child: _Segmented(
                    left: s.strings.onboarding.pf_female,
                    right: s.strings.onboarding.pf_male,
                    rightActive: gender == 'male',
                    onChanged: (r) => setState(() => gender = r ? 'male' : 'female'),
                  )),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(children: [
              Opacity(
                  opacity: ok ? 1 : 0.4,
                  child: PButton(s.strings.onboarding.pf_create,
                      variant: BtnVariant.primary,
                      large: true,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: ok ? _createAccount : null)),
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
  final String status;
  final ValueChanged<String> onChanged;
  final PatientAppState s;
  @override
  Widget build(BuildContext context) {
    final (icon, col, msg) = switch (status) {
      'checking' => (LucideIcons.loader, T.fg3, s.strings.auth.un_checking),
      'available' => (LucideIcons.checkCircle2, T.petalMint600, s.strings.auth.un_avail),
      'taken' => (LucideIcons.xCircle, T.danger, s.strings.auth.un_taken),
      'invalid' => (LucideIcons.alertCircle, T.sun500, s.strings.auth.un_invalid),
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
            if (status == 'checking')
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
                Text('balsm.health/@${controller.text}',
                    textDirection: TextDirection.ltr,
                    style: Typo.num(size: FS.xs, color: T.fg3)),
              ]),
            ),
        ]));
  }
}

// ── Shared small widgets ─────────────────────────────────────
class _Segmented extends StatelessWidget {
  const _Segmented(
      {required this.left,
      required this.right,
      this.leftIcon,
      this.rightIcon,
      required this.rightActive,
      required this.onChanged});
  final String left, right;
  final IconData? leftIcon, rightIcon;
  final bool rightActive;
  final ValueChanged<bool> onChanged;
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
        seg(left, leftIcon, !rightActive, () => onChanged(false)),
        const SizedBox(width: 6),
        seg(right, rightIcon, rightActive, () => onChanged(true)),
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

// ── Dial-code picker (phone) ─────────────────────────────────
/// Regional-indicator flag emoji from a 2-letter ISO country code.
String _flagEmoji(String code) {
  if (code.length != 2) return '🏳️';
  return String.fromCharCodes(
      code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + (c - 0x41)));
}

class _DialCodeButton extends StatelessWidget {
  const _DialCodeButton({required this.country, required this.onTap});
  final CountryCode country;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(T.rMd),
            border: Border.all(color: T.border, width: 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_flagEmoji(country.value), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Text(country.dialCode,
              textDirection: TextDirection.ltr,
              style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.lg, fontWeight: FontWeight.w600)),
          const SizedBox(width: 2),
          const Icon(LucideIcons.chevronDown, size: 15, color: T.fg3),
        ]),
      ),
    );
  }
}

class _DialCodeSheet extends StatelessWidget {
  const _DialCodeSheet({required this.current, required this.s});
  final CountryCode current;
  final PatientAppState s;
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: s.dir,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: const BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 38, height: 4, decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 12),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(s.strings.auth.dial_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)))),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: CountryCode.known
                  .map((c) => GestureDetector(
                        onTap: () => Navigator.pop(context, c),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          child: Row(children: [
                            Text(_flagEmoji(c.value), style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(c.name(kCatalog, locale: s.lang.value), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600))),
                            Text(c.dialCode, textDirection: TextDirection.ltr, style: Typo.num(size: FS.sm, weight: FontWeight.w700, color: T.fg3)),
                            if (c == current)
                              Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: Icon(LucideIcons.checkCircle2, size: 18, color: s.accent.main)),
                          ]),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ]),
      ),
    );
  }
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
  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _newPw = TextEditingController();
  String _step = 'email'; // email | code | done
  bool _busy = false;
  bool _showPw = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPw.dispose();
    super.dispose();
  }

  bool get _emailOk =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());
  bool get _resetOk => _code.text.trim().length >= 4 && _newPw.text.length >= 8;

  Future<void> _sendCode() async {
    if (!_emailOk || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Forgot-password reuses the OTP-request endpoint to send the reset code.
    final r = await ref
        .read(signInUseCaseProvider)
        .requestEmailOtp(_email.text.trim(), widget.s.country.value);
    if (!mounted) return;
    setState(() => _busy = false);
    r.fold((_) => setState(() => _step = 'code'),
        (f) => setState(() => _error = f.message));
  }

  Future<void> _reset() async {
    if (!_resetOk || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(signInUseCaseProvider).resetPassword(
          email: _email.text.trim(),
          code: _code.text.trim(),
          newPassword: _newPw.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    r.fold((_) => setState(() => _step = 'done'),
        (f) => setState(() => _error = f.message));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Directionality(
      textDirection: s.dir,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 16),
            Text(_step == 'done' ? s.strings.auth.fp_success : s.strings.auth.fp_title,
                style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_step == 'email') ...[
              Text(s.strings.auth.fp_help, style: Typo.body(ar: s.rtl).copyWith(color: T.fg2)),
              const SizedBox(height: 16),
              _Input(controller: _email, hint: s.strings.emergency.em_ph, keyboard: TextInputType.emailAddress, forceLtr: true, accent: s.accent, onChanged: (_) => setState(() {})),
            ] else if (_step == 'code') ...[
              RichText(text: TextSpan(style: Typo.body(ar: s.rtl).copyWith(color: T.fg2), children: [
                TextSpan(text: '${s.strings.auth.fp_sent_help} '),
                TextSpan(text: _email.text.trim(), style: const TextStyle(color: T.fg1, fontWeight: FontWeight.w700)),
              ])),
              const SizedBox(height: 16),
              _Label(s.strings.auth.fp_code_label, ar: s.rtl),
              const SizedBox(height: 8),
              _Input(controller: _code, hint: '••••••', keyboard: TextInputType.number, mono: true, forceLtr: true, accent: s.accent, onChanged: (_) => setState(() {})),
              const SizedBox(height: 14),
              _Label(s.strings.auth.fp_new_pw, ar: s.rtl),
              const SizedBox(height: 8),
              _Input(controller: _newPw, hint: s.strings.auth.pw_ph, obscure: !_showPw, forceLtr: true, accent: s.accent,
                  suffixIcon: GestureDetector(onTap: () => setState(() => _showPw = !_showPw), child: Icon(_showPw ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: T.fg3)),
                  onChanged: (_) => setState(() {})),
            ],
            if (_error != null)
              Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: Typo.meta(ar: s.rtl).copyWith(color: T.danger, fontWeight: FontWeight.w600))),
            const SizedBox(height: 20),
            if (_step == 'email')
              Opacity(opacity: _emailOk && !_busy ? 1 : 0.4, child: PButton(s.strings.auth.fp_send, variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: s.rtl, onTap: _emailOk && !_busy ? () { _sendCode(); } : null))
            else if (_step == 'code')
              Opacity(opacity: _resetOk && !_busy ? 1 : 0.4, child: PButton(s.strings.auth.fp_reset, variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: s.rtl, onTap: _resetOk && !_busy ? () { _reset(); } : null))
            else
              PButton(s.strings.auth.fp_done, variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: s.rtl, onTap: () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }
}

// ── Date-of-birth calendar sheet ─────────────────────────────
class _DobCalendarSheet extends StatefulWidget {
  const _DobCalendarSheet({required this.initial, required this.s});
  final DateTime? initial;
  final PatientAppState s;
  @override
  State<_DobCalendarSheet> createState() => _DobCalendarSheetState();
}

class _DobCalendarSheetState extends State<_DobCalendarSheet> {
  late int _y;
  late int _m; // 0-based
  DateTime? _sel;
  bool _yearMode = false;


  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final init = widget.initial ?? DateTime(now.year - 25, now.month);
    _y = init.year;
    _m = init.month - 1;
    _sel = widget.initial;
  }

  void _prev() => setState(() {
        if (_m == 0) { _m = 11; _y--; } else { _m--; }
      });
  void _next() => setState(() {
        if (_m == 11) { _m = 0; _y++; } else { _m++; }
      });

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final rtl = s.rtl;
    // Pipe-separated lists in the i69n bundle (`cal_months`/`cal_weekdays`).
    final months = s.strings.settings.cal_months.split('|');
    final wd = s.strings.settings.cal_weekdays.split('|');
    final now = DateTime.now();
    final firstWeekday = DateTime(_y, _m + 1, 1).weekday % 7; // Sun=0
    final daysIn = DateTime(_y, _m + 2, 0).day;
    final years = [for (var y = now.year; y >= 1920; y--) y];

    return Directionality(
      textDirection: s.dir,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: const BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 38, height: 4, decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
            Expanded(child: Text(s.strings.onboarding.dob_title, style: Typo.subhead(ar: rtl).copyWith(fontWeight: FontWeight.w700))),
            RoundBtn(icon: LucideIcons.x, onTap: () => Navigator.pop(context)),
          ])),
          const SizedBox(height: 8),
          Flexible(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              RoundBtn(icon: rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft, onTap: _prev),
              GestureDetector(onTap: () => setState(() => _yearMode = !_yearMode), child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${months[_m]} $_y', style: Typo.subhead(ar: rtl).copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 4), const Icon(LucideIcons.chevronDown, size: 15, color: T.fg3),
              ])),
              RoundBtn(icon: rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight, onTap: _next),
            ]),
            const SizedBox(height: 12),
            if (_yearMode)
              GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.9, children: years
                  .map((y) => GestureDetector(onTap: () => setState(() { _y = y; _yearMode = false; }), child: Container(alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: y == _y ? s.accent.main : T.border, width: 1.5), color: y == _y ? s.accent.main : Colors.white), child: Text('$y', style: Typo.num(size: FS.sm, weight: FontWeight.w600, color: y == _y ? Colors.white : T.fg1)))))
                  .toList())
            else ...[
              Row(children: wd.map((w) => Expanded(child: Center(child: Text(w, style: Typo.meta(ar: rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg3))))).toList()),
              const SizedBox(height: 6),
              GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 7, mainAxisSpacing: 2, crossAxisSpacing: 2, children: [
                for (var i = 0; i < firstWeekday; i++) const SizedBox(),
                for (var d = 1; d <= daysIn; d++)
                  Builder(builder: (_) {
                    final date = DateTime(_y, _m + 1, d);
                    final disabled = date.isAfter(now);
                    final active = _sel != null && _sel!.year == _y && _sel!.month == _m + 1 && _sel!.day == d;
                    return GestureDetector(
                      onTap: disabled ? null : () => setState(() => _sel = date),
                      child: Container(alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? s.accent.main : Colors.transparent),
                          child: Text('$d', style: Typo.num(size: FS.sm, weight: active ? FontWeight.w700 : FontWeight.w500, color: disabled ? T.ink200 : active ? Colors.white : T.fg1))),
                    );
                  }),
              ]),
            ],
            const SizedBox(height: 16),
          ]))),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 20),
            child: Opacity(opacity: _sel != null ? 1 : 0.4, child: PButton(_sel != null ? s.strings.onboarding.dob_confirm : s.strings.onboarding.dob_select, variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: rtl, onTap: _sel != null ? () => Navigator.pop(context, _sel) : null)),
          ),
        ]),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input(
      {required this.controller,
      required this.hint,
      this.keyboard,
      this.mono = false,
      this.forceLtr = false,
      this.obscure = false,
      this.prefix,
      this.prefixIcon,
      this.suffixIcon,
      required this.accent,
      this.onChanged});
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final bool mono;
  final bool forceLtr;
  final bool obscure;
  final String? prefix;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Accent accent;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) {
    final style = mono ? Typo.num(size: FS.lg) : Typo.body(ar: false).copyWith(fontSize: FS.lg, color: T.fg1);
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      onChanged: onChanged,
      obscureText: obscure,
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
  }
}
