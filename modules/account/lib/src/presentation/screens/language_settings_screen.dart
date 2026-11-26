import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../failure_text.dart';
import '../i18n/i18n.dart';
import '../providers/account_setting_change.dart';

/// Selectable account languages — the closed set of fully-supported UI
/// locales (beta languages are picker-visible in the app-shell language
/// sheet only, not selectable as the account's preferred language).
const List<LanguageCode> _languages = LanguageCode.uiSupported;

/// Language settings: a 2-option segmented control (English / Arabic).
/// Selecting a language dispatches ChangeLanguageUseCase and applies an
/// immediate Directionality update (<=200ms) for instant LTR/RTL feedback.
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  static final NotifierProvider<AccountSettingChangeNotifier, AccountSettingChange> _change =
      accountSettingChangeProvider(AccountSetting.language);

  Future<void> _onSelect(BuildContext context, WidgetRef ref, AccountSummary summary, String tag) async {
    // Immediate UI feedback (<=200ms): the notifier applies the selection
    // (and so the Directionality) before the server round-trip.
    final ok = await ref.read(_change.notifier).changeLanguage(summary, tag);
    if (!ok || !context.mounted) return;
    await refreshAccountSummary(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(accountSummaryProvider);
    final m = ref.watch(accountStringsProvider);
    final (:pending, :failure) = ref.watch(_change.select((c) => (pending: c.pending, failure: c.failure)));

    return summaryAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.cream50,
        body: SafeArea(child: BalsmLoadingIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.cream50,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: BalsmErrorBanner(
              message: m.loadError,
              onRetry: () => refreshAccountSummary(ref),
            ),
          ),
        ),
      ),
      data: (summary) {
        if (summary == null) {
          return Scaffold(body: Center(child: Text(m.noAccount)));
        }
        final selectedTag = pending ?? summary.preferredLanguage;
        // Match on the base subtag so a regioned tag (`ar-SA`) still
        // highlights Arabic.
        final selectedBase = selectedTag.split('-').first.toLowerCase();
        final selected = _languages.firstWhere(
          (l) => l.value == selectedBase,
          orElse: () => _languages.first,
        );
        final dir =
            (LanguageCode.tryParseUi(selectedTag) ?? LanguageCode.en).isRtl ? TextDirection.rtl : TextDirection.ltr;

        // Immediate Directionality flip for instant RTL/LTR feedback.
        return Directionality(
          textDirection: dir,
          child: Scaffold(
            backgroundColor: AppColors.cream50,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BalsmAppBar.withBack(
                    title: m.account.language,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          m.languageIntro,
                          style: const TextStyle(
                            fontSize: FontSizes.description,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        BalsmSegmented<LanguageCode>(
                          options: _languages,
                          labelOf: (l) => l.nativeName,
                          selected: selected,
                          onChanged: (l) => unawaited(_onSelect(context, ref, summary, l.value)),
                        ),
                        if (failure case final failure?) ...[
                          const SizedBox(height: 16),
                          BalsmErrorBanner(message: accountFailureText(failure)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
