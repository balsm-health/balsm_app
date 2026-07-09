import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/dose_event.dart';
import '../../domain/value_objects/ids.dart';
import '../providers.dart';

/// Timeline of a medication's dose history, colored by outcome:
/// taken = mint, skipped = neutral, missed = danger, snoozed = amber,
/// correction = info.
class DoseHistoryScreen extends ConsumerWidget {
  const DoseHistoryScreen({super.key, required this.medicationId});

  final MedicationId medicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(doseHistoryProvider(medicationId));

    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      appBar: AppBar(
        title: const Text('Dose history'),
        backgroundColor: BalsmColors.surface,
        elevation: 0,
      ),
      body: historyAsync.when(
        loading: () => const BalsmLoadingIndicator(),
        error: (e, _) => BalsmErrorBanner(
          message: 'Could not load dose history.',
          onRetry: () => ref.invalidate(doseHistoryProvider(medicationId)),
        ),
        data: (events) {
          if (events.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No dose history yet.',
                  style: TextStyle(color: BalsmColors.fg3),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (_, i) => _TimelineTile(
              event: events[i],
              isFirst: i == 0,
              isLast: i == events.length - 1,
            ),
          );
        },
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final DoseEvent event;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = _outcomeColor(event.outcome);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : BalsmColors.ink200,
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color:
                        isLast ? Colors.transparent : BalsmColors.ink200,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      BalsmPill(
                        label: _outcomeLabel(event.outcome),
                        variant: _outcomeVariant(event.outcome),
                        showDot: true,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('HH:mm').format(event.scheduledAt),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: BalsmColors.fg1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEE, d MMM yyyy').format(event.scheduledAt),
                    style: const TextStyle(fontSize: 13, color: BalsmColors.fg3),
                  ),
                  if (event.outcome == DoseOutcome.snoozed &&
                      event.snoozeUntil != null)
                    Text(
                      'Snoozed until ${DateFormat('HH:mm').format(event.snoozeUntil!)}',
                      style:
                          const TextStyle(fontSize: 12, color: BalsmColors.fg3),
                    ),
                  if (event.parentEventId != null)
                    const Text(
                      'Correction',
                      style: TextStyle(fontSize: 12, color: BalsmColors.fg3),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _outcomeColor(DoseOutcome o) => switch (o) {
      DoseOutcome.taken => BalsmColors.petalMint,
      DoseOutcome.skipped => BalsmColors.ink400,
      DoseOutcome.missed => BalsmColors.danger,
      DoseOutcome.snoozed => BalsmColors.warning,
      DoseOutcome.correction => BalsmColors.petalBlue,
    };

BalsmPillVariant _outcomeVariant(DoseOutcome o) => switch (o) {
      DoseOutcome.taken => BalsmPillVariant.success,
      DoseOutcome.skipped => BalsmPillVariant.neutral,
      DoseOutcome.missed => BalsmPillVariant.danger,
      DoseOutcome.snoozed => BalsmPillVariant.warn,
      DoseOutcome.correction => BalsmPillVariant.info,
    };

String _outcomeLabel(DoseOutcome o) => switch (o) {
      DoseOutcome.taken => 'Taken',
      DoseOutcome.skipped => 'Skipped',
      DoseOutcome.missed => 'Missed',
      DoseOutcome.snoozed => 'Snoozed',
      DoseOutcome.correction => 'Corrected',
    };
