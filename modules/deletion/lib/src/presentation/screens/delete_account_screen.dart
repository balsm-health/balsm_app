import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../i18n/i18n.dart';

/// Account-deletion explainer + entry point.
///
/// Reachable in <=2 taps from Settings (SC-012). Shows a 3-column disclosure
/// table (Retained / Deleted / Wiped) and a danger CTA that advances to the
/// confirm step.
class DeleteAccountScreen extends ConsumerWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(deletionStringsProvider);
    final retained = [m.itemDisclosureRecord, m.itemDeletionLog];

    // Deleted from Balsm's own servers. Care team is named explicitly rather than
    // left to "All PHI on server": it is the only health record the patient can
    // see in the app that Balsm also holds, so a patient reading this column has
    // to be able to find it (FR-513).
    final deleted = [m.itemAccount, m.itemHandle, m.itemSessions, m.itemCareTeamCloud];
    final wiped = [m.itemPhiDevice, m.itemCareTeam, m.itemPhiServer];
    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BalsmAppBar.withBack(
              title: m.title,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
                children: [
                  Text(
                    m.dataHeading,
                    style: const TextStyle(
                      fontSize: FontSizes.subhead,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    m.dataIntro,
                    style: const TextStyle(fontSize: FontSizes.description, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 20),
                  _DisclosureTable(
                    retained: retained,
                    deleted: deleted,
                    wiped: wiped,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              child: BalsmButton(
                label: m.requestDeletion,
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

class _DisclosureTable extends ConsumerWidget {
  const _DisclosureTable({
    required this.retained,
    required this.deleted,
    required this.wiped,
  });

  final List<String> retained;
  final List<String> deleted;
  final List<String> wiped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(deletionStringsProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _DisclosureColumn(
            title: m.columnRetained,
            color: AppColors.ink600,
            icon: Icons.lock_outline,
            items: retained,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DisclosureColumn(
            title: m.columnDeleted,
            color: AppColors.warning,
            icon: Icons.remove_circle_outline,
            items: deleted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DisclosureColumn(
            title: m.columnWiped,
            color: AppColors.danger,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: FontSizes.bodySm,
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
                style: const TextStyle(fontSize: FontSizes.meta, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
