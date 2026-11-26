import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../i18n/i18n.dart';
import '../providers/deletion_flow.dart';
import '../widgets/reauth_form.dart';

/// Public, session-less deletion-cancellation flow
/// (route `/account/delete-cancelled`).
///
/// NO auth required. Re-auth happens inline via the 3-channel [ReauthForm],
/// then `POST /deletion/cancel` is invoked. Cancelling is less destructive than
/// deleting, but it still changes another person's account state, so it takes
/// the same proof. Works on web and mobile.
class PublicDeleteCancelledScreen extends ConsumerWidget {
  const PublicDeleteCancelledScreen({super.key});

  static const DeletionEntry _entry = DeletionEntry.publicCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(deletionStringsProvider);
    final cancelled = ref.watch(deletionFlowProvider(_entry).select((f) => f.stage == DeletionStage.cancelled));
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
                  m.publicCancelTitle,
                  style: const TextStyle(
                    fontSize: FontSizes.headline,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (cancelled) const _Cancelled() else ReauthForm(entry: _entry, submitLabel: m.publicCancelAction),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cancelled extends ConsumerWidget {
  const _Cancelled();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(deletionStringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
        const SizedBox(height: 16),
        Text(
          m.cancelled,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: FontSizes.subhead,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          m.safeBody,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: FontSizes.description, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
