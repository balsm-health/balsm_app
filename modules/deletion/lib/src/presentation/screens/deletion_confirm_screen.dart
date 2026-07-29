import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/use_cases/cancel_deletion_use_case.dart';
import '../../application/use_cases/request_deletion_use_case.dart';

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
    final grace = _graceUntil;
    final scheduled = grace != null;
    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BalsmAppBar.withBack(
              title: 'Confirm deletion',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: BalsmColors.danger,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    scheduled ? 'Deletion scheduled' : 'Are you sure?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: BalsmColors.fg1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scheduled
                        ? 'You can still cancel until the grace period ends.'
                        : 'This schedules your account for permanent deletion. '
                            'You can cancel any time before the grace period '
                            'ends.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: BalsmColors.fg3,
                    ),
                  ),
                  if (grace != null) ...[
                    const SizedBox(height: 24),
                    _GraceCountdownCard(graceUntil: grace),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    BalsmErrorBanner(message: _error!),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: scheduled
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BalsmButton(
                          label: 'Cancel deletion',
                          variant: BalsmButtonVariant.primary,
                          loading: _submitting,
                          onPressed: _submitting ? null : _cancel,
                        ),
                        const SizedBox(height: 10),
                        BalsmButton(
                          label: 'Done',
                          variant: BalsmButtonVariant.secondary,
                          onPressed: () => context.go('/'),
                        ),
                      ],
                    )
                  : BalsmButton(
                      label: 'Yes, delete my account',
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

class _GraceCountdownCard extends StatelessWidget {
  const _GraceCountdownCard({required this.graceUntil});

  final DateTime graceUntil;

  @override
  Widget build(BuildContext context) {
    final remaining = graceUntil.difference(DateTime.now().toUtc());
    final formatted = DateFormat.yMMMMd().add_jm().format(graceUntil.toLocal());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BalsmColors.dangerBg,
        borderRadius: BorderRadius.circular(BalsmRadius.lg),
        border: Border.all(color: BalsmColors.danger.withAlpha(60)),
      ),
      child: Column(
        children: [
          const Text(
            'Deletion scheduled for',
            style: TextStyle(fontSize: 13, color: BalsmColors.fg2),
          ),
          const SizedBox(height: 4),
          Text(
            formatted,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: BalsmColors.danger,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatRemaining(remaining),
            style: const TextStyle(fontSize: 13, color: BalsmColors.fg3),
          ),
        ],
      ),
    );
  }

  String _formatRemaining(Duration d) {
    if (d.isNegative) return 'Grace period has ended';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (days > 0) return '$days days, $hours hours remaining';
    return '${hours}h ${minutes}m ${seconds}s remaining';
  }
}
