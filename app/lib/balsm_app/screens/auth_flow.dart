import 'dart:async';
import 'package:account/account.dart'
    show accountProfileUseCaseProvider, claimHandleUseCaseProvider, UpdateProfileInput;
import 'package:auth/auth.dart'
    show ageGateUseCaseProvider, signUpUseCaseProvider, signInUseCaseProvider, SignInSuccess, SignInLockout;
import 'package:core/core.dart'
    show
        accountSummaryProvider,
        countryRegistryProvider,
        StatusScreen,
        LanguageCode,
        Gender,
        showBalsmDatePicker,
        BalsmWelcomeBackground;
import 'package:disclosure/disclosure.dart' show acceptDisclosureUseCaseProvider, disclosureDaoProvider, DisclosureId;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
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
      'walkthrough' => const WalkthroughScreen(),
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
    return BalsmWelcomeBackground(
      child: SafeArea(
        child: ContentColumn(
          maxWidth: 440,
          child: Column(children: [
            // `.wbody { margin-top: auto }` — lockup + CTAs sit on the cream
            // fade; watercolor fills the space above.
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
              child: Column(children: [
                SvgPicture.asset(Assets.brand_logo_vertical, width: 92, height: 92, fit: BoxFit.contain),
                const SizedBox(height: 22),
                Text(s.strings.onboarding.w_title, textAlign: TextAlign.center, style: Typo.display(ar: s.rtl)),
                const SizedBox(height: 12),
                Text(s.strings.onboarding.w_sub,
                    textAlign: TextAlign.center, style: Typo.body(ar: s.rtl).copyWith(color: T.fg2)),
                const SizedBox(height: 28),
                PButton(s.strings.onboarding.w_start(s.gender),
                    variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: s.rtl, onTap: () {
                  s.setAuthIntent('signup');
                  s.go('phone');
                }),
                const SizedBox(height: 16),
                _OrDivider(label: s.strings.onboarding.w_or, ar: s.rtl),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () {
                    s.setAuthIntent('signin');
                    s.go('phone');
                  },
                  child: RichText(
                      text: TextSpan(style: Typo.body(ar: s.rtl).copyWith(color: T.fg2), children: [
                    TextSpan(text: '${s.strings.onboarding.w_have} '),
                    TextSpan(
                        text: s.strings.onboarding.w_signin,
                        style: TextStyle(color: s.accent.main, fontWeight: FontWeight.w700)),
                  ])),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _trust(s, LucideIcons.smartphone, s.strings.settings.trust_device),
                const SizedBox(width: 22),
                _trust(s, LucideIcons.lock, s.strings.settings.trust_private),
                const SizedBox(width: 22),
                _trust(s, LucideIcons.cloudOff, s.strings.settings.trust_offline),
              ]),
            ),
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
  final ctrl = TextEditingController();
  final pwCtrl = TextEditingController();
  bool _showPw = false;
  String? _error;
  bool _submitting = false;

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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5C14202B),
      isScrollControlled: true,
      builder: (_) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _ForgotPasswordSheet(initialEmail: email, s: s),
        ),
      ),
    );
  }

  Future<void> _continue() async {
    final s = AppScope.of(context);
    final isSignup = s.authIntent == 'signup';
    final address = ctrl.text.trim();

    if (!isSignup) {
      setState(() {
        _submitting = true;
        _error = null;
      });
      final result = await ref.read(signInUseCaseProvider).passwordSignIn(email: address, password: pwCtrl.text);
      if (!mounted) return;
      setState(() => _submitting = false);
      result.fold(
        (signIn) {
          switch (signIn) {
            case SignInSuccess():
              s.setAuthContact(method: 'email', email: address);
              unawaited(enterAfterSignIn(context, ref, s));
            case SignInLockout(:final session):
              final secsLeft = session.until.difference(DateTime.now()).inSeconds.clamp(0, 3600);
              setState(() => _error = s.strings.auth.auth_locked_retry(secsLeft.toString()));
          }
        },
        (_) => setState(() => _error = s.strings.auth.pw_invalid_creds),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref.read(signUpUseCaseProvider).requestEmailOtp(address, s.country.value);
    if (!mounted) return;
    setState(() => _submitting = false);
    result.fold(
      (_) {
        s.setAuthContact(method: 'email', email: address);
        s.setAuthPassword(pwCtrl.text);
        s.go('otp');
      },
      (failure) => setState(() => _error = failure.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final isSignup = s.authIntent == 'signup';
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
                const SizedBox(height: 18),
                Text(isSignup ? s.strings.emergency.em_pw_signup_title : s.strings.emergency.em_pw_title,
                    style: Typo.title(ar: s.rtl)),
                const SizedBox(height: 8),
                Text(isSignup ? s.strings.emergency.em_pw_signup_help : s.strings.emergency.em_pw_help,
                    style: Typo.body(ar: s.rtl)),
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
                    onChanged: (_) => setState(() {})),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _Label(s.strings.auth.pw_label, ar: s.rtl),
                  if (!isSignup)
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
                Opacity(
                    opacity: ok && !_submitting ? 1 : 0.4,
                    child: PButton(
                        _submitting && !isSignup
                            ? s.strings.auth.pw_signing_in
                            : (isSignup ? s.strings.auth.pw_signup : s.strings.auth.pw_signin),
                        variant: BtnVariant.primary,
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
    final result = await ref.read(signInUseCaseProvider).verifyEmailOtp(email: s.authEmail, code: code);
    if (!mounted) return;
    setState(() => _verifying = false);
    result.fold(
      (signInResult) {
        switch (signInResult) {
          case SignInSuccess(:final isNewUser):
            unawaited(_afterVerify(s, isNewUser: isNewUser));
          case SignInLockout(:final session):
            final secsLeft = session.until.difference(DateTime.now()).inSeconds.clamp(0, 3600);
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
    final contact = s.authEmail.isEmpty ? 'you@example.com' : s.authEmail;
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
                  TextSpan(text: '${s.strings.emergency.em_otp_h} '),
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
                        : PButton(s.strings.auth.otp_resend, variant: BtnVariant.ghost, accent: s.accent, ar: s.rtl,
                            onTap: () {
                            setState(() => secs = 28);
                            _tick();
                          })),
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
    ref.invalidate(accountSummaryProvider);
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
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);
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

  bool get _emailOk => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());
  bool get _resetOk => _code.text.trim().length >= 4 && _newPw.text.length >= 8;

  Future<void> _sendCode() async {
    if (!_emailOk || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Forgot-password reuses the OTP-request endpoint to send the reset code.
    final r = await ref.read(signInUseCaseProvider).requestEmailOtp(_email.text.trim(), widget.s.country.value);
    if (!mounted) return;
    setState(() => _busy = false);
    r.fold((_) => setState(() => _step = 'code'), (f) => setState(() => _error = f.message));
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
    r.fold((_) => setState(() => _step = 'done'), (f) => setState(() => _error = f.message));
  }

  @override
  Widget build(BuildContext context) {
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
            Center(
                child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 16),
            Text(_step == 'done' ? s.strings.auth.fp_success : s.strings.auth.fp_title,
                style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_step == 'email') ...[
              Text(s.strings.auth.fp_help, style: Typo.body(ar: s.rtl).copyWith(color: T.fg2)),
              const SizedBox(height: 16),
              _Input(
                  controller: _email,
                  hint: s.strings.emergency.em_ph,
                  keyboard: TextInputType.emailAddress,
                  forceLtr: true,
                  accent: s.accent,
                  onChanged: (_) => setState(() {})),
            ] else if (_step == 'code') ...[
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
            if (_step == 'email')
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
            else if (_step == 'code')
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
      this.onChanged});
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
  @override
  Widget build(BuildContext context) {
    final style = mono ? Typo.num(size: FS.lg) : Typo.body(ar: false).copyWith(fontSize: FS.lg, color: T.fg1);
    final field = TextField(
      key: id == null ? null : Key(id!),
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
    // Maestro selects on the platform accessibility identifier, which only
    // exists if a semantics node carries one; Patrol selects on the Key above.
    return id == null ? field : Semantics(identifier: id, child: field);
  }
}
