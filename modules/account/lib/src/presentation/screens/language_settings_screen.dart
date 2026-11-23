import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/use_cases/change_language_use_case.dart';
import '../failure_text.dart';
import '../i18n/i18n.dart';

/// Selectable account languages — the closed set of fully-supported UI
/// locales (beta languages are picker-visible in the app-shell language
/// sheet only, not selectable as the account's preferred language).
const List<LanguageCode> _languages = LanguageCode.uiSupported;

/// Language settings: a 2-option segmented control (English / Arabic).
/// Selecting a language dispatches ChangeLanguageUseCase and applies an
/// immediate Directionality update (<=200ms) for instant LTR/RTL feedback.
class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends ConsumerState<LanguageSettingsScreen> {
  // Locally-applied selection for immediate Directionality feedback,
  // before the server round-trip completes.
  String? _pending;
  bool _busy = false;
  String? _error;

  Future<void> _onSelect(AccountSummary summary, String tag) async {
    if (tag == (_pending ?? summary.preferredLanguage) || _busy) return;

    // Immediate UI feedback (<=200ms): apply selection + Directionality now.
    setState(() {
      _pending = tag;
      _busy = true;
      _error = null;
    });

    final result = await ref.read(changeLanguageUseCaseProvider).execute(
          userId: summary.id,
          oldLanguage: summary.preferredLanguage,
          newLanguage: tag,
        );

    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      (_) => refreshAccountSummary(ref),
      (failure) => setState(() {
        // Revert optimistic selection on failure.
        _pending = summary.preferredLanguage;
        _error = accountFailureText(failure);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(accountSummaryProvider);
    final m = ref.watch(accountStringsProvider);

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
        final selectedTag = _pending ?? summary.preferredLanguage;
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
                          onChanged: (l) => _onSelect(summary, l.value),
                        ),
                        if (_error case final error?) ...[
                          const SizedBox(height: 16),
                          BalsmErrorBanner(message: error),
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
