import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pregnancy/pregnancy.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../shell.dart';
import '../family/family_kit.dart';
import 'pregnancy_kit.dart';
import 'pregnancy_screen.dart';

enum _Mode { due, lastPeriod }

/// Start pregnancy tracking (mother-child.jsx `MCPregStartScreen`): a due
/// date, or the first day of the last period (due date estimated from it);
/// how many babies; the obstetrician's name and phone. With [mother] it
/// starts tracking on that family member's profile.
class PregnancyStartScreen extends ConsumerStatefulWidget {
  const PregnancyStartScreen({super.key, this.mother});

  /// Whose pregnancy (null = the account holder's own).
  final HealthProfileId? mother;
  @override
  ConsumerState<PregnancyStartScreen> createState() => _PregnancyStartScreenState();
}

class _PregnancyStartScreenState extends ConsumerState<PregnancyStartScreen> {
  _Mode _mode = _Mode.due;
  DateTime? _date;
  int _count = 1;
  final _ob = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ob.dispose();
    _phone.dispose();
    super.dispose();
  }

  DateTime? get _due {
    final d = _date;
    if (d == null) return null;
    return _mode == _Mode.due ? d : PregnancyDates.dueFromLastPeriod(d);
  }

  Future<void> _pick() async {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final now = DateTime.now();
    final due = _mode == _Mode.due;
    final picked = await pickDay(
      context,
      title: due ? p.due_date : p.lmp,
      initial: _date ?? now,
      first: due
          ? now.subtract(const Duration(days: Pregnancy.maxDaysPast))
          : now.subtract(const Duration(days: PregnancyDates.termDays + Pregnancy.maxDaysPast)),
      last: due ? now.add(const Duration(days: Pregnancy.maxDaysAhead)) : now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final due = _due;
    final mother = widget.mother ?? await ref.read(selfProfileIdProvider.future);
    if (due == null || mother == null || _saving) return;
    setState(() => _saving = true);
    final r = await ref.read(startPregnancyUseCaseProvider)(
      motherId: mother,
      dueDate: due,
      babyCount: _count,
      now: DateTime.now(),
      obName: _ob.text,
      obPhone: _phone.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r.isFailure) {
      final s = AppScope.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.strings.family.save_failed(s.gender))));
      return;
    }
    final dir = AppScope.of(context).dir;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            Directionality(textDirection: dir, child: AdaptiveFrame(child: PregnancyScreen(mother: widget.mother))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final due = _due;
    final owner = pregnancyOwner(ref, widget.mother);
    return FamilyScaffold(
      title: owner == null ? p.title : p.title_of(owner.shortName),
      footer: PButton(
        owner == null ? p.start_cta : p.start_cta_of(s.gender),
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: due == null || _saving ? null : _save,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            owner == null ? p.start_note : p.start_note_of(owner.shortName, s.gender),
            style: Typo.bodySm(ar: s.rtl),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: BalsmSegmented<_Mode>(
            options: _Mode.values,
            labelOf: (m) => m == _Mode.due ? p.mode_due : p.mode_lmp,
            selected: _mode,
            onChanged: (m) => setState(() {
              _mode = m;
              _date = null;
            }),
          ),
        ),
        LabelledField(
          label: _mode == _Mode.due ? p.due_date : p.lmp,
          help: _mode == _Mode.lastPeriod && due != null ? '${p.est_due} ${formatDay(due)}' : null,
          child: DayField(value: _date, placeholder: p.pick_date, onTap: _pick),
        ),
        LabelledField(
          label: p.how_many,
          help: p.add_later,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  const gap = 8.0;
                  final w = (c.maxWidth - gap * 3) / 4;
                  return Wrap(
                    spacing: gap,
                    children: [
                      for (final n in [1, 2, 3])
                        SizedBox(
                          width: w,
                          child: _CountChip(label: '$n', active: _count == n, onTap: () => setState(() => _count = n)),
                        ),
                      SizedBox(
                        width: w,
                        child: _CountChip(
                          label: p.more,
                          active: _count >= 4,
                          onTap: () => setState(() => _count = _count >= 4 ? _count : 4),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (_count >= 4)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      RoundBtn(
                        icon: LucideIcons.minus,
                        semanticLabel: '−',
                        iconSize: 18,
                        onTap: () => setState(() => _count = (_count - 1).clamp(4, Pregnancy.maxBabies)),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$_count',
                          textAlign: TextAlign.center,
                          style: Typo.num(size: FontSizes.subhead, weight: FontWeight.w700),
                        ),
                      ),
                      RoundBtn(
                        icon: LucideIcons.plus,
                        semanticLabel: '+',
                        iconSize: 18,
                        onTap: () => setState(() => _count = (_count + 1).clamp(4, Pregnancy.maxBabies)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        LabelledField(
          label: p.ob,
          child: TextField(
            controller: _ob,
            maxLength: Pregnancy.maxTextLength,
            decoration: fieldDecoration(s, p.ob_name_ph).copyWith(counterText: ''),
          ),
        ),
        LabelledField(
          label: p.phone,
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            maxLength: Pregnancy.maxTextLength,
            decoration: fieldDecoration(s, '+20').copyWith(counterText: ''),
          ),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Semantics(
      button: true,
      selected: active,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? s.accent.main : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: active ? s.accent.main : AppColors.border, width: 1.5),
          ),
          child: Text(
            label,
            style: Typo.bodySm(ar: s.rtl).copyWith(
              fontWeight: FontWeight.w600,
              color: active ? ColorContrast.onFill(s.accent.main) : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
