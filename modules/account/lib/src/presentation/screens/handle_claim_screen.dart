import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/use_cases/claim_handle_use_case.dart';
import '../failure_text.dart';
import '../i18n/i18n.dart';
import '../providers/handle_check.dart';

/// Screen for claiming an `@handle`.
///
/// - `@`-prefixed input, lowercased.
/// - Debounced 500ms live validation (format + availability).
/// - Green check when available, red X when taken/invalid.
/// - On a taken/reserved conflict, shows up to 3 conflict-aware alternatives
///   derived from the attempted handle (FR-008). Hidden otherwise.
/// - Submit -> ClaimHandleUseCase; 409 surfaces "Handle taken".
class HandleClaimScreen extends ConsumerStatefulWidget {
  const HandleClaimScreen({super.key});

  @override
  ConsumerState<HandleClaimScreen> createState() => _HandleClaimScreenState();
}

class _HandleClaimScreenState extends ConsumerState<HandleClaimScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    // Strip a leading '@' and force lowercase for the canonical handle.
    final value = raw.replaceFirst(RegExp('^@'), '').toLowerCase();
    if (value != raw) {
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    ref.read(handleCheckProvider.notifier).input(value);
  }

  Future<void> _submit() async {
    if (ref.read(handleCheckProvider).status != HandleStatus.available) return;
    setState(() => _submitting = true);
    final claimed = await ref.read(handleCheckProvider.notifier).claim();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (claimed == null) return;
    // Refresh the account summary so the new handle is reflected.
    // Must drop the retained row, not just rebuild the provider.
    unawaited(refreshAccountSummary(ref));
    Navigator.of(context).maybePop(claimed);
  }

  void _pick(String suggestion) {
    _controller.text = suggestion;
    _onChanged(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(accountStringsProvider);
    final available = ref.watch(handleCheckProvider.select((c) => c.status == HandleStatus.available));

    return Scaffold(
      backgroundColor: AppColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BalsmAppBar.withBack(
              title: m.claimTitle,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 8),
                  Text(
                    m.claimIntro,
                    style: const TextStyle(fontSize: FontSizes.description, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 20),
                  _HandleField(
                    controller: _controller,
                    onChanged: _onChanged,
                    onSubmitted: (_) => unawaited(_submit()),
                  ),
                  _Suggestions(onPick: _pick),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
              child: BalsmButton(
                label: m.claimAction,
                loading: _submitting,
                onPressed: available && !_submitting ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Up to 3 conflict-aware alternatives, shown only when the attempted handle
/// is taken or reserved (FR-008), derived from it (not the display name).
class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.onPick});

  final ValueChanged<String> onPick;

  /// The attempted handle is already valid, so append short suffixes while
  /// keeping each suggestion within the 3-30 char handle format. Never suggests
  /// the attempted handle verbatim (it is unavailable).
  static List<String> _conflictSuggestions(String handle) {
    final base = handle.toLowerCase().replaceAll(RegExp('[^a-z0-9_.]+'), '').replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    if (base.isEmpty) return const [];
    // Leave room for a short suffix within the 30-char cap.
    final trimmed = base.length > 28 ? base.substring(0, 28) : base;
    return <String>[
      '${trimmed}1',
      '${trimmed}_',
      '$trimmed.1',
    ].where(kHandleFormat.hasMatch).take(3).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(accountStringsProvider);
    final suggestions = ref.watch(
      handleCheckProvider.select(
        (c) => c.status == HandleStatus.taken ? _conflictSuggestions(c.handle) : const <String>[],
      ),
    );
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          m.suggestions,
          style: const TextStyle(
            fontSize: FontSizes.bodySm,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in suggestions)
              GestureDetector(
                onTap: () => onPick(s),
                child: BalsmPill(
                  label: '@$s',
                  variant: BalsmPillVariant.info,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HandleField extends ConsumerWidget {
  const _HandleField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  static Color _borderColor(HandleStatus status) => switch (status) {
        HandleStatus.available => AppColors.success,
        HandleStatus.taken || HandleStatus.invalid => AppColors.danger,
        HandleStatus.idle || HandleStatus.checking => AppColors.border,
      };

  static String? _message(Messages m, HandleCheck check) {
    if (check.claimFailure case final failure?) return accountFailureText(failure);
    if (check.checkFailed) return m.handleCheckFailed;
    return switch (check.status) {
      HandleStatus.invalid => m.handleFormatHint,
      HandleStatus.available => m.handle.available,
      HandleStatus.taken => m.handle.taken,
      HandleStatus.idle || HandleStatus.checking => null,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(accountStringsProvider);
    final check = ref.watch(handleCheckProvider);
    final status = check.status;
    final message = _message(m, check);
    final messageColor = status == HandleStatus.available ? AppColors.success : AppColors.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: _borderColor(status), width: 1.5),
          ),
          child: Row(
            children: [
              const Text(
                '@',
                style: TextStyle(
                  fontSize: FontSizes.subhead,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontSize: FontSizes.subhead, color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'yourhandle',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 4),
                  ),
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                ),
              ),
              _StatusIcon(status: status),
            ],
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(fontSize: FontSizes.meta, color: messageColor),
          ),
        ],
      ],
    );
  }
}

/// Spinner while checking, a check when available, a cross when not.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final HandleStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
        HandleStatus.checking => const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        HandleStatus.available => const Icon(Icons.check_circle, color: AppColors.success, size: 22),
        HandleStatus.taken || HandleStatus.invalid => const Icon(Icons.cancel, color: AppColors.danger, size: 22),
        HandleStatus.idle => const SizedBox.shrink(),
      };
}
