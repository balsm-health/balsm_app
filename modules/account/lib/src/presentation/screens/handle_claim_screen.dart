import 'dart:async';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/use_cases/claim_handle_use_case.dart';
import '../failure_text.dart';
import '../i18n/i18n.dart';

/// Status of the live handle-availability check.
enum _HandleStatus { idle, checking, available, taken, invalid }

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
  Timer? _debounce;
  _HandleStatus _status = _HandleStatus.idle;
  String? _message;
  bool _submitting = false;

  @override
  void dispose() {
    _debounce?.cancel();
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

    _debounce?.cancel();

    if (value.isEmpty) {
      setState(() {
        _status = _HandleStatus.idle;
        _message = null;
      });
      return;
    }

    if (!kHandleFormat.hasMatch(value)) {
      setState(() {
        _status = _HandleStatus.invalid;
        _message = ref.read(accountStringsProvider).handleFormatHint;
      });
      return;
    }

    setState(() {
      _status = _HandleStatus.checking;
      _message = null;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () => _check(value));
  }

  Future<void> _check(String handle) async {
    final api = ref.read(accountApiProvider);
    try {
      final res = await api.checkHandleAvailability(handle);
      if (!mounted || _controller.text != handle) return;
      final available = res.available;
      setState(() {
        _status = available ? _HandleStatus.available : _HandleStatus.taken;
        _message = available
            ? ref.read(accountStringsProvider).handle.available
            : ref.read(accountStringsProvider).handle.taken;
      });
    } on ApiException catch (e) {
      if (!mounted || _controller.text != handle) return;
      final taken = e.statusCode == 409;
      setState(() {
        _status = taken ? _HandleStatus.taken : _HandleStatus.idle;
        _message =
            taken ? ref.read(accountStringsProvider).handle.taken : ref.read(accountStringsProvider).handleCheckFailed;
      });
    }
  }

  /// Conflict-aware alternatives for a taken/reserved [handle]. The attempted
  /// handle is already valid, so append short suffixes while keeping each
  /// suggestion within the 3-30 char handle format. Never suggests the
  /// attempted handle verbatim (it is unavailable).
  List<String> _conflictSuggestions(String handle) {
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

  Future<void> _submit() async {
    final handle = _controller.text.trim();
    if (handle.isEmpty || _status != _HandleStatus.available) return;
    setState(() => _submitting = true);
    final result = await ref.read(claimHandleUseCaseProvider).execute(handle);
    if (!mounted) return;
    setState(() => _submitting = false);
    result.fold(
      (claimed) {
        // Refresh the account summary so the new handle is reflected.
        // Must drop the retained row, not just rebuild the provider.
        unawaited(refreshAccountSummary(ref));
        Navigator.of(context).maybePop(claimed);
      },
      (failure) {
        setState(() {
          if (failure is ConflictFailure) {
            _status = _HandleStatus.taken;
            _message = ref.read(accountStringsProvider).handle.taken;
          } else {
            _message = accountFailureText(failure);
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(accountStringsProvider);
    // Only surface suggestions on a taken/reserved conflict, derived from the
    // attempted handle (not the unrelated display name).
    final suggestions =
        _status == _HandleStatus.taken ? _conflictSuggestions(_controller.text.trim()) : const <String>[];

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
                    status: _status,
                    message: _message,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _submit(),
                  ),
                  if (suggestions.isNotEmpty) ...[
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
                      children: suggestions
                          .map(
                            (s) => GestureDetector(
                              onTap: () {
                                _controller.text = s;
                                _onChanged(s);
                              },
                              child: BalsmPill(
                                label: '@$s',
                                variant: BalsmPillVariant.info,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
              child: BalsmButton(
                label: m.claimAction,
                loading: _submitting,
                onPressed: _status == _HandleStatus.available && !_submitting ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandleField extends StatelessWidget {
  const _HandleField({
    required this.controller,
    required this.status,
    required this.message,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final _HandleStatus status;
  final String? message;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  Color get _borderColor {
    switch (status) {
      case _HandleStatus.available:
        return AppColors.success;
      case _HandleStatus.taken:
      case _HandleStatus.invalid:
        return AppColors.danger;
      default:
        return AppColors.border;
    }
  }

  Widget? get _suffix {
    switch (status) {
      case _HandleStatus.checking:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _HandleStatus.available:
        return const Icon(Icons.check_circle, color: AppColors.success, size: 22);
      case _HandleStatus.taken:
      case _HandleStatus.invalid:
        return const Icon(Icons.cancel, color: AppColors.danger, size: 22);
      case _HandleStatus.idle:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageColor = status == _HandleStatus.available ? AppColors.success : AppColors.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: _borderColor, width: 1.5),
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
              if (_suffix case final suffix?) suffix,
            ],
          ),
        ),
        if (message case final message?) ...[
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
