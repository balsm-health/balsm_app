import 'dart:async';

import 'package:balsm_api/balsm_api.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/use_cases/claim_handle_use_case.dart';

/// Status of the live handle-availability check.
enum _HandleStatus { idle, checking, available, taken, invalid }

/// Screen for claiming an `@handle`.
///
/// - `@`-prefixed input, lowercased.
/// - Debounced 500ms live validation (format + availability).
/// - Green check when available, red X when taken/invalid.
/// - Up to 3 suggestions derived from displayName.
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
    final value = raw.replaceFirst(RegExp(r'^@'), '').toLowerCase();
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
        _message = '3-30 characters: a-z, 0-9, _ or .';
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
        _message = available ? 'Available' : 'Handle taken';
      });
    } on ApiException catch (e) {
      if (!mounted || _controller.text != handle) return;
      final taken = e.statusCode == 409;
      setState(() {
        _status = taken ? _HandleStatus.taken : _HandleStatus.idle;
        _message = taken ? 'Handle taken' : 'Could not check availability';
      });
    }
  }

  List<String> _suggestions(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) return const [];
    final base = displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.]+'), '')
        .replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    if (base.isEmpty) return const [];
    final trimmed = base.length > 24 ? base.substring(0, 24) : base;
    return [
      trimmed,
      '$trimmed.1',
      '${trimmed}_',
    ].where((s) => kHandleFormat.hasMatch(s)).take(3).toList();
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
        ref.invalidate(accountSummaryProvider);
        Navigator.of(context).maybePop(claimed);
      },
      (failure) {
        setState(() {
          if (failure is ConflictFailure) {
            _status = _HandleStatus.taken;
            _message = 'Handle taken';
          } else {
            _message = failure.message;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(accountSummaryProvider);
    final displayName = summaryAsync.asData?.value?.displayName;
    final suggestions = _suggestions(displayName);

    return Scaffold(
      backgroundColor: BalsmColors.cream50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BalsmAppBar.withBack(
              title: 'Claim your handle',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Pick a unique @handle. People can find you with it.',
                    style: TextStyle(fontSize: 14, color: BalsmColors.fg3),
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
                    const Text(
                      'Suggestions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BalsmColors.fg2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions
                          .map((s) => GestureDetector(
                                onTap: () {
                                  _controller.text = s;
                                  _onChanged(s);
                                },
                                child: BalsmPill(
                                  label: '@$s',
                                  variant: BalsmPillVariant.info,
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: BalsmButton(
                label: 'Claim handle',
                loading: _submitting,
                onPressed: _status == _HandleStatus.available && !_submitting
                    ? _submit
                    : null,
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
        return BalsmColors.success;
      case _HandleStatus.taken:
      case _HandleStatus.invalid:
        return BalsmColors.danger;
      default:
        return BalsmColors.border;
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
        return const Icon(Icons.check_circle,
            color: BalsmColors.success, size: 22);
      case _HandleStatus.taken:
      case _HandleStatus.invalid:
        return const Icon(Icons.cancel, color: BalsmColors.danger, size: 22);
      case _HandleStatus.idle:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageColor = status == _HandleStatus.available
        ? BalsmColors.success
        : BalsmColors.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(BalsmRadius.md),
            border: Border.all(color: _borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              const Text(
                '@',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: BalsmColors.fg3,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontSize: 18, color: BalsmColors.fg1),
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
              if (_suffix != null) _suffix!,
            ],
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            style: TextStyle(fontSize: 12, color: messageColor),
          ),
        ],
      ],
    );
  }
}
