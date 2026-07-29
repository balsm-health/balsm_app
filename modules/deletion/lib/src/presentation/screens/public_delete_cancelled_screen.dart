import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/use_cases/cancel_deletion_use_case.dart';
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

  Future<void> _onReauthed(ReauthCredentials _) async {
    // Re-auth succeeded; cancel the pending deletion. Credentials are never
    // logged or retained (no PHI).
    setState(() {
      _submitting = true;
      _error = null;
    });
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
                const Text(
                  'Cancel account deletion',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: BalsmColors.fg1,
                  ),
                ),
                const SizedBox(height: 16),
                switch (_stage) {
                  _Stage.reauth => ReauthForm(
                      submitLabel: 'Cancel deletion',
                      submitting: _submitting,
                      error: _error,
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
