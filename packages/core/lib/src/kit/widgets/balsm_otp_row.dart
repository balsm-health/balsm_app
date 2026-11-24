import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/western_digits.dart';
import '../tokens.dart';

/// 6-box OTP input porting prototype `.otp-row` + `.otp-box`.
/// Auto-advances on each digit; paste-fills all boxes; auto-submits on 6th digit.
class BalsmOtpRow extends StatefulWidget {
  const BalsmOtpRow({
    required this.onCompleted,
    super.key,
    this.length = 6,
  });

  final ValueChanged<String> onCompleted;
  final int length;

  @override
  State<BalsmOtpRow> createState() => _BalsmOtpRowState();
}

class _BalsmOtpRowState extends State<BalsmOtpRow> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final List<String> _values;

  @override
  void initState() {
    super.initState();
    _values = List.filled(widget.length, '');
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String val) {
    // Handle paste
    if (val.length > 1) {
      final digits = toWesternDigits(val).replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < widget.length && i < digits.length; i++) {
        _controllers[i].text = digits[i];
        _values[i] = digits[i];
      }
      setState(() {});
      final filled = _values.join();
      if (filled.length == widget.length) {
        widget.onCompleted(filled);
      }
      return;
    }

    final digit = toWesternDigits(val).replaceAll(RegExp(r'\D'), '');
    setState(() => _values[index] = digit);
    _controllers[index].text = digit;

    if (digit.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        final code = _values.join();
        if (code.length == widget.length) {
          widget.onCompleted(code);
        }
      }
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _values[index].isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      setState(() => _values[index - 1] = '');
      _controllers[index - 1].text = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // A code reads left to right in every language: the first digit lands in
    // the leftmost box, Arabic included.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: _row(),
    );
  }

  Widget _row() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (i) {
        final isFilled = _values[i].isNotEmpty;
        final isFocused = _focusNodes[i].hasFocus;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (e) => _onKeyEvent(i, e),
            child: Focus(
              onFocusChange: (_) => setState(() {}),
              child: SizedBox(
                width: 48,
                height: 60,
                child: Stack(
                  children: [
                    // Visible box
                    AnimatedContainer(
                      duration: Motion.base,
                      curve: Motion.easeOut,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(
                          color: isFocused ? AppColors.hueBlue : (isFilled ? AppColors.hueBlue : AppColors.border),
                          width: 1.5,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: AppColors.hueBlue.withValues(alpha: 0.16),
                                  spreadRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isFilled ? '•' : '',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          fontSize: FontSizes.title,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    // Invisible TextField for input
                    Opacity(
                      opacity: 0,
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(counterText: ''),
                        onChanged: (v) => _onChanged(i, v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
