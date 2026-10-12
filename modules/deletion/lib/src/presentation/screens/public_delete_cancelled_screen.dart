import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/use_cases/cancel_deletion_use_case.dart';
import '../../application/ports/reauth_port.dart';
import '../i18n/i18n.dart';
import '../widgets/reauth_form.dart';

/// Public, session-less deletion-cancellation flow
/// (route `/account/delete-cancelled`).
///
/// NO auth required. Re-auth happens inline via the 3-channel [ReauthForm],
/// then `POST /deletion/cancel` is invoked. Works on web and mobile.
class PublicDeleteCancelledScreen extends ConsumerStatefulWidget {
  const PublicDeleteCancelledScreen({super.key});

  @override
  ConsumerState<PublicDeleteCancelledScreen> createState() => _PublicDeleteCancelledScreenState();
}

enum _Stage { reauth, done }

class _PublicDeleteCancelledScreenState extends ConsumerState<PublicDeleteCancelledScreen> {
  _Stage _stage = _Stage.reauth;
  bool _submitting = false;
  String? _error;

  Future<void> _sendCode(ReauthChannel channel, String identifier) async {
    setState(() => _error = null);
    final sent = await ref.read(reauthPortProvider).requestChallenge(channel, identifier);
    if (!mounted) return;
    if (sent case AppFailureResult(:final failure)) {
      setState(() => _error = failure.message);
    }
  }

  /// Verifies before cancelling. Cancelling is less destructive than deleting,
  /// but it still changes another person's account state, so it takes the same
  /// proof. Credentials are never logged or retained.
  Future<void> _onReauthed(ReauthCredentials credentials) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final proof = await ref.read(reauthPortProvider).verify(credentials);
    if (!mounted) return;
    if (proof case AppFailureResult(:final failure)) {
      setState(() {
        _submitting = false;
        _error = failure.message;
      });
      return;
    }
    final result = await ref.read(cancelDeletionUseCaseProvider).call();
    if (!mounted) return;
    result.fold(
      (_) => setState(() {
        _submitting = false;
        _stage = _Stage.done;
      }),
      (failure) => setState(() {
        _submitting = false;
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(deletionStringsProvider);
    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Text(
                  m.publicCancelTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: BalsmColors.fg1,
                  ),
                ),
                const SizedBox(height: 16),
                switch (_stage) {
                  _Stage.reauth => ReauthForm(
                      submitLabel: m.publicCancelAction,
                      submitting: _submitting,
                      error: _error,
                      onRequestChallenge: _sendCode,
                      onSubmit: _onReauthed,
                    ),
                  _Stage.done => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: const [
                        Icon(Icons.check_circle_outline, size: 48, color: BalsmColors.success),
                        SizedBox(height: 16),
                        Text(
                          'Deletion cancelled',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: BalsmColors.fg1,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Your account is safe. Nothing was deleted.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: BalsmColors.fg3),
                        ),
                      ],
                    ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
