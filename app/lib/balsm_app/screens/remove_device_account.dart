import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../auth/device_account_remover.dart';
import '../kit.dart';
import '../routes.dart';
import '../tokens.dart';

/// Asks before removing a device-only account from this phone.
///
/// From Profile it is one confirmation. From Unlock's "Forgot password?
/// Start over" ([forgotPassword]) it is two: first what losing the password
/// means for the data, then the same removal confirmation as Profile.
/// True only when every step was confirmed explicitly.
Future<bool> confirmRemoveDeviceAccount(BuildContext context, PatientAppState s, {bool forgotPassword = false}) async {
  final a = s.strings.auth;
  if (forgotPassword) {
    final first = await showAppSheet<bool>(context,
        builder: (_) => _ConfirmSheet(
            s: s, title: a.unlock_forgot, body: a.unlock_forgot_confirm_body, confirm: a.remove_device_confirm_btn));
    if (first != true || !context.mounted) return false;
  }
  final ok = await showAppSheet<bool>(context,
      builder: (_) => _ConfirmSheet(
          s: s,
          title: a.remove_device_confirm_title,
          body: a.remove_device_confirm_body,
          confirm: a.remove_device_confirm_btn));
  return ok == true;
}

/// Removes the device-only account (see [DeviceAccountRemover]) and returns
/// to Welcome. False if the removal failed; nothing is shown about why (the
/// error could carry storage details), and the caller lets the patient retry.
Future<bool> removeDeviceAccount(WidgetRef ref, PatientAppState s) async {
  try {
    await ref.read(deviceAccountRemoverProvider).remove();
  } catch (_) {
    return false;
  }
  s.resetForSignOut();
  s.setAccountMode(AccountMode.online);
  s.go(AppRoutes.welcome);
  return true;
}

/// Signs a device-only account out by locking the app: back to Unlock, which
/// is where every cold start of this account opens. Nothing is deleted, the
/// server is never called, and the password set on this device opens it
/// again (#122). The session and the patient's own preferences stay, so it is
/// the same account that unlocks; only the tab goes back to Home.
void lockDeviceAccount(PatientAppState s) {
  s.setTab(AppTab.home);
  s.go(AppRoutes.unlock);
}

/// Pops `true` only on the explicit destructive button.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.s, required this.title, required this.body, required this.confirm});
  final PatientAppState s;
  final String title;
  final String body;
  final String confirm;

  @override
  Widget build(BuildContext context) {
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
            Semantics(
                header: true, child: Text(title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(height: 8),
            Text(body, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3, height: 1.5)),
            const SizedBox(height: 20),
            PButton(
              confirm,
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
          ]),
        ),
      ]),
    );
  }
}
