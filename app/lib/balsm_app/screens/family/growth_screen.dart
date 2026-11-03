import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../tokens.dart';
import 'family_kit.dart';
import 'health_log_form.dart';
import 'profile_bar.dart';

/// Opens person [id]'s growth log (mother-child.jsx `MCGrowthScreen`).
Future<void> openGrowth(BuildContext context, HealthProfileId id) =>
    pushFamilyScreen<void>(context, (_) => GrowthScreen(id: id));

/// A person's growth log — a manual list, no charts: the add form (weight
/// and/or height, and the day measured) above every entry, newest first.
class GrowthScreen extends ConsumerStatefulWidget {
  const GrowthScreen({super.key, required this.id});
  final HealthProfileId id;
  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  final _weight = TextEditingController();
  final _height = TextEditingController();
  DateTime _day = DateTime.now();
  bool _saving = false;

  PatientAppState get s => AppScope.of(context);

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  bool get _typed => _weight.text.trim().isNotEmpty || _height.text.trim().isNotEmpty;

  Future<void> _add() async {
    if (_saving) return;
    final g = s.strings.growth;
    final messenger = ScaffoldMessenger.of(context);
    final wText = _weight.text.trim();
    final hText = _height.text.trim();
    final w = parseMeasure(wText);
    final h = parseMeasure(hText);
    if ((wText.isNotEmpty && w == null) || (hText.isNotEmpty && h == null)) {
      messenger.showSnackBar(SnackBar(content: Text(g.invalid(s.gender))));
      return;
    }
    setState(() => _saving = true);
    final result = await ref.read(recordGrowthEntryUseCaseProvider)(
      measuredOn: _day,
      weightKg: w,
      heightCm: h,
      now: DateTime.now(),
      profileId: widget.id,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isFailure) {
      final invalid = result.error is ValidationFailure;
      messenger.showSnackBar(SnackBar(
        content: Text(invalid ? g.invalid(s.gender) : s.strings.family.save_failed(s.gender)),
      ));
      return;
    }
    setState(() {
      _weight.clear();
      _height.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = s.strings.growth;
    final entries = ref.watch(growthEntriesProvider(widget.id)).valueOrNull;
    final now = DateTime.now();
    return FamilyScaffold(
      title: g.title,
      bar: const ProfileBar(),
      children: [
        PCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: LogField(label: g.weight, child: _number(_weight))),
              const SizedBox(width: 10),
              Expanded(child: LogField(label: g.height, child: _number(_height))),
            ]),
            LogField(
              label: g.date,
              child: LogDateField(
                value: _day,
                title: g.date,
                first: DateTime(now.year - 120),
                last: now,
                onPicked: (d) => setState(() => _day = d),
              ),
            ),
            PButton(
              g.add,
              large: true,
              block: true,
              accent: s.accent,
              ar: s.rtl,
              onTap: _typed && !_saving ? _add : null,
            ),
          ]),
        ),
        FamilySecHead(g.entries),
        if (entries == null)
          const SizedBox.shrink()
        else if (entries.isEmpty)
          Text(g.empty, style: Typo.bodySm(ar: s.rtl))
        else
          PCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(T.rLg),
              child: Column(children: [
                for (final (i, e) in entries.indexed) _EntryRow(entry: e, divider: i > 0),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _number(TextEditingController c) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹.,٫]')),
          LengthLimitingTextInputFormatter(6)
        ],
        textDirection: TextDirection.ltr,
        onChanged: (_) => setState(() {}),
        style: Typo.num(size: FS.md, weight: FontWeight.w500, color: T.fg1),
        decoration: logInputDecoration(s, null),
      );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.divider});
  final GrowthEntry entry;
  final bool divider;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final g = s.strings.growth;
    final value = Typo.num(size: FS.md, weight: FontWeight.w600, color: T.fg1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: T.ink100))) : null,
      child: Row(children: [
        Expanded(
          child: Text(formatDay(entry.measuredOn),
              textDirection: TextDirection.ltr,
              textAlign: s.rtl ? TextAlign.right : TextAlign.left,
              style: Typo.num(size: FS.sm, weight: FontWeight.w500, color: T.fg3)),
        ),
        Text(entry.weightKg == null ? '—' : g.kg(formatMeasure(entry.weightKg!)), style: value),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 86),
          child: Text(
            entry.heightCm == null ? '—' : g.cm(formatMeasure(entry.heightCm!)),
            textAlign: TextAlign.end,
            style: value,
          ),
        ),
      ]),
    );
  }
}
