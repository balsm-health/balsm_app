import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/use_cases/cancel_deletion_use_case.dart';
import '../i18n/i18n.dart';

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
    final m = ref.watch(deletionStringsProvider);
    final grace = widget.graceUntil;
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
                  if (_error case final error?) ...[
                    const SizedBox(height: 20),
                    BalsmErrorBanner(message: error, onRetry: _cancel),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              child: BalsmButton(
                label: m.publicCancelAction,
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
