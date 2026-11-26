import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../auth/auth_flow_controllers.dart';
import '../kit.dart';
import '../maintenance/maintenance_guard.dart';
import '../routes.dart';
import '../widgets/auth_fields.dart';

/// Opens the go-online sheet (design: `GoOnlineSheet`): email → code → done.
Future<void> showGoOnlineSheet(BuildContext context) async {
  if (maintenancePaused(context)) return;
  final s = AppScope.of(context);
  return showAppSheet<void>(
    context,
    textDirection: s.dir,
    builder: (_) => _GoOnlineSheet(s: s),
  );
}

/// Gate for anything that needs a server account (sharing, Balsm Cloud) —
/// never for on-device data. True when the account is online; a device-only
/// account gets the go-online sheet first, and this answers whether it came
/// back online.
Future<bool> requireOnline(BuildContext context) async {
  final s = AppScope.of(context);
  if (s.accountMode != AccountMode.deviceOnly) return true;
  await showGoOnlineSheet(context);
  return s.accountMode == AccountMode.online;
}

/// The sheet's text for an [AuthError].
String? _errorText(PatientAppState s, AuthError? e) => switch (e) {
      null => null,
      AuthError(kind: AuthErrorKind.lockout, :final lockoutSecs) =>
        s.strings.auth.auth_locked_retry(lockoutSecs.toString()),
      AuthError(kind: AuthErrorKind.server, :final message?) => message,
      _ => s.strings.offline.go_failed(s.gender),
    };

class _GoOnlineSheet extends ConsumerStatefulWidget {
  const _GoOnlineSheet({required this.s});
  final PatientAppState s;
  @override
  ConsumerState<_GoOnlineSheet> createState() => _GoOnlineSheetState();
}

/// View state only: the two fields and the code focus. The step machine,
/// errors and the resend countdown live in [GoOnlineSheetController].
class _GoOnlineSheetState extends ConsumerState<_GoOnlineSheet> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();

  PatientAppState get s => widget.s;

  @override
  void dispose() {
    ContextMenuController.removeAny();
    _email.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!isPlausibleEmail(_email.text)) return;
    final sent = await ref.read(goOnlineSheetControllerProvider.notifier).sendCode(_email.text.trim());
    if (!sent || !mounted) return;
    _code.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _codeFocus.requestFocus();
    });
  }

  void _showCodeKeyboard() {
    ContextMenuController.removeAny();
    reopenCodeKeyboard(_codeFocus, mounted: () => mounted);
  }

  /// Fills the boxes from the clipboard; a whole code submits at once (#99).
  Future<void> _pasteCode() async {
    final code = await clipboardCode();
    if (code == null || !mounted || ref.read(goOnlineSheetControllerProvider).busy) return;
    _code.text = code;
    if (code.length == 6) unawaited(_verify());
  }

  Future<void> _verify() async {
    final code = _code.text;
    if (code.length != 6) return;
    final nav = Navigator.of(context);
    final result =
        await ref.read(goOnlineSheetControllerProvider.notifier).verify(email: _email.text.trim(), code: code);
    switch (result) {
      case null:
        return;
      case GoOnlineVerifyResult.online:
        // Update the UI gates even if the sheet was dismissed mid-verify.
        s.setAccountMode(AccountMode.online);
        if (mounted) unawaited(HapticFeedback.lightImpact());
      case GoOnlineVerifyResult.needsMergeChoice:
        if (mounted) nav.pop();
        s.go(AppRoutes.mergeOrDiscard);
      case GoOnlineVerifyResult.failedButOnline:
        s.setAccountMode(AccountMode.online);
        if (mounted) _code.clear();
      case GoOnlineVerifyResult.failed:
        if (mounted) _code.clear();
      case GoOnlineVerifyResult.refused:
        if (!mounted) return;
        unawaited(HapticFeedback.heavyImpact());
        _code.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The device-only account's email, once storage has answered.
    ref.listen(goOnlineSheetControllerProvider.select((st) => st.email), (_, email) {
      if (email != null && _email.text.isEmpty) _email.text = email;
    });
    final step = ref.watch(goOnlineSheetControllerProvider.select((st) => st.step));
    final error = ref.watch(goOnlineSheetControllerProvider.select((st) => st.error));
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
              if (step == GoOnlineStep.done)
                _DoneStep(s: s)
              else ...[
                Text(s.strings.offline.go_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (step == GoOnlineStep.email)
                  _EmailStep(s: s, email: _email)
                else
                  _CodeStep(
                    s: s,
                    email: _email.text.trim(),
                    code: _code,
                    focus: _codeFocus,
                    onShowKeyboard: _showCodeKeyboard,
                    onPaste: _pasteCode,
                    onComplete: () => unawaited(_verify()),
                    onResend: () => unawaited(_send()),
                  ),
              ],
              if (_errorText(s, error) case final text?)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      text,
                      style: Typo.meta(ar: s.rtl).copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _PrimaryButton(
                s: s,
                email: _email,
                code: _code,
                onSend: _send,
                onVerify: _verify,
                onDone: () async => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({required this.s, required this.email});
  final PatientAppState s;
  final TextEditingController email;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.strings.offline.go_help, style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          AuthInput(
            controller: email,
            hint: s.strings.emergency.em_ph,
            keyboard: TextInputType.emailAddress,
            forceLtr: true,
            accent: s.accent,
            autofillHints: const [AutofillHints.email],
          ),
        ],
      );
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.s,
    required this.email,
    required this.code,
    required this.focus,
    required this.onShowKeyboard,
    required this.onPaste,
    required this.onComplete,
    required this.onResend,
  });
  final PatientAppState s;
  final String email;
  final TextEditingController code;
  final FocusNode focus;
  final VoidCallback onShowKeyboard;
  final Future<void> Function() onPaste;
  final VoidCallback onComplete;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textSecondary),
              children: [
                TextSpan(text: '${s.strings.offline.go_code_help(s.gender)} '),
                TextSpan(
                  text: email,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Same shape as the sign-in code screen: six painted boxes over one
          // hidden field; the group carries the label and the digit count.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: code,
            builder: (context, value, _) => Semantics(
              textField: true,
              label: s.strings.common.a11y_code_field,
              value: s.strings.common.a11y_code_progress('${value.text.length}'),
              onTap: onShowKeyboard,
              onPaste: onPaste,
              child: ExcludeSemantics(
                child: GestureDetector(
                  // The gaps between boxes count as the field too.
                  behavior: HitTestBehavior.opaque,
                  onTap: onShowKeyboard,
                  onLongPressStart: (d) => showCodePasteMenu(context, d.globalPosition, onPaste),
                  child: OtpBoxRow(code: value.text, accent: s.accent),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 1,
              width: 1,
              child: TextField(
                controller: code,
                focusNode: focus,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                inputFormatters: const [CodeInputFormatter()],
                onChanged: (v) {
                  if (v.length == 6) onComplete();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: _ResendLine(s: s, onResend: onResend)),
        ],
      );
}

/// The resend countdown, then the Resend button once it reaches zero.
class _ResendLine extends ConsumerWidget {
  const _ResendLine({required this.s, required this.onResend});
  final PatientAppState s;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (secs, busy) = ref.watch(goOnlineSheetControllerProvider.select((st) => (st.secs, st.busy)));
    if (secs > 0) {
      return RichText(
        text: TextSpan(
          style: Typo.meta(ar: s.rtl),
          children: [
            TextSpan(text: '${s.strings.auth.otp_in} '),
            TextSpan(
              text: '${secs}s',
              style: Typo.num(size: FontSizes.meta, weight: FontWeight.w700, color: AppColors.textTertiary),
            ),
          ],
        ),
      );
    }
    return PButton(
      s.strings.auth.otp_resend,
      variant: BtnVariant.ghost,
      accent: s.accent,
      ar: s.rtl,
      onTap: busy ? null : onResend,
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.s});
  final PatientAppState s;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.hueMint50, shape: BoxShape.circle),
              child: const Icon(LucideIcons.check, size: 36, color: AppColors.hueMint600),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            s.strings.offline.go_done_title(s.gender),
            textAlign: TextAlign.center,
            style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            s.strings.offline.go_done_help,
            textAlign: TextAlign.center,
            style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textSecondary),
          ),
        ],
      );
}

/// Send / Verify / Done, enabled by the step, the busy flag and the field
/// the step needs.
class _PrimaryButton extends ConsumerWidget {
  const _PrimaryButton({
    required this.s,
    required this.email,
    required this.code,
    required this.onSend,
    required this.onVerify,
    required this.onDone,
  });
  final PatientAppState s;
  final TextEditingController email;
  final TextEditingController code;
  final Future<void> Function() onSend;
  final Future<void> Function() onVerify;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (step, busy) = ref.watch(goOnlineSheetControllerProvider.select((st) => (st.step, st.busy)));
    final st = s.strings.offline;
    return ListenableBuilder(
      listenable: Listenable.merge([email, code]),
      builder: (context, _) {
        final (label, enabled, onTap) = switch (step) {
          GoOnlineStep.email => (st.go_send, isPlausibleEmail(email.text) && !busy, onSend),
          GoOnlineStep.code => (st.go_verify(s.gender), code.text.length == 6 && !busy, onVerify),
          GoOnlineStep.done => (st.go_done, true, onDone),
        };
        return Opacity(
          opacity: enabled ? 1 : 0.4,
          child: PButton(
            label,
            large: true,
            block: true,
            accent: s.accent,
            ar: s.rtl,
            onTap: enabled ? () => unawaited(onTap()) : null,
          ),
        );
      },
    );
  }
}
