import 'dart:async';

import 'package:auth/auth.dart';
import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../auth/go_online_controller.dart';
import '../kit.dart';
import '../routes.dart';
import '../tokens.dart';
import '../widgets/auth_fields.dart';

/// Opens the go-online sheet (design: `GoOnlineSheet`): email → code → done.
Future<void> showGoOnlineSheet(BuildContext context) {
  final s = AppScope.of(context);
  return showAppSheet<void>(
    context,
    textDirection: s.dir,
    builder: (_) => _GoOnlineSheet(s: s),
  );
}

/// Gate for anything that needs a server account (sharing, care-team sync,
/// Balsm Cloud). True when the account is online; a device-only account gets
/// the go-online sheet first, and this answers whether it came back online.
Future<bool> requireOnline(BuildContext context, WidgetRef ref) async {
  final s = AppScope.of(context);
  if (s.accountMode != AccountMode.deviceOnly) return true;
  await showGoOnlineSheet(context);
  return s.accountMode == AccountMode.online;
}

enum _Step { email, code, done }

class _GoOnlineSheet extends ConsumerStatefulWidget {
  const _GoOnlineSheet({required this.s});
  final PatientAppState s;
  @override
  ConsumerState<_GoOnlineSheet> createState() => _GoOnlineSheetState();
}

class _GoOnlineSheetState extends ConsumerState<_GoOnlineSheet> {
  static const _resendSecs = 28;

  final _email = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  _Step _step = _Step.email;
  bool _busy = false;
  String? _error;
  int _secs = 0;
  Timer? _timer;

  PatientAppState get s => widget.s;

  @override
  void initState() {
    super.initState();
    unawaited(_prefill());
  }

  /// The device-only account's email — the one it will be claimed under.
  Future<void> _prefill() async {
    try {
      final creds = await ref.read(offlineAccountServiceProvider).pendingCredentials();
      if (!mounted || creds == null || _email.text.isNotEmpty) return;
      setState(() => _email.text = creds.email);
    } catch (_) {
      // Prefill is a convenience; the field stays editable.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  bool get _emailOk => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secs = _resendSecs);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _secs <= 1) {
        t.cancel();
        if (mounted) setState(() => _secs = 0);
        return;
      }
      setState(() => _secs--);
    });
  }

  Future<void> _send() async {
    if (!_emailOk || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(goOnlineControllerProvider).sendCode(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.isFailure) {
        _error = r.error.message;
        return;
      }
      _step = _Step.code;
      _code.clear();
    });
    if (r.isSuccess) {
      _startCountdown();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _codeFocus.requestFocus();
      });
    }
  }

  Future<void> _verify() async {
    final code = _code.text;
    if (code.length != 6 || _busy) return;
    final controller = ref.read(goOnlineControllerProvider);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await controller.verify(email: _email.text.trim(), code: code);
    if (r.isSuccess) {
      switch (r.value) {
        case GoOnlineOutcome.online:
          // Update the UI gates even if the sheet was dismissed mid-verify.
          s.setAccountMode(AccountMode.online);
          if (!mounted) return;
          _timer?.cancel();
          unawaited(HapticFeedback.lightImpact());
          setState(() {
            _busy = false;
            _step = _Step.done;
          });
        case GoOnlineOutcome.needsMergeChoice:
          if (mounted) nav.pop();
          s.go(AppRoutes.mergeOrDiscard);
      }
      return;
    }
    if (!mounted) return;
    unawaited(HapticFeedback.heavyImpact());
    final until = controller.lockedUntil;
    setState(() {
      _busy = false;
      _code.clear();
      _error = until != null
          ? s.strings.auth.auth_locked_retry(until.difference(DateTime.now()).inSeconds.clamp(0, 3600).toString())
          : r.error.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = s.strings.offline;
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
            if (_step == _Step.done)
              _done()
            else ...[
              Text(st.go_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (_step == _Step.email) ..._emailStep() else ..._codeStep(),
            ],
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                      liveRegion: true,
                      child: Text(_error!,
                          style: Typo.meta(ar: s.rtl).copyWith(color: T.danger, fontWeight: FontWeight.w600)))),
            const SizedBox(height: 20),
            _primary(),
          ]),
        ),
      ),
    );
  }

  List<Widget> _emailStep() => [
        Text(s.strings.offline.go_help, style: Typo.body(ar: s.rtl).copyWith(color: T.fg2)),
        const SizedBox(height: 16),
        AuthInput(
            controller: _email,
            hint: s.strings.emergency.em_ph,
            keyboard: TextInputType.emailAddress,
            forceLtr: true,
            accent: s.accent,
            autofillHints: const [AutofillHints.email],
            onChanged: (_) => setState(() {})),
      ];

  List<Widget> _codeStep() {
    final code = _code.text;
    return [
      RichText(
          text: TextSpan(style: Typo.body(ar: s.rtl).copyWith(color: T.fg2), children: [
        TextSpan(text: '${s.strings.offline.go_code_help} '),
        TextSpan(text: _email.text.trim(), style: const TextStyle(color: T.fg1, fontWeight: FontWeight.w700)),
      ])),
      const SizedBox(height: 20),
      // Same shape as the sign-in code screen: six painted boxes over one
      // hidden field; the group carries the label and the digit count.
      Semantics(
        textField: true,
        label: s.strings.common.a11y_code_field,
        value: s.strings.common.a11y_code_progress('${code.length}'),
        onTap: () => _codeFocus.requestFocus(),
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: () => _codeFocus.requestFocus(),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 6; i++)
                Flexible(
                  child: OtpBox(
                    char: i < code.length ? code[i] : '',
                    active: code.length == i,
                    accent: s.accent,
                  ),
                ),
            ]),
          ),
        ),
      ),
      Opacity(
          opacity: 0,
          child: SizedBox(
              height: 1,
              width: 1,
              child: TextField(
                controller: _code,
                focusNode: _codeFocus,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                onChanged: (v) {
                  setState(() {});
                  if (v.length == 6) unawaited(_verify());
                },
              ))),
      const SizedBox(height: 12),
      Center(
          child: _secs > 0
              ? RichText(
                  text: TextSpan(style: Typo.meta(ar: s.rtl), children: [
                  TextSpan(text: '${s.strings.auth.otp_in} '),
                  TextSpan(text: '${_secs}s', style: Typo.num(size: FS.xs, weight: FontWeight.w700, color: T.fg3)),
                ]))
              : PButton(s.strings.auth.otp_resend,
                  variant: BtnVariant.ghost, accent: s.accent, ar: s.rtl, onTap: _busy ? null : () => _send())),
    ];
  }

  Widget _done() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: T.hueMint50, shape: BoxShape.circle),
            child: const Icon(LucideIcons.check, size: 36, color: T.hueMint600),
          ),
        ),
        const SizedBox(height: 14),
        Text(s.strings.offline.go_done_title,
            textAlign: TextAlign.center, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(s.strings.offline.go_done_help,
            textAlign: TextAlign.center, style: Typo.body(ar: s.rtl).copyWith(color: T.fg2)),
      ]);

  Widget _primary() {
    final st = s.strings.offline;
    final (label, enabled, onTap) = switch (_step) {
      _Step.email => (st.go_send, _emailOk && !_busy, _send),
      _Step.code => (st.go_verify, _code.text.length == 6 && !_busy, _verify),
      _Step.done => (st.go_done, true, () async => Navigator.pop(context)),
    };
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: PButton(label,
          variant: BtnVariant.primary,
          large: true,
          block: true,
          accent: s.accent,
          ar: s.rtl,
          onTap: enabled ? () => unawaited(onTap()) : null),
    );
  }
}
