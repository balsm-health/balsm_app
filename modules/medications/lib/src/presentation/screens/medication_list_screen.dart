import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/aggregates/medication.dart';
import '../providers.dart';
import 'schedule_format.dart';

/// Lists the user's medications with name, dose, schedule summary, a status pill
/// and a controlled-substance badge.
class MedicationListScreen extends ConsumerWidget {
  const MedicationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsAsync = ref.watch(medicationListProvider);

    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      appBar: AppBar(
        title: const Text('Medications'),
        backgroundColor: BalsmColors.surface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.goNamed('medications.add'),
        backgroundColor: BalsmColors.petalBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: medsAsync.when(
        loading: () => const BalsmLoadingIndicator(),
        error: (e, _) => BalsmErrorBanner(
          message: 'Could not load medications.',
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

class _MedicationTile extends StatelessWidget {
  const _MedicationTile({required this.med});
  final Medication med;

  @override
  Widget build(BuildContext context) {
    final expired = med.isExpired();
    final tone = med.isControlled
        ? BalsmMedTone.controlled
        : expired
            ? BalsmMedTone.success
            : BalsmMedTone.info;

    return BalsmMedRow(
      name: med.name,
      dose: _doseLine(med),
      tone: tone,
      onTap: () => context.goNamed(
        'medications.detail',
        pathParameters: {'id': med.id.storeKey()},
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (med.isControlled) ...[
            const BalsmPill(
              label: 'Controlled',
              variant: BalsmPillVariant.controlled,
              showDot: true,
            ),
            const SizedBox(width: 8),
          ],
          BalsmPill(
            label: expired ? 'Inactive' : 'Active',
            variant: expired ? BalsmPillVariant.neutral : BalsmPillVariant.success,
            showDot: true,
          ),
        ],
      ),
    );
  }

  String _doseLine(Medication med) {
    final dose = med.doseAmount;
    final schedule = formatSchedule(med.scheduleType, med.scheduleConfig);
    if (dose == null || dose.isEmpty) return schedule;
    return '$dose · $schedule';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.medication_outlined, size: 48, color: BalsmColors.ink400),
              SizedBox(height: 16),
              Text(
                'No medications yet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: BalsmColors.fg1,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Add your first medication to start tracking doses.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: BalsmColors.fg3),
              ),
            ],
          ),
        ),
      );
}
