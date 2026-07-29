import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../application/use_cases/cancel_deletion_use_case.dart';

/// Shown after a user logs into an account that is pending deletion.
///
/// Surfaces a banner with the scheduled deletion date and a CTA that cancels
/// the deletion via [CancelDeletionUseCase].
class PostDeletionLoginScreen extends ConsumerStatefulWidget {
  const PostDeletionLoginScreen({super.key, this.graceUntil});

  /// Scheduled purge deadline; surfaced to the user. May be null if unknown.
  final DateTime? graceUntil;

  @override
  ConsumerState<PostDeletionLoginScreen> createState() => _PostDeletionLoginScreenState();
}

class _PostDeletionLoginScreenState extends ConsumerState<PostDeletionLoginScreen> {
  bool _submitting = false;
  String? _error;

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
    final grace = widget.graceUntil;
    final dateText = grace != null ? DateFormat.yMMMMd().format(grace.toLocal()) : 'soon';
    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BalsmAppBar.withBack(
              title: 'Welcome back',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BalsmColors.warningBg,
                      borderRadius: BorderRadius.circular(BalsmRadius.lg),
                      border: Border.all(
                        color: BalsmColors.warning.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          color: BalsmColors.warning,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your account is scheduled for deletion on '
                            '$dateText.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: BalsmColors.fg2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Changed your mind? You can cancel the deletion and keep '
                    'your account.',
                    style: TextStyle(fontSize: 14, color: BalsmColors.fg3),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    BalsmErrorBanner(message: _error!, onRetry: _cancel),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: BalsmButton(
                label: 'Cancel deletion',
                loading: _submitting,
                onPressed: _submitting ? null : _cancel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
