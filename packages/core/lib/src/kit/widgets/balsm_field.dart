import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

enum BalsmFieldVariant { text, email, numeric, date, dropdown }

/// Input field porting prototype `.field` (label above, 56pt height, error state).
class BalsmField extends StatefulWidget {
  const BalsmField({
    required this.label,
    super.key,
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
    required this.label,
    super.key,
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
    required this.label,
    super.key,
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
        FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩]')), // Arabic + Latin
      ];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError ? AppColors.danger : (_focused ? AppColors.borderFocus : AppColors.border);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: FontSizes.bodySm,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.easeOut,
            height: widget.maxLines == 1 ? 56 : null,
            decoration: BoxDecoration(
              color: widget.enabled ? AppColors.white : AppColors.ink50,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: (hasError ? AppColors.danger : AppColors.hueBlue).withValues(alpha: 0.16),
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
                fontSize: FontSizes.subhead,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: const TextStyle(color: AppColors.textHint),
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
            style: const TextStyle(fontSize: FontSizes.meta, color: AppColors.danger),
          ),
        ] else if (widget.helperText case final helperText?) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: const TextStyle(fontSize: FontSizes.meta, color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }
}
