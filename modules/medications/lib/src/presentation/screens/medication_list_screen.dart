import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/aggregates/medication.dart';
import '../i18n/i18n.dart';
import '../providers.dart';
import 'schedule_format.dart';

/// Lists the user's medications with name, dose, schedule summary, a status pill
/// and a controlled-substance badge.
class MedicationListScreen extends ConsumerWidget {
  const MedicationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(medicationListProvider);
    final m = ref.watch(medicationsStringsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream50,
      appBar: AppBar(
        title: Text(m.listTitle),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.goNamed('medications.add'),
        backgroundColor: AppColors.hueBlue,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: Text(m.addShort),
      ),
      body: medsAsync.when(
        loading: () => const BalsmLoadingIndicator(),
        error: (e, _) => BalsmErrorBanner(
          message: m.listLoadError,
          onRetry: () => ref.invalidate(medicationListProvider),
        ),
        data: (meds) {
          if (meds.isEmpty) return const _EmptyState();
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: meds.length,
            itemBuilder: (_, i) => _MedicationTile(med: meds[i]),
          );
        },
      ),
    );
  }
}

class _MedicationTile extends ConsumerWidget {
  const _MedicationTile({required this.med});
  final Medication med;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicationsStringsProvider);
    final expired = med.isExpired();
    final tone = med.isControlled
        ? BalsmMedTone.controlled
        : expired
            ? BalsmMedTone.success
            : BalsmMedTone.info;

    return BalsmMedRow(
      name: med.name,
      dose: _doseLine(m, med),
      tone: tone,
      onTap: () => context.goNamed(
        'medications.detail',
        pathParameters: {'id': med.id.storeKey()},
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (med.isControlled) ...[
            BalsmPill(
              label: m.controlled,
              variant: BalsmPillVariant.controlled,
              showDot: true,
            ),
            const SizedBox(width: 8),
          ],
          BalsmPill(
            label: expired ? m.inactive : m.active,
            variant: expired ? BalsmPillVariant.neutral : BalsmPillVariant.success,
            showDot: true,
          ),
        ],
      ),
    );
  }

  String _doseLine(Messages m, Medication med) {
    final dose = med.doseAmount;
    final schedule = formatSchedule(m, med.scheduleType, med.scheduleConfig);
    if (dose == null || dose.isEmpty) return schedule;
    return '$dose · $schedule';
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicationsStringsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.medication_outlined, size: 48, color: AppColors.ink400),
            const SizedBox(height: 16),
            Text(
              m.list.empty,
              style: const TextStyle(
                fontSize: FontSizes.subheadSm,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              m.listEmptyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: FontSizes.description, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
