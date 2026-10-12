import 'package:material_ui/material_ui.dart';

import '../kit.dart';
import '../tokens.dart';

// Shared auth-form fields, extracted from `screens/auth_flow.dart` so the
// go-online sheet reuses the sign-in look instead of copying it.

/// A text field in the sign-in style (white fill, 1.5 px border, accent focus).
class AuthInput extends StatelessWidget {
  const AuthInput(
      {super.key,
      required this.controller,
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

/// One painted box of the six-digit code row (`.otp-box`).
class OtpBox extends StatelessWidget {
  const OtpBox({super.key, required this.char, required this.active, required this.accent});
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
