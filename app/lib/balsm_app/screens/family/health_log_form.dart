import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../tokens.dart';
import 'family_kit.dart';

/// Form pieces shared by the vaccination and growth forms (the design's
/// `.field` label + `.b-input`).

/// A labelled form field; [trailing] sits at the label's end ("Optional").
class LogField extends StatelessWidget {
  const LogField({super.key, required this.label, required this.child, this.trailing, this.hint});
  final String label;
  final Widget child;
  final String? trailing;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final labelStyle = Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: labelStyle)),
          if (trailing != null) Text(trailing!, style: Typo.meta(ar: s.rtl).copyWith(color: T.fg3)),
        ]),
        const SizedBox(height: 8),
        child,
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(hint!, style: Typo.meta(ar: s.rtl).copyWith(height: 1.5)),
        ],
      ]),
    );
  }
}

/// The `.b-input` look for a [TextField] in these forms.
InputDecoration logInputDecoration(PatientAppState s, String? hint) => InputDecoration(
      hintText: hint,
      hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4),
      filled: true,
      fillColor: Colors.white,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
    );

/// A day picked from the app's date picker (`<input type="date">`), shown
/// DD/MM/YYYY; [onClear] adds a clear button for an optional day.
class LogDateField extends StatelessWidget {
  const LogDateField({
    super.key,
    required this.value,
    required this.title,
    required this.first,
    required this.last,
    required this.onPicked,
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
    if (picked != null) onPicked(picked);
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
          child: Row(children: [
            const Icon(LucideIcons.calendar, size: 17, color: T.fg3),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                day == null ? s.strings.family.f_dob_ph : formatDay(day),
                textDirection: TextDirection.ltr,
                textAlign: s.rtl ? TextAlign.right : TextAlign.left,
                style: Typo.body(ar: s.rtl).copyWith(color: day == null ? T.fg3 : T.fg1),
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
                    child: Icon(LucideIcons.x, size: 16, color: T.fg3),
                  ),
                ),
              )
            else
              const Icon(LucideIcons.chevronDown, size: 15, color: T.fg3),
          ]),
        ),
      ),
    );
  }
}

/// A measurement typed on either keyboard: Arabic-Indic digits and the
/// Arabic decimal separator or a comma are read as their Latin forms. Null
/// for blank or unreadable text.
double? parseMeasure(String text) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in text.trim().split('')) {
    final i = arabic.indexOf(ch);
    final j = persian.indexOf(ch);
    b.write(i >= 0
        ? '$i'
        : j >= 0
            ? '$j'
            : (ch == '٫' || ch == ',')
                ? '.'
                : ch);
  }
  final s = b.toString();
  return s.isEmpty ? null : double.tryParse(s);
}

/// A measurement as shown in a list: no trailing zeros ("12", "9.85").
String formatMeasure(double v) {
  final fixed = v.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}
