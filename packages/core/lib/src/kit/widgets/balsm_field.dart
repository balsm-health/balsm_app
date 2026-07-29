import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../_tokens.dart';

enum BalsmFieldVariant { text, email, numeric, date, dropdown }

/// Input field porting prototype `.field` (label above, 56pt height, error state).
class BalsmField extends StatefulWidget {
  const BalsmField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.errorText,
    this.helperText,
    this.variant = BalsmFieldVariant.text,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
  });

  const BalsmField.email({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
  })  : variant = BalsmFieldVariant.email,
        maxLines = 1;

  const BalsmField.numeric({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
  })  : variant = BalsmFieldVariant.numeric,
        maxLines = 1;

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? errorText;
  final String? helperText;
  final BalsmFieldVariant variant;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final int maxLines;

  @override
  State<BalsmField> createState() => _BalsmFieldState();
}

class _BalsmFieldState extends State<BalsmField> {
  bool _focused = false;

  TextInputType get _keyboardType {
    switch (widget.variant) {
      case BalsmFieldVariant.email:
        return TextInputType.emailAddress;
      case BalsmFieldVariant.numeric:
        return TextInputType.number;
      case BalsmFieldVariant.date:
        return TextInputType.datetime;
      default:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter>? get _formatters {
    if (widget.variant == BalsmFieldVariant.numeric) {
      return [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')), // Arabic + Latin
      ];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError ? BalsmColors.danger : (_focused ? BalsmColors.borderFocus : BalsmColors.border);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: BalsmColors.fg2,
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          child: AnimatedContainer(
            duration: BalsmDuration.base,
            curve: kBalsmEaseOut,
            height: widget.maxLines == 1 ? 56 : null,
            decoration: BoxDecoration(
              color: widget.enabled ? Colors.white : BalsmColors.ink50,
              borderRadius: BorderRadius.circular(BalsmRadius.md),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: (hasError ? BalsmColors.danger : BalsmColors.appAccent).withOpacity(0.16),
                        blurRadius: 0,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: TextField(
              controller: widget.controller,
              keyboardType: _keyboardType,
              inputFormatters: _formatters,
              maxLines: widget.maxLines,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              style: const TextStyle(
                fontSize: 18,
                color: BalsmColors.fg1,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: const TextStyle(color: BalsmColors.fg4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: const TextStyle(fontSize: 12, color: BalsmColors.danger),
          ),
        ] else if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.helperText!,
            style: const TextStyle(fontSize: 12, color: BalsmColors.fg3),
          ),
        ],
      ],
    );
  }
}
