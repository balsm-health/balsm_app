import 'dart:async';

import 'package:account/account.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Home dashboard.
///
/// - Time-aware greeting using the account display name.
/// - Onboarding nudge cards (claim handle / emergency card / add medication);
///   completed nudges are hidden. Empty state shows all three.
/// - Today summary card when medications exist (placeholder count for now).
/// - Listens for [CountryChanged] on the [EventBus] to trigger a locale
///   refresh (T173) by invalidating the account summary.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<CountryChanged>? _countrySub;

  @override
  void initState() {
    super.initState();
    // T173: react to country change → refresh locale-derived state.
    final bus = ref.read(eventBusProvider);
    _countrySub = bus.on<CountryChanged>().listen((_) {
      if (!mounted) return;
      // Re-fetch the account summary so greeting / locale reflect the change.
      ref.invalidate(accountSummaryProvider);
    });
  }

  @override
  void dispose() {
    _countrySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(accountSummaryProvider);

    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: summaryAsync.when(
          loading: () => const BalsmLoadingIndicator(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: BalsmErrorBanner(
              message: 'Could not load your home.',
              onRetry: () => ref.invalidate(accountSummaryProvider),
            ),
          ),
          data: (summary) => _HomeBody(summary: summary),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.summary});
  final AccountSummary? summary;

  @override
  Widget build(BuildContext context) {
    // Placeholder: medication state is owned by the medications module.
    // For the MVP home, treat the list as empty (count 0) until wired.
    const hasMedications = false;
    const medicationCountToday = 0;

    final needsHandle = summary?.handle == null;
    // Emergency-card and first-medication completion are owned by sibling
    // modules; until those flags are exposed we always offer the nudges.
    const needsEmergencyCard = true;
    const needsFirstMedication = true;

    final nudges = <Widget>[
      if (needsHandle)
        _Nudge(
          eyebrow: 'Get set up',
          title: 'Claim your handle',
          ctaLabel: 'Claim handle',
          onTap: () => context.goNamed('handle.claim'),
        ),
      if (needsEmergencyCard)
        _Nudge(
          eyebrow: 'Be prepared',
          title: 'Add emergency card',
          ctaLabel: 'Add card',
          onTap: () => _go(context, 'emergency.card'),
        ),
      if (needsFirstMedication)
        _Nudge(
          eyebrow: 'Stay on track',
          title: 'Add a medication',
          ctaLabel: 'Add medication',
          onTap: () => _go(context, 'medications.add'),
        ),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: _Greeting(summary: summary),
        ),
        const SizedBox(height: 8),
        if (hasMedications) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: BalsmCard.accent(
              child: Row(
                children: [
                  const Icon(Icons.medication_outlined,
                      color: BalsmColors.appAccent600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: BalsmColors.fg3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$medicationCountToday doses scheduled',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: BalsmColors.fg1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Nudges (empty state = all three; completed are hidden).
        for (final n in nudges) ...[
          n,
          const SizedBox(height: 12),
        ],
        if (nudges.isEmpty && !hasMedications)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: BalsmCard(
              child: Text(
                'You are all set. Nothing needs your attention right now.',
                style: TextStyle(fontSize: 14, color: BalsmColors.fg2),
              ),
            ),
          ),
      ],
    );
  }

  void _go(BuildContext context, String name) {
    try {
      context.goNamed(name);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not available yet.')),
      );
    }
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.summary});
  final AccountSummary? summary;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final part = hour < 12
        ? 'Good morning'
        : (hour < 18 ? 'Good afternoon' : 'Good evening');
    final raw = summary?.displayName?.trim();
    final name = (raw == null || raw.isEmpty) ? null : raw;
    final text = name == null ? part : '$part, $name';
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w800,
        fontSize: 26,
        letterSpacing: -0.26,
        color: BalsmColors.fg1,
      ),
    );
  }
}

class _Nudge extends StatelessWidget {
  const _Nudge({
    required this.eyebrow,
    required this.title,
    required this.ctaLabel,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String ctaLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => BalsmHeroCard.prompt(
        eyebrow: eyebrow,
        title: title,
        ctaLabel: ctaLabel,
        onCta: onTap,
      );
}
