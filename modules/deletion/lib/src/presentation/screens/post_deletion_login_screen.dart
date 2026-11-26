import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/use_cases/cancel_deletion_use_case.dart';
import '../i18n/i18n.dart';
import '../providers/deletion_flow.dart';

/// Shown after a user logs into an account that is pending deletion.
///
/// Surfaces a banner with the scheduled deletion date and a CTA that cancels
/// the deletion via [CancelDeletionUseCase].
class PostDeletionLoginScreen extends ConsumerWidget {
  const PostDeletionLoginScreen({super.key, this.graceUntil});

  /// Scheduled purge deadline; surfaced to the user. May be null if unknown.
  final DateTime? graceUntil;

  static const DeletionEntry _entry = DeletionEntry.postLogin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(deletionStringsProvider);
    ref.listen(deletionFlowProvider(_entry).select((f) => f.stage), (_, stage) {
      if (stage == DeletionStage.cancelled) context.goNamed('deletion.cancelled');
    });
    final (:submitting, :failure) =
        ref.watch(deletionFlowProvider(_entry).select((f) => (submitting: f.submitting, failure: f.failure)));
    void cancel() => unawaited(ref.read(deletionFlowProvider(_entry).notifier).cancelDeletion());
    final grace = graceUntil;
    final dateText = grace != null ? DateFormat.yMMMMd().format(grace.toLocal()) : m.soon;
    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BalsmAppBar.withBack(
              title: m.welcomeBack,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warningBackground,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(
                        color: AppColors.warning.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          color: AppColors.warning,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            m.scheduledOn(dateText),
                            style: const TextStyle(
                              fontSize: FontSizes.description,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    m.changedMind,
                    style: const TextStyle(fontSize: FontSizes.description, color: AppColors.textTertiary),
                  ),
                  if (failure case final failure?) ...[
                    const SizedBox(height: 20),
                    BalsmErrorBanner(message: failure.message, onRetry: cancel),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              child: BalsmButton(
                label: m.publicCancelAction,
                loading: submitting,
                onPressed: submitting ? null : cancel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
