import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/use_cases/change_country_use_case.dart';
import '../failure_text.dart';
import '../i18n/i18n.dart';

// Account countries come from core's CountryRegistry (the first-class
// jurisdictions with a supervisory authority) — NOT CountryCode.known,
// which is the wider structural set used by dial-code/travel pickers.

/// Country settings: lists countries, highlights the current one, and warns
/// that changing country requires confirming identity. On confirm it triggers
/// re-auth, then ChangeCountryUseCase, then re-disclosure.
class CountrySettingsScreen extends ConsumerStatefulWidget {
  const CountrySettingsScreen({super.key});

  @override
  ConsumerState<CountrySettingsScreen> createState() => _CountrySettingsScreenState();
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
      await refreshAccountSummary(ref);
      await _showDisclosure(code);
    } else {
      setState(() => _error = accountFailureText(result.error));
    }
  }

  /// Re-auth gate. The real flow re-runs the identity-confirmation route;
  /// here we surface a blocking confirmation that must be acknowledged.
  Future<bool> _confirmIdentity() async {
    final m = ref.read(accountStringsProvider);
    final common = coreMessagesOf(context).common;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.confirmIdentityTitle),
        content: Text(m.confirmIdentityBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(common.continue_),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Re-disclosure after a successful country change (new supervisory authority).
  Future<void> _showDisclosure(String code) async {
    final authority = ref.read(countryRegistryProvider).supervisoryAuthority(code);
    final m = ref.read(accountStringsProvider);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(m.privacyDisclosureTitle),
        content: Text(m.privacyDisclosureBody(authority)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(m.iUnderstand),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(accountSummaryProvider);
    final m = ref.watch(accountStringsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BalsmAppBar.withBack(
              title: m.account.country,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: summaryAsync.when(
                loading: () => const BalsmLoadingIndicator(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: BalsmErrorBanner(
                    message: m.loadError,
                    onRetry: () => refreshAccountSummary(ref),
                  ),
                ),
                data: (summary) {
                  if (summary == null) {
                    return Center(child: Text(m.noAccount));
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const SizedBox(height: 8),
                      _Warning(m.countryWarning),
                      if (_error case final error?) ...[
                        const SizedBox(height: 12),
                        BalsmErrorBanner(message: error),
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
                                        color: AppColors.hueBlue,
                                        size: 22,
                                      )
                                    : (_busy ? const SizedBox.shrink() : null),
                                onTap: _busy ? null : () => _onSelect(summary, c.isoCode),
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
          color: AppColors.warningBackground,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: FontSizes.bodySm, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
}
