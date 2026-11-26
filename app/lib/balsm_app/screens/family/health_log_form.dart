import 'package:core/core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_state.dart';
import 'family_kit.dart';

/// Form pieces shared by the vaccination and growth forms (the design's
/// `.field` label + `.b-input`).

/// A labelled form field; [trailing] sits at the label's end ("Optional").
class LogField extends StatelessWidget {
  const LogField({required this.label, required this.child, super.key, this.trailing, this.hint});
  final String label;
  final Widget child;
  final String? trailing;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final labelStyle = Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: labelStyle)),
              if (trailing case final trailing?)
                Text(trailing, style: Typo.meta(ar: s.rtl).copyWith(color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 8),
          child,
          if (hint case final hint?) ...[
            const SizedBox(height: 6),
            Text(hint, style: Typo.meta(ar: s.rtl).copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }
}

/// The `.b-input` look for a [TextField] in these forms.
InputDecoration logInputDecoration(PatientAppState s, String? hint) => InputDecoration(
      hintText: hint,
      hintStyle: Typo.body(ar: s.rtl).copyWith(color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.white,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: s.accent.main, width: 1.5),
      ),
    );

/// A day picked from the app's date picker (`<input type="date">`), shown
/// DD/MM/YYYY; [onClear] adds a clear button for an optional day.
class LogDateField extends StatelessWidget {
  const LogDateField({
    required this.value,
    required this.title,
    required this.first,
    required this.last,
    required this.onPicked,
    super.key,
    this.onClear,
  });
  final DateTime? value;
  final String title;
  final DateTime first;
  final DateTime last;
  final ValueChanged<DateTime> onPicked;
  final VoidCallback? onClear;

  Future<void> _pick(BuildContext context) async {
    final s = AppScope.of(context);
    final initial = value ?? (last.isBefore(DateTime.now()) ? last : DateTime.now());
    final picked = await showBalsmDatePicker(
      context,
      initial: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: last,
      title: title,
      confirmLabel: s.strings.onboarding.dob_confirm,
      months: s.strings.settings.cal_months.split('|'),
      weekdays: s.strings.settings.cal_weekdays.split('|'),
      rtl: s.rtl,
      accent: s.accent.main,
    );
    // The form may have closed while the picker was open.
    if (picked != null && context.mounted) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final day = value;
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: () => _pick(context),
        child: InputDecorator(
          decoration: logInputDecoration(s, null),
          child: Row(
            children: [
              const Icon(LucideIcons.calendar, size: 17, color: AppColors.textTertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  day == null ? s.strings.family.f_dob_ph : formatDay(day),
                  textDirection: TextDirection.ltr,
                  textAlign: s.rtl ? TextAlign.right : TextAlign.left,
                  style: Typo.body(ar: s.rtl)
                      .copyWith(color: day == null ? AppColors.textTertiary : AppColors.textPrimary),
                ),
              ),
              if (day != null && onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Semantics(
                    button: true,
                    label: s.strings.vacc.f_next_clear,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(LucideIcons.x, size: 16, color: AppColors.textTertiary),
                    ),
                  ),
                )
              else
                const Icon(LucideIcons.chevronDown, size: 15, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A measurement typed on either keyboard: Arabic-Indic digits and the
/// Arabic decimal separator or a comma are read as their Latin forms. Null
/// for blank or unreadable text.
double? parseMeasure(String text) {
  // U+066B is the Arabic decimal separator.
  final s = toWesternDigits(text.trim()).replaceAll(RegExp('[\u066B,]'), '.');
  // Plain digits with at most one point. `double.tryParse` alone also takes
  // "NaN", "Infinity" and "1e5", none of which is a measurement.
  if (!RegExp(r'^(\d+\.?\d*|\.\d+)$').hasMatch(s)) return null;
  return double.tryParse(s);
}

/// A measurement as shown in a list: no trailing zeros ("12", "9.85").
String formatMeasure(double v) {
  final fixed = v.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}
