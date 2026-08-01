import 'package:flutter/material.dart';

import '../_tokens.dart';
import 'balsm_round_button.dart';

const List<String> _defaultMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Sunday-first, matching the day-grid layout below.
const List<String> _defaultWeekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _clamp(DateTime d, DateTime lo, DateTime hi) => d.isBefore(lo) ? lo : (d.isAfter(hi) ? hi : d);

/// The shared Balsm date picker — a branded bottom-sheet calendar with
/// month/year navigation and a year grid. Use this everywhere a date is chosen
/// (DOB, medication dates, …) instead of Material `showDatePicker`.
///
/// [months] (12) and [weekdays] (7, Sunday-first) default to English; app
/// screens pass their localized `cal_months` / `cal_weekdays`. [rtl] defaults to
/// the ambient [Directionality]; [accent] defaults to the app accent.
Future<DateTime?> showBalsmDatePicker(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  required String title,
  required String confirmLabel,
  DateTime? initial,
  Color accent = BalsmColors.appAccent,
  List<String>? months,
  List<String>? weekdays,
  bool? rtl,
}) {
  assert(!firstDate.isAfter(lastDate), 'firstDate must be on or before lastDate');
  final isRtl = rtl ?? (Directionality.maybeOf(context) == TextDirection.rtl);
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x5C2B2B25),
    isScrollControlled: true,
    builder: (_) => _BalsmDatePickerSheet(
      firstDate: _dateOnly(firstDate),
      lastDate: _dateOnly(lastDate),
      initial: initial == null ? null : _dateOnly(initial),
      title: title,
      confirmLabel: confirmLabel,
      accent: accent,
      months: months ?? _defaultMonths,
      weekdays: weekdays ?? _defaultWeekdays,
      rtl: isRtl,
    ),
  );
}

class _BalsmDatePickerSheet extends StatefulWidget {
  const _BalsmDatePickerSheet({
    required this.firstDate,
    required this.lastDate,
    required this.initial,
    required this.title,
    required this.confirmLabel,
    required this.accent,
    required this.months,
    required this.weekdays,
    required this.rtl,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initial;
  final String title;
  final String confirmLabel;
  final Color accent;
  final List<String> months;
  final List<String> weekdays;
  final bool rtl;

  @override
  State<_BalsmDatePickerSheet> createState() => _BalsmDatePickerSheetState();
}

class _BalsmDatePickerSheetState extends State<_BalsmDatePickerSheet> {
  late int _y;
  late int _m; // 0-based
  DateTime? _sel;
  bool _yearMode = false;

  @override
  void initState() {
    super.initState();
    final view = _clamp(widget.initial ?? DateTime.now(), widget.firstDate, widget.lastDate);
    _y = view.year;
    _m = view.month - 1;
    _sel = widget.initial;
  }

  bool get _canPrev => DateTime(_y, _m + 1, 1).isAfter(widget.firstDate);
  bool get _canNext => DateTime(_y, _m + 2, 0).isBefore(widget.lastDate);

  void _prev() => setState(() {
        if (_m == 0) {
          _m = 11;
          _y--;
        } else {
          _m--;
        }
      });

  void _next() => setState(() {
        if (_m == 11) {
          _m = 0;
          _y++;
        } else {
          _m++;
        }
      });

  @override
  Widget build(BuildContext context) {
    final rtl = widget.rtl;
    final firstWeekday = DateTime(_y, _m + 1, 1).weekday % 7; // Sun = 0
    final daysIn = DateTime(_y, _m + 2, 0).day;
    final years = [for (var y = widget.lastDate.year; y >= widget.firstDate.year; y--) y];

    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: const BoxDecoration(
          color: BalsmColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(BalsmRadius.xl)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: BalsmColors.ink200, borderRadius: BorderRadius.circular(BalsmRadius.pill)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: BalsmColors.fg1)),
              ),
              BalsmRoundButton(
                icon: const Icon(Icons.close, size: 18, color: BalsmColors.fg2),
                size: 36,
                onTap: () => Navigator.pop(context),
                semanticLabel: 'Close',
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  BalsmRoundButton.ghost(
                    icon: Icon(rtl ? Icons.chevron_right : Icons.chevron_left, size: 22, color: BalsmColors.fg2),
                    size: 36,
                    onTap: _canPrev ? _prev : () {},
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _yearMode = !_yearMode),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${widget.months[_m]} $_y',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: BalsmColors.fg1)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 18, color: BalsmColors.fg3),
                    ]),
                  ),
                  BalsmRoundButton.ghost(
                    icon: Icon(rtl ? Icons.chevron_left : Icons.chevron_right, size: 22, color: BalsmColors.fg2),
                    size: 36,
                    onTap: _canNext ? _next : () {},
                  ),
                ]),
                const SizedBox(height: 12),
                if (_yearMode)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.9,
                    children: years
                        .map((y) => GestureDetector(
                              onTap: () => setState(() {
                                _y = y;
                                _yearMode = false;
                              }),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: y == _y ? widget.accent : BalsmColors.border, width: 1.5),
                                  color: y == _y ? widget.accent : BalsmColors.surface,
                                ),
                                child: Text('$y',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: y == _y ? Colors.white : BalsmColors.fg1)),
                              ),
                            ))
                        .toList(),
                  )
                else ...[
                  Row(
                    children: widget.weekdays
                        .map((w) => Expanded(
                              child: Center(
                                child: Text(w,
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w700, color: BalsmColors.fg3)),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 7,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    children: [
                      for (var i = 0; i < firstWeekday; i++) const SizedBox(),
                      for (var d = 1; d <= daysIn; d++)
                        Builder(builder: (_) {
                          final date = DateTime(_y, _m + 1, d);
                          final disabled = date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate);
                          final active = _sel != null && _sel!.year == _y && _sel!.month == _m + 1 && _sel!.day == d;
                          return GestureDetector(
                            onTap: disabled ? null : () => setState(() => _sel = date),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: active ? widget.accent : Colors.transparent,
                              ),
                              child: Text('$d',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                      color: disabled
                                          ? BalsmColors.ink200
                                          : active
                                              ? Colors.white
                                              : BalsmColors.fg1)),
                            ),
                          );
                        }),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ]),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 20),
            child: Opacity(
              opacity: _sel != null ? 1 : 0.4,
              child: GestureDetector(
                onTap: _sel != null ? () => Navigator.pop(context, _sel) : null,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.accent,
                    borderRadius: BorderRadius.circular(BalsmRadius.lg),
                  ),
                  child: Text(widget.confirmLabel,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
