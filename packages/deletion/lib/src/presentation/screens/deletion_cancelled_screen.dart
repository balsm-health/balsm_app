import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Success screen shown after a deletion is cancelled (account kept).
class DeletionCancelledScreen extends ConsumerWidget {
  const DeletionCancelledScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: BalsmColors.cream50,
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
                      color: BalsmColors.successBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 40,
                      color: BalsmColors.success,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Deletion cancelled',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: BalsmColors.fg1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your account is safe. Nothing was deleted.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: BalsmColors.fg3),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: BalsmButton(
                label: 'Return to home',
                onPressed: () => context.go('/'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
