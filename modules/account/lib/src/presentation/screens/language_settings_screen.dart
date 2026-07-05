import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/use_cases/change_language_use_case.dart';

/// One selectable language option.
class _LangOption {
  const _LangOption(this.tag, this.label);
  final String tag; // BCP-47
  final String label;
}

const _kLanguages = <_LangOption>[
  _LangOption('en', 'English'),
  _LangOption('ar-EG', 'عربي (مصر)'),
  _LangOption('ar-SA', 'عربي (السعودية)'),
  _LangOption('ar-AE', 'عربي (الإمارات)'),
];

/// Language settings: a 4-option segmented control. Selecting a language
/// dispatches ChangeLanguageUseCase and applies an immediate Directionality
/// update (<=200ms) for instant LTR/RTL feedback.
class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() =>
      _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState
    extends ConsumerState<LanguageSettingsScreen> {
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

    final result =
        await ref.read(changeLanguageUseCaseProvider).execute(
              userId: summary.id,
              oldLanguage: summary.preferredLanguage,
              newLanguage: tag,
            );

    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      (_) => ref.invalidate(accountSummaryProvider),
      (failure) => setState(() {
        // Revert optimistic selection on failure.
        _pending = summary.preferredLanguage;
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(accountSummaryProvider);

    return summaryAsync.when(
      loading: () => const Scaffold(
        backgroundColor: BalsmColors.cream50,
        body: SafeArea(child: BalsmLoadingIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: BalsmColors.cream50,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: BalsmErrorBanner(
              message: 'Could not load account.',
              onRetry: () => ref.invalidate(accountSummaryProvider),
            ),
          ),
        ),
      ),
      data: (summary) {
        if (summary == null) {
          return const Scaffold(body: Center(child: Text('No account.')));
        }
        final selectedTag = _pending ?? summary.preferredLanguage;
        final selected = _kLanguages.firstWhere(
          (o) => o.tag == selectedTag,
          orElse: () => _kLanguages.first,
        );
        final dir = Bcp47Tag(selectedTag).isRtl
            ? TextDirection.rtl
            : TextDirection.ltr;

        // Immediate Directionality flip for instant RTL/LTR feedback.
        return Directionality(
          textDirection: dir,
          child: Scaffold(
            backgroundColor: BalsmColors.cream50,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BalsmAppBar.withBack(
                    title: 'Language',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'Choose your preferred language.',
                          style: TextStyle(
                            fontSize: 14,
                            color: BalsmColors.fg3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        BalsmSegmented<_LangOption>(
                          options: _kLanguages,
                          labelOf: (o) => o.label,
                          selected: selected,
                          onChanged: (o) => _onSelect(summary, o.tag),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          BalsmErrorBanner(message: _error!),
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
