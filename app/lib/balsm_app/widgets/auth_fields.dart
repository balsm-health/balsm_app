import 'package:flutter/services.dart';
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

/// Opens the keyboard for a code field's hidden input. After a trip to
/// another app the field still has focus but its input connection is gone, so
/// neither requestFocus nor a bare keyboard-show does anything. Dropping focus
/// and taking it back once that has settled opens a fresh connection, and the
/// keyboard with it (#98).
void reopenCodeKeyboard(FocusNode focus, {required bool Function() mounted}) {
  if (!focus.hasFocus) {
    focus.requestFocus();
    return;
  }
  focus.unfocus();
  Future<void>.delayed(Duration.zero, () {
    if (mounted()) focus.requestFocus();
  });
}

/// The code in text that was pasted or offered by the keyboard: `123 456`,
/// `123-456` and "Your code is 123456" all read as `123456` (#99). A message
/// with other numbers in it yields only a group of exactly six digits; when
/// there is none and the digits run past six, it is not guessed at (null).
/// Fewer than six digits are kept, so a partial paste fills what it can.
String? codeFromText(String? text) {
  if (text == null) return null;
  final group = RegExp(r'(?<!\d)\d{3}[ -]?\d{3}(?!\d)').firstMatch(text);
  if (group != null) return group[0]!.replaceAll(RegExp(r'\D'), '');
  final digits = text.replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty || digits.length > 6 ? null : digits;
}

/// The code field's only formatter. A keystroke must be a digit and the code
/// stops at six; anything inserted at once, a paste or the keyboard's
/// one-time-code suggestion, replaces the field with the code found in it.
class CodeInputFormatter extends TextInputFormatter {
  const CodeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.length - oldValue.text.length <= 1) {
      final ok = RegExp(r'^\d{0,6}$').hasMatch(newValue.text);
      return ok ? newValue : oldValue;
    }
    final start = oldValue.selection.start;
    final end = newValue.selection.end;
    final inserted =
        start >= 0 && end >= start && end <= newValue.text.length ? newValue.text.substring(start, end) : newValue.text;
    final code = codeFromText(inserted);
    if (code == null) return oldValue;
    return TextEditingValue(text: code, selection: TextSelection.collapsed(offset: code.length));
  }
}

/// The code on the clipboard, read the same way as a paste into the field.
Future<String?> clipboardCode() async => codeFromText((await Clipboard.getData(Clipboard.kTextPlain))?.text);

/// Long-press on the code boxes shows the platform's Paste button, as a text
/// field would. The real input is hidden, so it cannot offer one itself (#99).
void showCodePasteMenu(BuildContext context, Offset at, VoidCallback onPaste) {
  ContextMenuController().show(
    context: context,
    contextMenuBuilder: (_) => AdaptiveTextSelectionToolbar.buttonItems(
      anchors: TextSelectionToolbarAnchors(primaryAnchor: at),
      buttonItems: [
        ContextMenuButtonItem(
          type: ContextMenuButtonType.paste,
          onPressed: () {
            ContextMenuController.removeAny();
            onPaste();
          },
        ),
      ],
    ),
  );
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
