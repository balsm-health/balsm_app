import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/use_cases/record_dose_outcome_use_case.dart';
import '../../domain/entities/dose_event.dart';
import '../providers.dart';
import '../widgets/dedup_banner.dart';

/// Today's scheduled doses sorted by time, each with take / skip / snooze
/// actions and a missed-dose banner. Route name `meds.today`.
///
/// Supports `?highlightDoseId=` (T035bm consumer side): when provided, the
/// matching dose slot is scrolled into view and briefly highlighted. The id
/// matches [TodayDose.slotId].
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key, this.highlightDoseId});

  /// Slot id to scroll to + highlight, from a notification tap deep-link.
  final String? highlightDoseId;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final _scrollController = ScrollController();
  final _itemKeys = <String, GlobalKey>{};
  String? _highlighted;

  @override
  void initState() {
    super.initState();
    _highlighted = widget.highlightDoseId;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlight() {
    final id = _highlighted;
    if (id == null) return;
    final key = _itemKeys[id];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.2,
      );
    });
    // Clear highlight after a moment so it acts as a transient cue.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlighted = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dosesAsync = ref.watch(todayDosesProvider);

    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      appBar: AppBar(
        title: const Text('Today'),
        backgroundColor: BalsmColors.surface,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: SyncStatusBadge()),
          ),
        ],
      ),
      body: dosesAsync.when(
        loading: () => const BalsmLoadingIndicator(),
        error: (e, _) => BalsmErrorBanner(
          message: 'Could not load today\'s doses.',
          onRetry: () => ref.invalidate(todayDosesProvider),
        ),
        data: (doses) {
          final hasMissed = doses.any((d) => d.event?.outcome == DoseOutcome.missed);
          // Schedule a scroll-to-highlight once the list is laid out.
          if (_highlighted != null) _scrollToHighlight();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(todayDosesProvider),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const DedupBanner(),
                if (hasMissed) const _MissedBanner(),
                if (doses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No doses scheduled today.',
                        style: TextStyle(color: BalsmColors.fg3),
                      ),
                    ),
                  ),
                ...doses.map((d) {
                  final key = _itemKeys.putIfAbsent(d.slotId, GlobalKey.new);
                  return Container(
                    key: key,
                    child: _DoseTile(
                      dose: d,
                      highlighted: _highlighted == d.slotId,
                      onTake: () => _record(d, DoseOutcome.taken),
                      onSkip: () => _record(d, DoseOutcome.skipped),
                      onSnooze: () => _record(
                        d,
                        DoseOutcome.snoozed,
                        snoozeUntil: DateTime.now().add(const Duration(minutes: 30)),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _record(
    TodayDose dose,
    DoseOutcome outcome, {
    DateTime? snoozeUntil,
  }) async {
    try {
      await ref.read(recordDoseOutcomeUseCaseProvider).call(
            medicationId: dose.medication.id,
            scheduledAt: dose.scheduledAt,
            outcome: outcome,
            snoozeUntil: snoozeUntil,
          );
      ref.invalidate(todayDosesProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not record dose')),
      );
    }
  }
}

class _DoseTile extends StatelessWidget {
  const _DoseTile({
    required this.dose,
    required this.highlighted,
    required this.onTake,
    required this.onSkip,
    required this.onSnooze,
  });

  final TodayDose dose;
  final bool highlighted;
  final VoidCallback onTake;
  final VoidCallback onSkip;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    final med = dose.medication;
    final time = DateFormat('HH:mm').format(dose.scheduledAt);
    final outcome = dose.event?.outcome;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? BalsmColors.petalBlue50 : Colors.transparent,
        borderRadius: BorderRadius.circular(BalsmRadius.lg),
        border: highlighted ? Border.all(color: BalsmColors.petalBlue) : null,
      ),
      child: BalsmMedRow(
        name: med.name,
        dose: dose.medication.doseAmount == null ? time : '${med.doseAmount} · $time',
        tone: med.isControlled ? BalsmMedTone.controlled : BalsmMedTone.info,
        showDivider: false,
        trailing: dose.isPending
            ? _Actions(onTake: onTake, onSkip: onSkip, onSnooze: onSnooze)
            : BalsmPill(
                label: _label(outcome!),
                variant: _variant(outcome),
                showDot: true,
              ),
      ),
    );
  }

  static String _label(DoseOutcome o) => switch (o) {
        DoseOutcome.taken => 'Taken',
        DoseOutcome.skipped => 'Skipped',
        DoseOutcome.missed => 'Missed',
        DoseOutcome.snoozed => 'Snoozed',
        DoseOutcome.correction => 'Corrected',
      };

  static BalsmPillVariant _variant(DoseOutcome o) => switch (o) {
        DoseOutcome.taken => BalsmPillVariant.success,
        DoseOutcome.skipped => BalsmPillVariant.neutral,
        DoseOutcome.missed => BalsmPillVariant.danger,
        DoseOutcome.snoozed => BalsmPillVariant.warn,
        DoseOutcome.correction => BalsmPillVariant.info,
      };
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.onTake,
    required this.onSkip,
    required this.onSnooze,
  });
  final VoidCallback onTake;
  final VoidCallback onSkip;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onSnooze,
            icon: const Icon(Icons.snooze, color: BalsmColors.warning),
            tooltip: 'Snooze',
          ),
          IconButton(
            onPressed: onSkip,
            icon: const Icon(Icons.close, color: BalsmColors.ink500),
            tooltip: 'Skip',
          ),
          IconButton(
            onPressed: onTake,
            icon: const Icon(Icons.check_circle, color: BalsmColors.petalMint),
            tooltip: 'Take',
          ),
        ],
      );
}

class _MissedBanner extends StatelessWidget {
  const _MissedBanner();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: BalsmColors.dangerBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BalsmColors.danger),
        ),
        child: Row(
          children: const [
            Icon(Icons.error_outline, color: BalsmColors.danger, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'You have missed doses today. Review and update them below.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      );
}
