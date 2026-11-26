import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/use_cases/request_deletion_use_case.dart';
import '../i18n/i18n.dart';
import '../providers/deletion_flow.dart';

/// Final "Are you sure?" confirmation with a live grace countdown.
///
/// Submitting calls `POST /deletion/intake` (via [RequestDeletionUseCase]),
/// which schedules deletion and returns the grace deadline. After scheduling
/// the user may still cancel within the grace window.
class DeletionConfirmScreen extends ConsumerWidget {
  const DeletionConfirmScreen({super.key});

  static const DeletionEntry _entry = DeletionEntry.confirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(deletionStringsProvider);
    ref.listen(deletionFlowProvider(_entry).select((f) => f.stage), (_, stage) {
      if (stage == DeletionStage.cancelled) context.goNamed('deletion.cancelled');
    });
    final (:scheduled, :graceUntil, :failure) = ref.watch(
      deletionFlowProvider(_entry).select(
        (f) => (scheduled: f.stage != DeletionStage.preconfirm, graceUntil: f.graceUntil, failure: f.failure),
      ),
    );
    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BalsmAppBar.withBack(
              title: m.confirm,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    scheduled ? m.scheduledTitle : m.areYouSure,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: FontSizes.headline,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scheduled ? m.scheduledBody : m.confirmBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: FontSizes.description,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  if (graceUntil case final grace?) ...[
                    const SizedBox(height: 24),
                    _GraceCountdownCard(graceUntil: grace),
                  ],
                  if (failure case final failure?) ...[
                    const SizedBox(height: 20),
                    BalsmErrorBanner(message: failure.message),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              child: _ConfirmActions(scheduled: scheduled),
            ),
          ],
        ),
      ),
    );
  }
}

/// Before scheduling: the danger confirm button. After: cancel, or done.
class _ConfirmActions extends ConsumerWidget {
  const _ConfirmActions({required this.scheduled});

  final bool scheduled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(deletionStringsProvider);
    final provider = deletionFlowProvider(DeletionConfirmScreen._entry);
    final submitting = ref.watch(provider.select((f) => f.submitting));
    if (!scheduled) {
      return BalsmButton(
        label: m.confirmAction,
        variant: BalsmButtonVariant.danger,
        loading: submitting,
        onPressed: submitting ? null : () => unawaited(ref.read(provider.notifier).requestDeletion()),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BalsmButton(
          label: m.publicCancelAction,
          loading: submitting,
          onPressed: submitting ? null : () => unawaited(ref.read(provider.notifier).cancelDeletion()),
        ),
        const SizedBox(height: 10),
        BalsmButton(
          label: coreMessagesOf(context).common.done,
          variant: BalsmButtonVariant.secondary,
          onPressed: () => context.go('/'),
        ),
      ],
    );
  }
}

/// Counts down to the purge once a second; the ticker is this card's own.
class _GraceCountdownCard extends ConsumerStatefulWidget {
  const _GraceCountdownCard({required this.graceUntil});

  final DateTime graceUntil;

  @override
  ConsumerState<_GraceCountdownCard> createState() => _GraceCountdownCardState();
}

class _GraceCountdownCardState extends ConsumerState<_GraceCountdownCard> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(deletionStringsProvider);
    final graceUntil = widget.graceUntil;
    final remaining = graceUntil.difference(DateTime.now().toUtc());
    final formatted = DateFormat.yMMMMd().add_jm().format(graceUntil.toLocal());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerBackground,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.danger.withAlpha(60)),
      ),
      child: Column(
        children: [
          Text(
            m.scheduledFor,
            style: const TextStyle(fontSize: FontSizes.bodySm, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            formatted,
            style: const TextStyle(
              fontSize: FontSizes.body,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatRemaining(m, remaining),
            style: const TextStyle(fontSize: FontSizes.bodySm, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  String _formatRemaining(Messages m, Duration d) {
    if (d.isNegative) return m.graceEnded;
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (days > 0) return m.remainingDays(days, hours);
    return m.remainingTime(hours, minutes, seconds);
  }
}
