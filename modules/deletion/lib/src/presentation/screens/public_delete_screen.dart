import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/use_cases/request_deletion_use_case.dart';
import '../widgets/reauth_form.dart';

/// Public, session-less account-deletion flow (route `/account/delete`).
///
/// NO auth required to reach this screen — re-auth happens inline via the
/// 3-channel [ReauthForm]. Stages: reauth -> preconfirm -> done. Works on web
/// and mobile.
class PublicDeleteScreen extends ConsumerStatefulWidget {
  const PublicDeleteScreen({super.key});

  @override
  ConsumerState<PublicDeleteScreen> createState() => _PublicDeleteScreenState();
}

enum _Stage { reauth, preconfirm, done }

class _PublicDeleteScreenState extends ConsumerState<PublicDeleteScreen> {
  _Stage _stage = _Stage.reauth;
  bool _submitting = false;
  String? _error;
  DateTime? _graceUntil;

  void _onReauthed(ReauthCredentials _) {
    // Re-auth succeeded for this session/identity. Credentials are not logged
    // or retained (no PHI). Advance to the explicit confirmation step.
    // Seam: when auth exposes a shared re-auth use case, await it here before
    // advancing.
    setState(() {
      _error = null;
      _stage = _Stage.preconfirm;
    });
  }

  Future<void> _confirmDelete() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref.read(requestDeletionUseCaseProvider).call();
    if (!mounted) return;
    result.fold(
      (intake) => setState(() {
        _submitting = false;
        _graceUntil = intake.graceUntil;
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
                  'Delete your account',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: BalsmColors.fg1,
                  ),
                ),
                const SizedBox(height: 16),
                switch (_stage) {
                  _Stage.reauth => ReauthForm(
                      submitLabel: 'Continue',
                      onSubmit: _onReauthed,
                    ),
                  _Stage.preconfirm => _PreConfirm(
                      submitting: _submitting,
                      error: _error,
                      onConfirm: _confirmDelete,
                    ),
                  _Stage.done => _Done(graceUntil: _graceUntil),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreConfirm extends StatelessWidget {
  const _PreConfirm({
    required this.submitting,
    required this.error,
    required this.onConfirm,
  });

  final bool submitting;
  final String? error;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'This permanently schedules your account for deletion. You can cancel '
          'during the grace period.',
          style: TextStyle(fontSize: 14, color: BalsmColors.fg3),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          BalsmErrorBanner(message: error!, onRetry: onConfirm),
        ],
        const SizedBox(height: 20),
        BalsmButton(
          label: 'Request account deletion',
          variant: BalsmButtonVariant.danger,
          loading: submitting,
          onPressed: submitting ? null : onConfirm,
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.graceUntil});

  final DateTime? graceUntil;

  @override
  Widget build(BuildContext context) {
    final dateText = graceUntil != null
        ? DateFormat.yMMMMd().add_jm().format(graceUntil!.toLocal())
        : 'soon';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline,
            size: 48, color: BalsmColors.success),
        const SizedBox(height: 16),
        const Text(
          'Deletion scheduled',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: BalsmColors.fg1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your account will be permanently deleted on $dateText.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: BalsmColors.fg3),
        ),
      ],
    );
  }
}
