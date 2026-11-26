import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../i18n/i18n.dart';
import '../providers/deletion_flow.dart';
import '../widgets/reauth_form.dart';

/// Public, session-less account-deletion flow (route `/account/delete`).
///
/// NO auth required to reach this screen — re-auth happens inline via the
/// 3-channel [ReauthForm]. Stages: reauth -> preconfirm -> done. Works on web
/// and mobile.
class PublicDeleteScreen extends ConsumerWidget {
  const PublicDeleteScreen({super.key, this.alreadyVerified = false});

  /// True when the person arrived through the emailed deletion link, which the
  /// caller has already redeemed for a session: that is the same proof the
  /// code gives, so the screen opens on the confirmation step. It skips a
  /// form, not a check — the deletion request itself still needs that session,
  /// and the server refuses it without one.
  final bool alreadyVerified;

  DeletionEntry get _entry => alreadyVerified ? DeletionEntry.publicDeleteVerified : DeletionEntry.publicDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(deletionStringsProvider);
    final stage = ref.watch(deletionFlowProvider(_entry).select((f) => f.stage));
    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Text(
                  m.publicTitle,
                  style: const TextStyle(
                    fontSize: FontSizes.headline,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                switch (stage) {
                  DeletionStage.reauth => ReauthForm(entry: _entry, submitLabel: m.verifyContinue),
                  DeletionStage.preconfirm => _PreConfirm(entry: _entry),
                  DeletionStage.scheduled || DeletionStage.cancelled => _Done(entry: _entry),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreConfirm extends ConsumerWidget {
  const _PreConfirm({required this.entry});

  final DeletionEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(deletionStringsProvider);
    final (:submitting, :failure) =
        ref.watch(deletionFlowProvider(entry).select((f) => (submitting: f.submitting, failure: f.failure)));
    void confirm() => unawaited(ref.read(deletionFlowProvider(entry).notifier).requestDeletion());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          m.publicConfirmBody,
          style: const TextStyle(fontSize: FontSizes.description, color: AppColors.textTertiary),
        ),
        if (failure case final failure?) ...[
          const SizedBox(height: 16),
          BalsmErrorBanner(message: failure.message, onRetry: confirm),
        ],
        const SizedBox(height: 20),
        BalsmButton(
          label: m.requestDeletion,
          variant: BalsmButtonVariant.danger,
          loading: submitting,
          onPressed: submitting ? null : confirm,
        ),
      ],
    );
  }
}

class _Done extends ConsumerWidget {
  const _Done({required this.entry});

  final DeletionEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(deletionStringsProvider);
    final graceUntil = ref.watch(deletionFlowProvider(entry).select((f) => f.graceUntil));
    final dateText = switch (graceUntil) {
      final graceUntil? => DateFormat.yMMMMd().add_jm().format(graceUntil.toLocal()),
      _ => m.soon
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
        const SizedBox(height: 16),
        Text(
          m.scheduledTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: FontSizes.subhead,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          m.deletedOn(dateText),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: FontSizes.description, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
