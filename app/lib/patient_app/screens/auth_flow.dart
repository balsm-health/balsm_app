import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              Text(s.t('w_title'), textAlign: TextAlign.center, style: Typo.display(ar: s.rtl)),
              const SizedBox(height: 12),
              Text(s.t('w_sub'), textAlign: TextAlign.center, style: Typo.body(ar: s.rtl).copyWith(color: T.fg2)),
              const SizedBox(height: 28),
              PButton(s.t('w_start'),
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
                    child: Text(s.t('w_or'), style: Typo.meta(ar: s.rtl))),
                const Expanded(child: Divider(color: T.ink200)),
              ]),
              const SizedBox(height: 14),
              _SocialButton(label: s.t('w_apple'), dark: true, icon: Icons.apple, onTap: () => s.go('profile')),
              const SizedBox(height: 12),
              _SocialButton(label: s.t('w_google'), dark: false, googleG: true, onTap: () => s.go('profile')),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => s.go('phone'),
                child: RichText(
                    text: TextSpan(style: Typo.body(ar: s.rtl).copyWith(color: T.fg2), children: [
                  TextSpan(text: '${s.t('w_have')} '),
                  TextSpan(text: s.t('w_signin'), style: TextStyle(color: s.accent.main, fontWeight: FontWeight.w700)),
                ])),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _trust(s, LucideIcons.smartphone, s.t('trust_device')),
              _trust(s, LucideIcons.lock, s.t('trust_private')),
              _trust(s, LucideIcons.cloudOff, s.t('trust_offline')),
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
    return GestureDetector(
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
                child: Text('G',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF4285F4))))
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

// ── Phone / email ────────────────────────────────────────────
class _PhoneScreen extends StatefulWidget {
  const _PhoneScreen();
  @override
  State<_PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<_PhoneScreen> {
  bool email = false;
  final ctrl = TextEditingController();
  bool get ok {
    final v = ctrl.text.trim();
    return email ? RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v) : v.replaceAll(RegExp(r'\D'), '').length >= 10;
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
                left: s.t('ph_label'),
                leftIcon: LucideIcons.phone,
                right: s.t('em_label'),
                rightIcon: LucideIcons.mail,
                rightActive: email,
                onChanged: (r) => setState(() {
                  email = r;
                  ctrl.clear();
                }),
              ),
              const SizedBox(height: 24),
              Text(email ? s.t('em_title') : s.t('ph_title'), style: Typo.title(ar: s.rtl)),
              const SizedBox(height: 8),
              Text(email ? s.t('em_help') : s.t('ph_help'), style: Typo.body(ar: s.rtl)),
              const SizedBox(height: 24),
              _Label(email ? s.t('em_label') : s.t('ph_label'), ar: s.rtl),
              const SizedBox(height: 8),
              if (email)
                _Input(
                    controller: ctrl,
                    hint: s.t('em_ph'),
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
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(children: [
              Opacity(
                  opacity: ok ? 1 : 0.4,
                  child: PButton(s.t('continue'),
                      variant: BtnVariant.primary,
                      large: true,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: ok ? () => s.go('otp') : null)),
              const SizedBox(height: 14),
              Text(s.t('ph_terms'), textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
            ]),
          ),
        ]),
        ),
      ),
    );
  }
}

// ── OTP ──────────────────────────────────────────────────────
class _OtpScreen extends StatefulWidget {
  const _OtpScreen();
  @override
  State<_OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<_OtpScreen> {
  final ctrl = TextEditingController();
  final focus = FocusNode();
  int secs = 28;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
    _tick();
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
              Text(s.t('otp_title'), style: Typo.title(ar: s.rtl)),
              const SizedBox(height: 8),
              RichText(
                  text: TextSpan(style: Typo.body(ar: s.rtl), children: [
                TextSpan(text: '${s.t('otp_help')} '),
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
                          if (v.length == 6)
                            Future.delayed(const Duration(milliseconds: 280), () {
                              if (mounted) s.go('profile');
                            });
                        },
                      ))),
              const SizedBox(height: 24),
              Center(
                  child: secs > 0
                      ? RichText(
                          text: TextSpan(style: Typo.meta(ar: s.rtl), children: [
                          TextSpan(text: '${s.t('otp_in')} '),
                          TextSpan(
                              text: '${secs}s', style: Typo.num(size: FS.xs, weight: FontWeight.w700, color: T.fg3)),
                        ]))
                      : PButton(s.t('otp_resend'), variant: BtnVariant.ghost, accent: s.accent, ar: s.rtl, onTap: () {
                          setState(() => secs = 28);
                          _tick();
                        })),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Opacity(
                opacity: code.length == 6 ? 1 : 0.4,
                child: PButton(s.t('verify'),
                    variant: BtnVariant.primary,
                    large: true,
                    block: true,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: code.length == 6 ? () => s.go('profile') : null)),
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
    return Container(
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
    if (handle.text != v)
      handle.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
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
              Text(s.t('pf_title'), style: Typo.title(ar: s.rtl)),
              const SizedBox(height: 8),
              Text(s.t('pf_help'), style: Typo.body(ar: s.rtl)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: _Field(
                        label: s.t('pf_fname'),
                        ar: s.rtl,
                        child: _Input(
                            controller: first,
                            hint: s.t('pf_fname_ph'),
                            accent: s.accent,
                            onChanged: (_) => setState(() {})))),
                const SizedBox(width: 12),
                Expanded(
                    child: _Field(
                        label: s.t('pf_lname'),
                        ar: s.rtl,
                        child: _Input(
                            controller: last,
                            hint: s.t('pf_lname_ph'),
                            accent: s.accent,
                            onChanged: (_) => setState(() {})))),
              ]),
              const SizedBox(height: 16),
              _UsernameField(controller: handle, status: unStatus, onChanged: _setHandle, s: s),
              const SizedBox(height: 16),
              _Field(
                  label: s.t('pf_dob'),
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
                  label: s.t('pf_gender'),
                  ar: s.rtl,
                  child: _Segmented(
                    left: s.t('pf_female'),
                    right: s.t('pf_male'),
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
                  child: PButton(s.t('pf_create'),
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
                Text(s.t('pf_secure'), style: Typo.meta(ar: s.rtl)),
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
      'checking' => (LucideIcons.loader, T.fg3, s.t('un_checking')),
      'available' => (LucideIcons.checkCircle2, T.petalMint600, s.t('un_avail')),
      'taken' => (LucideIcons.xCircle, T.danger, s.t('un_taken')),
      'invalid' => (LucideIcons.alertCircle, T.sun500, s.t('un_invalid')),
      _ => (null, T.fg4, ''),
    };
    return _Field(
        label: s.t('un_label'),
        ar: s.rtl,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(alignment: Alignment.centerLeft, children: [
            _Input(
                controller: controller,
                hint: s.t('un_ph'),
                mono: true,
                forceLtr: true,
                accent: s.accent,
                prefix: '@',
                onChanged: onChanged),
            if (icon != null) Positioned(right: 12, child: Icon(icon, size: 17, color: col)),
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
    Widget seg(String label, IconData? icon, bool active, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
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
