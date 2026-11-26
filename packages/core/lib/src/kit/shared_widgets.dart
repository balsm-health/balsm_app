import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/western_digits.dart';
import '../localization/core_messages.dart';
import 'tokens.dart';

class BalsmButton extends StatelessWidget {
  const BalsmButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = BalsmButtonVariant.primary,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final BalsmButtonVariant variant;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == BalsmButtonVariant.primary;
    final isDanger = variant == BalsmButtonVariant.danger;

    final bg = isPrimary
        ? AppColors.hueBlue
        : isDanger
            ? AppColors.danger
            : Colors.transparent;
    final fg = (isPrimary || isDanger) ? AppColors.white : AppColors.hueBlue;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
          side: isPrimary || isDanger ? BorderSide.none : const BorderSide(color: AppColors.hueBlue),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                  Text(label, style: const TextStyle(fontSize: FontSizes.body, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}

enum BalsmButtonVariant { primary, secondary, danger }

class BalsmTextField extends StatelessWidget {
  const BalsmTextField({
    required this.label,
    super.key,
    this.controller,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.onChanged,
    this.obscureText = false,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: FontSizes.bodySm, fontWeight: FontWeight.w600, color: AppColors.ink700),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: switch (onChanged) { final onChanged? => (v) => onChanged(toWesternDigits(v)), _ => null },
          obscureText: obscureText,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
          ),
        ),
      ],
    );
  }
}

class BalsmCountryPicker extends StatelessWidget {
  const BalsmCountryPicker({
    required this.countries,
    required this.selected,
    required this.onSelected,
    super.key,
    this.searchHint = 'Search countries',
  });

  final List<({String code, String name})> countries;
  final String? selected;
  final ValueChanged<String> onSelected;
  final String searchHint;

  @override
  Widget build(BuildContext context) {
    final selectedCountry = selected != null
        ? countries.firstWhere((c) => c.code == selected, orElse: () => (code: '', name: 'Select country'))
        : null;

    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.ink200),
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedCountry?.name ?? 'Select country',
                style: TextStyle(
                  color: selected == null ? AppColors.ink400 : AppColors.ink900,
                  fontSize: FontSizes.bodyLg,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.ink600),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => _CountryPickerSheet(
        countries: countries,
        searchHint: searchHint,
        onSelected: (code) {
          Navigator.pop(ctx);
          onSelected(code);
        },
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.countries,
    required this.searchHint,
    required this.onSelected,
  });

  final List<({String code, String name})> countries;
  final String searchHint;
  final ValueChanged<String> onSelected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.countries.where((c) => c.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: filtered.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(filtered[i].name),
                onTap: () => widget.onSelected(filtered[i].code),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BalsmLoadingIndicator extends StatelessWidget {
  const BalsmLoadingIndicator({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.hueBlue,
          ),
        ),
      );
}

class BalsmErrorBanner extends StatelessWidget {
  const BalsmErrorBanner({required this.message, super.key, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.danger.withAlpha(20),
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: AppColors.danger.withAlpha(60)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: FontSizes.description)),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(coreMessagesOf(context).common.retry, style: const TextStyle(color: AppColors.danger)),
              ),
          ],
        ),
      );
}
