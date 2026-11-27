import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';

/// iOS-Reminders-style date/time group from Claude Design `DateTimeRow`.
class DateTimeWhen extends StatelessWidget {
  const DateTimeWhen({
    required this.when,
    required this.onChanged,
    super.key,
    this.bare = false,
    this.dateLabel,
    this.lastDate,
    this.expiry,
    this.onExpiryChanged,
    this.expiryLabel,
  });

  final DateTime when;
  final ValueChanged<DateTime> onChanged;
  final bool bare;
  final String? dateLabel;

  /// Caps the issued-date picker. Defaults to today (metric / record logs).
  final DateTime? lastDate;

  /// Optional third row for an expiration date (prescriptions).
  final DateTime? expiry;
  final ValueChanged<DateTime?>? onExpiryChanged;
  final String? expiryLabel;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);
    final dateText = day == today ? s.strings.common.today : '${when.day} ${_shortMonth(when.month, s)}';
    final timeText = TimeOfDay.fromDateTime(when).format(context);
    final expiryDay = switch (expiry) { final expiry? => DateTime(expiry.year, expiry.month, expiry.day), _ => null };
    final expiryText = expiryDay == null
        ? s.strings.common.select_date(s.gender)
        : expiryDay == today
            ? s.strings.common.today
            : '${expiry!.day} ${_shortMonth(expiry!.month, s)}';

    return Container(
      margin: bare ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: bare ? BorderRadius.zero : BorderRadius.circular(AppRadii.lg),
        border: bare ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _DateTimeRow(
            icon: LucideIcons.calendar,
            chipBg: AppColors.dangerBackground,
            chipFg: AppColors.danger,
            label: dateLabel ?? s.strings.common.date,
            value: dateText,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: when,
                firstDate: DateTime(1900),
                lastDate: lastDate ?? DateTime.now(),
              );
              if (picked == null) return;
              onChanged(DateTime(picked.year, picked.month, picked.day, when.hour, when.minute));
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          _DateTimeRow(
            icon: LucideIcons.clock,
            chipBg: AppColors.hueBlue50,
            chipFg: AppColors.hueBlue,
            label: s.strings.common.time,
            value: timeText,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(when),
              );
              if (picked == null) return;
              onChanged(DateTime(when.year, when.month, when.day, picked.hour, picked.minute));
            },
          ),
          if (onExpiryChanged case final onExpiryChanged?) ...[
            const Divider(height: 1, color: AppColors.border),
            _DateTimeRow(
              icon: LucideIcons.calendar,
              chipBg: AppColors.hueViolet50,
              chipFg: AppColors.hueViolet,
              label: expiryLabel ?? s.strings.meds.rx_expiry,
              value: expiryText,
              muted: expiry == null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: expiry ?? when,
                  firstDate: DateTime(when.year, when.month, when.day),
                  lastDate: DateTime(now.year + 20),
                );
                if (picked == null) return;
                onExpiryChanged(DateTime(picked.year, picked.month, picked.day));
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.icon,
    required this.chipBg,
    required this.chipFg,
    required this.label,
    required this.value,
    required this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final Color chipBg;
  final Color chipFg;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PressHighlight(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(AppRadii.md)),
              child: Icon(icon, size: 17, color: chipFg),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textPrimary))),
            Text(
              value,
              style: Typo.body(ar: s.rtl)
                  .copyWith(fontWeight: FontWeight.w500, color: muted ? AppColors.textTertiary : AppColors.hueBlue),
            ),
          ],
        ),
      ),
    );
  }
}

// Localized via i69n `settings.cal_months` (was a hardcoded EN/AR ternary;
// CODING_STANDARDS: no inline bilingual ternaries).
String _shortMonth(int month, PatientAppState s) => s.strings.settings.cal_months.split('|')[month - 1];
