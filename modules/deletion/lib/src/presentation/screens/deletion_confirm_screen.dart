import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/use_cases/cancel_deletion_use_case.dart';
import '../../application/use_cases/request_deletion_use_case.dart';
import '../i18n/i18n.dart';

/// Final "Are you sure?" confirmation with a live grace countdown.
///
/// Submitting calls `POST /deletion/intake` (via [RequestDeletionUseCase]),
/// which schedules deletion and returns the grace deadline. After scheduling
/// the user may still cancel within the grace window.
class DeletionConfirmScreen extends ConsumerStatefulWidget {
  const DeletionConfirmScreen({super.key});

  @override
  ConsumerState<DeletionConfirmScreen> createState() => _DeletionConfirmScreenState();
}

class _DeletionConfirmScreenState extends ConsumerState<DeletionConfirmScreen> {
  bool _submitting = false;
  String? _error;
  DateTime? _graceUntil;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref.read(requestDeletionUseCaseProvider).call();
    if (!mounted) return;
    result.fold(
      (intake) {
        setState(() {
          _submitting = false;
          _graceUntil = intake.graceUntil;
        });
        _ticker = Timer.periodic(
          const Duration(seconds: 1),
          (_) => setState(() {}),
        );
      },
      (failure) => setState(() {
        _submitting = false;
        _error = failure.message;
      }),
    );
  }

  Future<void> _cancel() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref.read(cancelDeletionUseCaseProvider).call();
    if (!mounted) return;
    result.fold(
      (_) => context.goNamed('deletion.cancelled'),
      (failure) => setState(() {
        _submitting = false;
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(deletionStringsProvider);
    final grace = _graceUntil;
    final scheduled = grace != null;
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
                  if (grace != null) ...[
                    const SizedBox(height: 24),
                    _GraceCountdownCard(graceUntil: grace),
                  ],
                  if (_error case final error?) ...[
                    const SizedBox(height: 20),
                    BalsmErrorBanner(message: error),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              child: scheduled
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BalsmButton(
                          label: m.publicCancelAction,
                          loading: _submitting,
                          onPressed: _submitting ? null : _cancel,
                        ),
                        const SizedBox(height: 10),
                        BalsmButton(
                          label: coreMessagesOf(context).common.done,
                          variant: BalsmButtonVariant.secondary,
                          onPressed: () => context.go('/'),
                        ),
                      ],
                    )
                  : BalsmButton(
                      label: m.confirmAction,
                      variant: BalsmButtonVariant.danger,
                      loading: _submitting,
                      onPressed: _submitting ? null : _confirm,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraceCountdownCard extends ConsumerWidget {
  const _GraceCountdownCard({required this.graceUntil});

  final DateTime graceUntil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(deletionStringsProvider);
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
