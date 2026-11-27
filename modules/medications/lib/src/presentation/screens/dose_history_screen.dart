import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/entities/dose_event.dart';
import '../../domain/value_objects/ids.dart';
import '../i18n/i18n.dart';
import '../providers.dart';

/// Timeline of a medication's dose history, colored by outcome:
/// taken = mint, skipped = neutral, missed = danger, snoozed = amber,
/// correction = info.
class DoseHistoryScreen extends ConsumerWidget {
  const DoseHistoryScreen({required this.medicationId, super.key});

  final MedicationId medicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(doseHistoryProvider(medicationId));
    final m = ref.watch(medicationsStringsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream50,
      appBar: AppBar(
        title: Text(m.historyTitle),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: historyAsync.when(
        loading: () => const BalsmLoadingIndicator(),
        error: (e, _) => BalsmErrorBanner(
          message: m.historyLoadError,
          onRetry: () => ref.invalidate(doseHistoryProvider(medicationId)),
        ),
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  m.historyEmpty,
                  style: const TextStyle(color: AppColors.textTertiary),
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

class _TimelineTile extends ConsumerWidget {
  const _TimelineTile({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final DoseEvent event;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(medicationsStringsProvider);
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
                    color: isFirst ? Colors.transparent : AppColors.ink200,
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
                    color: isLast ? Colors.transparent : AppColors.ink200,
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
                        label: _outcomeLabel(m, event.outcome),
                        variant: _outcomeVariant(event.outcome),
                        showDot: true,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('HH:mm').format(event.scheduledAt),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEE, d MMM yyyy').format(event.scheduledAt),
                    style: const TextStyle(fontSize: FontSizes.bodySm, color: AppColors.textTertiary),
                  ),
                  if (event.outcome == DoseOutcome.snoozed && event.snoozeUntil != null)
                    Text(
                      m.snoozedUntil(DateFormat('HH:mm').format(event.snoozeUntil!)),
                      style: const TextStyle(fontSize: FontSizes.meta, color: AppColors.textTertiary),
                    ),
                  if (event.parentEventId != null)
                    Text(
                      m.correction,
                      style: const TextStyle(fontSize: FontSizes.meta, color: AppColors.textTertiary),
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
      DoseOutcome.taken => AppColors.hueMint,
      DoseOutcome.skipped => AppColors.ink400,
      DoseOutcome.missed => AppColors.danger,
      DoseOutcome.snoozed => AppColors.warning,
      DoseOutcome.correction => AppColors.hueBlue,
    };

BalsmPillVariant _outcomeVariant(DoseOutcome o) => switch (o) {
      DoseOutcome.taken => BalsmPillVariant.success,
      DoseOutcome.skipped => BalsmPillVariant.neutral,
      DoseOutcome.missed => BalsmPillVariant.danger,
      DoseOutcome.snoozed => BalsmPillVariant.warn,
      DoseOutcome.correction => BalsmPillVariant.info,
    };

String _outcomeLabel(Messages m, DoseOutcome o) => switch (o) {
      DoseOutcome.taken => m.outcome.taken,
      DoseOutcome.skipped => m.outcome.skipped,
      DoseOutcome.missed => m.outcome.missed,
      DoseOutcome.snoozed => m.outcome.snoozed,
      DoseOutcome.correction => m.outcome.corrected,
    };
