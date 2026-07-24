import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Account-deletion explainer + entry point.
///
/// Reachable in <=2 taps from Settings (SC-012). Shows a 3-column disclosure
/// table (Retained / Deleted / Wiped) and a danger CTA that advances to the
/// confirm step.
class DeleteAccountScreen extends ConsumerWidget {
  const DeleteAccountScreen({super.key});

  static const _retained = ['Disclosure record', 'Deletion log'];
  static const _deleted = ['Account', 'Handle', 'Sessions'];
  static const _wiped = ['All PHI on device', 'All PHI on server (after grace)'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BalsmAppBar.withBack(
              title: 'Delete account',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text(
                    'What happens to your data',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: BalsmColors.fg1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Deleting your account is permanent. Here is exactly what '
                    'is kept, removed, and wiped.',
                    style: TextStyle(fontSize: 14, color: BalsmColors.fg3),
                  ),
                  const SizedBox(height: 20),
                  _DisclosureTable(
                    retained: _retained,
                    deleted: _deleted,
                    wiped: _wiped,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: BalsmButton(
                label: 'Request account deletion',
                variant: BalsmButtonVariant.danger,
                icon: Icons.delete_outline,
                onPressed: () => context.goNamed('deletion.confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclosureTable extends StatelessWidget {
  const _DisclosureTable({
    required this.retained,
    required this.deleted,
    required this.wiped,
  });

  final List<String> retained;
  final List<String> deleted;
  final List<String> wiped;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _DisclosureColumn(
            title: 'Retained',
            color: BalsmColors.ink600,
            icon: Icons.lock_outline,
            items: retained,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DisclosureColumn(
            title: 'Deleted',
            color: BalsmColors.warning,
            icon: Icons.remove_circle_outline,
            items: deleted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DisclosureColumn(
            title: 'Wiped',
            color: BalsmColors.danger,
            icon: Icons.delete_forever_outlined,
            items: wiped,
          ),
        ),
      ],
    );
  }
}

class _DisclosureColumn extends StatelessWidget {
  const _DisclosureColumn({
    required this.title,
    required this.color,
    required this.icon,
    required this.items,
  });

  final String title;
  final Color color;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BalsmColors.surface,
        borderRadius: BorderRadius.circular(BalsmRadius.lg),
        border: Border.all(color: BalsmColors.border),
        boxShadow: BalsmShadow.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                item,
                style: const TextStyle(fontSize: 12, color: BalsmColors.fg2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
