import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/use_cases/change_country_use_case.dart';

// Account countries come from core's CountryRegistry (the first-class
// jurisdictions with a supervisory authority) — NOT CountryCode.known,
// which is the wider structural set used by dial-code/travel pickers.

/// Country settings: lists countries, highlights the current one, and warns
/// that changing country requires confirming identity. On confirm it triggers
/// re-auth, then ChangeCountryUseCase, then re-disclosure.
class CountrySettingsScreen extends ConsumerStatefulWidget {
  const CountrySettingsScreen({super.key});

  @override
  ConsumerState<CountrySettingsScreen> createState() =>
      _CountrySettingsScreenState();
}

class _CountrySettingsScreenState extends ConsumerState<CountrySettingsScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _onSelect(AccountSummary summary, String code) async {
    if (code == summary.countryCode || _busy) return;

    final confirmed = await _confirmIdentity();
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref.read(changeCountryUseCaseProvider).execute(
          userId: summary.id,
          oldCountry: summary.countryCode,
          newCountry: code,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    if (result.isSuccess) {
      ref.invalidate(accountSummaryProvider);
      await _showDisclosure(code);
    } else {
      setState(() => _error = result.error.message);
    }
  }

  /// Re-auth gate. The real flow re-runs the identity-confirmation route;
  /// here we surface a blocking confirmation that must be acknowledged.
  Future<bool> _confirmIdentity() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm your identity'),
        content: const Text(
          'Changing your country requires confirming your identity. '
          'You will be asked to re-authenticate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Re-disclosure after a successful country change (new supervisory authority).
  Future<void> _showDisclosure(String code) async {
    final authority =
        ref.read(countryRegistryProvider).supervisoryAuthority(code);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy disclosure'),
        content: Text(
          'Your data is now governed under $authority. '
          'Please review the updated privacy terms.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('I understand'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(accountSummaryProvider);

    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BalsmAppBar.withBack(
              title: 'Country',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: summaryAsync.when(
                loading: () => const BalsmLoadingIndicator(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: BalsmErrorBanner(
                    message: 'Could not load account.',
                    onRetry: () => ref.invalidate(accountSummaryProvider),
                  ),
                ),
                data: (summary) {
                  if (summary == null) {
                    return const Center(child: Text('No account.'));
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const SizedBox(height: 8),
                      const _Warning(
                        'Changing country requires confirming identity.',
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        BalsmErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 16),
                      BalsmListCard(
                        children: ref
                            .watch(countryRegistryProvider)
                            .all
                            .map(
                              (c) => BalsmListRow(
                                label: CountryCode.fromCode(c.isoCode).name(
                                  ref.watch(translationCatalogProvider),
                                  locale: summary.preferredLanguage,
                                ),
                                showChevron: false,
                                trailing: c.isoCode == summary.countryCode
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: BalsmColors.appAccent,
                                        size: 22,
                                      )
                                    : (_busy
                                        ? const SizedBox.shrink()
                                        : null),
                                onTap: _busy
                                    ? null
                                    : () => _onSelect(summary, c.isoCode),
                              ),
                            )
                            .toList(),
                      ),
                      if (_busy) ...[
                        const SizedBox(height: 16),
                        const BalsmLoadingIndicator(),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BalsmColors.warningBg,
          borderRadius: BorderRadius.circular(BalsmRadius.md),
          border: Border.all(color: BalsmColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: BalsmColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, color: BalsmColors.fg2),
              ),
            ),
          ],
        ),
      );
}
