import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../i18n/i18n.dart';

/// Success screen shown after a deletion is cancelled (account kept).
class DeletionCancelledScreen extends ConsumerWidget {
  const DeletionCancelledScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(deletionStringsProvider);
    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.successBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 40,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    m.cancelled,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: FontSizes.headline,
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
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              child: BalsmButton(
                label: m.returnHome,
                onPressed: () => context.go('/'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
