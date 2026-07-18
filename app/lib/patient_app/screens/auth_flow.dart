import 'dart:async';
import 'package:auth/auth.dart'
    show
        ageGateUseCaseProvider,
        signUpUseCaseProvider,
        signInUseCaseProvider,
        SignInSuccess,
        SignInLockout;
import 'package:core/core.dart' show countryRegistryProvider, StatusScreen;
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
              Text(s.strings.w_title, textAlign: TextAlign.center, style: Typo.display(ar: s.rtl)),
              const SizedBox(height: 12),
              Text(s.strings.w_sub, textAlign: TextAlign.center, style: Typo.body(ar: s.rtl).copyWith(color: T.fg2)),
              const SizedBox(height: 28),
              PButton(s.strings.w_start,
                  variant: BtnVariant.primary,
                  large: true,
                  block: true,
                  accent: s.accent,
                  ar: s.rtl,
                  onTap: () => s.go('phone')),
              const SizedBox(height: 14),
              Row(children: [
                const Expanded(child: Divider(color: T.ink200)),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(s.strings.w_or, style: Typo.meta(ar: s.rtl))),
                const Expanded(child: Divider(color: T.ink200)),
              ]),
              const SizedBox(height: 14),
              // Social sign-in has no real backend wired here (no google_sign_in /
              // sign_in_with_apple tokens available), and must NOT bypass the
              // fail-closed DOB/age gate. Funnel into the real email sign-up flow.
              _SocialButton(label: s.strings.w_apple, dark: true, icon: Icons.apple, onTap: () => s.go('phone')),
              const SizedBox(height: 12),
              _SocialButton(label: s.strings.w_google, dark: false, googleG: true, onTap: () => s.go('phone')),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => s.go('phone'),
                child: RichText(
                    text: TextSpan(style: Typo.body(ar: s.rtl).copyWith(color: T.fg2), children: [
                  TextSpan(text: '${s.strings.w_have} '),
                  TextSpan(text: s.strings.w_signin, style: TextStyle(color: s.accent.main, fontWeight: FontWeight.w700)),
                ])),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _trust(s, LucideIcons.smartphone, s.strings.trust_device),
              _trust(s, LucideIcons.lock, s.strings.trust_private),
              _trust(s, LucideIcons.cloudOff, s.strings.trust_offline),
            ]),
          ),
          const SizedBox(height: 26),
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
                  s.strings.na_not_available,
                  textAlign: TextAlign.center,
                  style: Typo.display(ar: s.rtl),
                ),
                const SizedBox(height: 12),
                Text(
                  s.rtl
                      ? 'بلسم متاح حاليًا لمن هم في سن 18 وأكثر. نعمل على إصدار للمستخدمين الأصغر سنًا بموافقة ولي الأمر.'
                      : 'Balsm is currently available for ages 18 and older. We\'re working on a version for younger users with parental consent.',
                  textAlign: TextAlign.center,
                  style: Typo.body(ar: s.rtl).copyWith(color: T.fg2),
                ),
                const SizedBox(height: 28),
                PButton(
                  s.strings.na_notify_me,
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
                    s.strings.na_status_support,
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
  bool email = true; // Email is the only path with a real OTP backend.
  final ctrl = TextEditingController();
  final dobCtrl = TextEditingController();
  DateTime? _dob;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    ctrl.dispose();
    dobCtrl.dispose();
    super.dispose();
  }

  bool get ok {
    final v = ctrl.text.trim();
    final contactOk = email
        ? RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
        : v.replaceAll(RegExp(r'\D'), '').length >= 10;
    // DOB is REQUIRED — no continue without it (fail-closed).
    return contactOk && _dob != null;
  }

  String _fmtDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dob = picked;
      dobCtrl.text = _fmtDob(picked);
      _error = null;
    });
  }

  Future<void> _continue() async {
    final s = AppScope.of(context);

    // Fail-closed gate #1 — DOB missing/invalid → do NOT proceed.
    final dob = _dob;
    if (dob == null) {
      setState(() => _error = s.rtl
          ? 'من فضلك اختر تاريخ ميلاد صالح.'
          : 'Please choose a valid date of birth.');
      return;
    }

    // Fail-closed gate #2 — age gate (PDPL / G3). Under-18 → soft-block screen,
    // no OTP, no session. AgeGateUseCase.validate() is synchronous.
    final ageResult = ref.read(ageGateUseCaseProvider).validate(dob);
    if (ageResult.isFailure) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const _UnderEighteenScreen(),
        ),
      );
      return;
    }

    // Phone OTP is not backed by the real API (email + Google/Apple only).
    if (!email) {
      setState(() => _error = s.rtl
          ? 'تسجيل الدخول عبر الهاتف غير متاح بعد — استخدم البريد الإلكتروني.'
          : 'Phone sign-in isn\'t available yet — please use email.');
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
        .requestEmailOtp(address, s.countryCode);
    if (!mounted) return;
    setState(() => _submitting = false);
    result.fold(
      (_) {
        s.setAuthContact(method: 'email', email: address);
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
                left: s.strings.ph_label,
                leftIcon: LucideIcons.phone,
                right: s.strings.em_label,
                rightIcon: LucideIcons.mail,
                rightActive: email,
                onChanged: (r) => setState(() {
                  email = r;
                  ctrl.clear();
                  _error = null;
                }),
              ),
              const SizedBox(height: 24),
              Text(email ? s.strings.em_title : s.strings.ph_title, style: Typo.title(ar: s.rtl)),
              const SizedBox(height: 8),
              Text(email ? s.strings.em_help : s.strings.ph_help, style: Typo.body(ar: s.rtl)),
              const SizedBox(height: 24),
              _Label(email ? s.strings.em_label : s.strings.ph_label, ar: s.rtl),
              const SizedBox(height: 8),
              if (email)
                _Input(
                    controller: ctrl,
                    hint: s.strings.em_ph,
                    keyboard: TextInputType.emailAddress,
                    forceLtr: true,
                    accent: s.accent,
                    onChanged: (_) => setState(() {}))
              else
                Row(children: [
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(T.rMd),
                        border: Border.all(color: T.border, width: 1.5)),
                    child: Row(children: [
                      const Text('🇪🇬', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text('+20', style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.lg, fontWeight: FontWeight.w600))
                    ]),
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
              // Date of birth — REQUIRED. Tapping opens a date picker (guarantees
              // a valid DateTime); feeds the fail-closed age gate on continue.
              const SizedBox(height: 20),
              _Field(
                label: s.strings.pf_dob,
                ar: s.rtl,
                child: GestureDetector(
                  onTap: _submitting ? null : _pickDob,
                  child: AbsorbPointer(
                    child: _Input(
                        controller: dobCtrl,
                        hint: 'DD / MM / YYYY',
                        mono: true,
                        forceLtr: true,
                        accent: s.accent,
                        prefixIcon: const Icon(LucideIcons.calendar, size: 18, color: T.fg3),
                        suffixIcon: const Icon(LucideIcons.chevronDown, size: 18, color: T.fg4)),
                  ),
                ),
              ),
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
                  child: PButton(s.strings.continue_,
                      variant: BtnVariant.primary,
                      large: true,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: ok && !_submitting ? () { _continue(); } : null)),
              const SizedBox(height: 14),
              Text(s.strings.ph_terms, textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
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
          case SignInSuccess():
            // Session persisted by the use-case — but do NOT grant access yet.
            // Interpose the fail-closed disclosure gate before reaching 'app'.
            unawaited(_enterAfterSignIn(s));
          case SignInLockout(:final session):
            final secsLeft =
                session.until.difference(DateTime.now()).inSeconds.clamp(0, 3600);
            setState(() {
              _error = s.rtl
                  ? 'الحساب مقفل مؤقتًا. حاول بعد $secsLeft ثانية.'
                  : 'Account temporarily locked. Try again in ${secsLeft}s.';
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

  /// Disclosure-acceptance GATE — interposed between a successful sign-in and
  /// reaching 'app'. Fail-closed: a user who has not accepted the CURRENT
  /// consolidated-disclosure version never reaches the app. A returning user
  /// who already accepted this version skips straight through.
  ///
  /// The check reads the real on-device acceptance store (Tier-1
  /// `DisclosureDao.watchAcceptance`); presentation goes through
  /// [_DisclosureGateScreen], which — on accept — runs the real
  /// `AcceptDisclosureUseCase` (persist + cloud sync + domain event) and pops
  /// `true`. Only a persisted acceptance unlocks 'app'.
  Future<void> _enterAfterSignIn(PatientAppState s) async {
    // Already accepted this disclosure version on-device? → straight in.
    final accepted = await ref
        .read(disclosureDaoProvider)
        .watchAcceptance(
          const DisclosureId.value(_kDisclosureId),
          _kDisclosureVersion,
        )
        .first;
    if (!mounted) return;
    if (accepted != null) {
      s.go('app');
      return;
    }
    // Not accepted → present the gate. Pushed over the OTP screen so backing
    // out (without accepting) simply returns here — no 'app' access is granted.
    final didAccept = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _DisclosureGateScreen(state: s),
      ),
    );
    if (!mounted) return;
    if (didAccept == true) s.go('app');
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
              Text(s.strings.otp_title, style: Typo.title(ar: s.rtl)),
              const SizedBox(height: 8),
              RichText(
                  text: TextSpan(style: Typo.body(ar: s.rtl), children: [
                TextSpan(text: '${s.strings.otp_help} '),
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
                          TextSpan(text: '${s.strings.otp_in} '),
                          TextSpan(
                              text: '${secs}s', style: Typo.num(size: FS.xs, weight: FontWeight.w700, color: T.fg3)),
                        ]))
                      : PButton(s.strings.otp_resend, variant: BtnVariant.ghost, accent: s.accent, ar: s.rtl, onTap: () {
                          setState(() => secs = 28);
                          _tick();
                        })),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Opacity(
                opacity: code.length == 6 && !_verifying ? 1 : 0.4,
                child: PButton(s.strings.verify,
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
          countryCode: s.countryCode,
          supervisoryAuthority: registry.supervisoryAuthority(s.countryCode),
          preferredLanguage: s.lang,
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
        ref.watch(countryRegistryProvider).supervisoryAuthority(s.countryCode);
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
                        s.strings.pv_title,
                        style: Typo.display(ar: s.rtl),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.rtl
                            ? 'قبل المتابعة، يرجى مراجعة كيفية تعاملنا مع بياناتك. تبقى بياناتك الصحية على جهازك.'
                            : 'Before you continue, please review how we handle your data. Your health data stays on your device.',
                        style: Typo.body(ar: s.rtl).copyWith(color: T.fg2),
                      ),
                      const SizedBox(height: 20),
                      _gateSection(
                        s,
                        LucideIcons.database,
                        s.strings.pv_collect,
                        s.rtl
                            ? 'حساب أساسي غير صحي (البريد، البلد، اللغة). تبقى السجلات الصحية مشفّرة على جهازك.'
                            : 'A minimal non-health account (email, country, language). Health records stay encrypted on your device.',
                      ),
                      _gateSection(
                        s,
                        LucideIcons.lock,
                        s.strings.pv_protect,
                        s.rtl
                            ? 'تشفير على مستوى الجهاز، ونقل عبر قنوات آمنة، ووصول محدود بأقل قدر ممكن.'
                            : 'On-device encryption, secure transport, and least-privilege access.',
                      ),
                      _gateSection(
                        s,
                        LucideIcons.scale,
                        s.strings.pv_rights,
                        s.rtl
                            ? 'يمكنك الوصول إلى بياناتك أو تصحيحها أو حذفها في أي وقت من إعدادات الحساب.'
                            : 'Access, correct, or delete your data at any time from account settings.',
                      ),
                      _gateSection(
                        s,
                        LucideIcons.landmark,
                        s.strings.pv_authority,
                        s.rtl
                            ? 'الجهة المشرفة على حماية بياناتك في بلدك: $authority.'
                            : 'The authority overseeing your data protection in your country: $authority.',
                      ),
                      _gateSection(
                        s,
                        LucideIcons.share2,
                        s.strings.pv_sharing2,
                        s.rtl
                            ? 'لا نبيع بياناتك. لا تتم المشاركة إلا بموافقتك الصريحة أو عند وجود إلزام قانوني.'
                            : 'We never sell your data. Sharing happens only with your explicit consent or a legal obligation.',
                      ),
                      _gateSection(
                        s,
                        LucideIcons.trash2,
                        s.strings.pv_deletion,
                        s.rtl
                            ? 'يؤدي حذف حسابك إلى إزالة بياناتك السحابية غير الصحية ومسح السجلات من جهازك.'
                            : 'Deleting your account removes your non-health cloud data and wipes on-device records.',
                      ),
                      const SizedBox(height: 8),
                      if (!_readToEnd)
                        Center(
                          child: Text(
                            s.rtl
                                ? 'مرّر للأسفل للمتابعة'
                                : 'Scroll down to continue',
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
                        ? (s.strings.pv_saving)
                        : (s.strings.pv_agree),
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
class _ProfileSetupScreen extends StatefulWidget {
  const _ProfileSetupScreen();
  @override
  State<_ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<_ProfileSetupScreen> {
  final first = TextEditingController();
  final last = TextEditingController();
  final handle = TextEditingController();
  final dob = TextEditingController();
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

  bool get ok => '${first.text} ${last.text}'.trim().length > 1 && (unStatus == 'available' || unStatus == 'idle');

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
              Text(s.strings.pf_title, style: Typo.title(ar: s.rtl)),
              const SizedBox(height: 8),
              Text(s.strings.pf_help, style: Typo.body(ar: s.rtl)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: _Field(
                        label: s.strings.pf_fname,
                        ar: s.rtl,
                        child: _Input(
                            controller: first,
                            hint: s.strings.pf_fname_ph,
                            accent: s.accent,
                            onChanged: (_) => setState(() {})))),
                const SizedBox(width: 12),
                Expanded(
                    child: _Field(
                        label: s.strings.pf_lname,
                        ar: s.rtl,
                        child: _Input(
                            controller: last,
                            hint: s.strings.pf_lname_ph,
                            accent: s.accent,
                            onChanged: (_) => setState(() {})))),
              ]),
              const SizedBox(height: 16),
              _UsernameField(controller: handle, status: unStatus, onChanged: _setHandle, s: s),
              const SizedBox(height: 16),
              _Field(
                  label: s.strings.pf_dob,
                  ar: s.rtl,
                  child: _Input(
                      controller: dob,
                      hint: 'DD / MM / YYYY',
                      keyboard: TextInputType.number,
                      mono: true,
                      forceLtr: true,
                      accent: s.accent,
                      prefixIcon: const Icon(LucideIcons.calendar, size: 18, color: T.fg3),
                      suffixIcon: const Icon(LucideIcons.chevronDown, size: 18, color: T.fg4))),
              const SizedBox(height: 16),
              _Field(
                  label: s.strings.pf_gender,
                  ar: s.rtl,
                  child: _Segmented(
                    left: s.strings.pf_female,
                    right: s.strings.pf_male,
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
                  child: PButton(s.strings.pf_create,
                      variant: BtnVariant.primary,
                      large: true,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: ok ? () => s.go('app') : null)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(LucideIcons.shieldCheck, size: 14, color: T.fg3),
                const SizedBox(width: 6),
                Text(s.strings.pf_secure, style: Typo.meta(ar: s.rtl)),
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
      'checking' => (LucideIcons.loader, T.fg3, s.strings.un_checking),
      'available' => (LucideIcons.checkCircle2, T.petalMint600, s.strings.un_avail),
      'taken' => (LucideIcons.xCircle, T.danger, s.strings.un_taken),
      'invalid' => (LucideIcons.alertCircle, T.sun500, s.strings.un_invalid),
      _ => (null, T.fg4, ''),
    };
    return _Field(
        label: s.strings.un_label,
        ar: s.rtl,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(alignment: Alignment.centerLeft, children: [
            _Input(
                controller: controller,
                hint: s.strings.un_ph,
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

class _Input extends StatelessWidget {
  const _Input(
      {required this.controller,
      required this.hint,
      this.keyboard,
      this.mono = false,
      this.forceLtr = false,
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
