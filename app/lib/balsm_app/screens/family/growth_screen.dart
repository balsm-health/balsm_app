import 'package:core/core.dart';
import 'package:family/family.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
/// Tapping an entry loads it into the form to edit in place; each row's bin
/// deletes it after a confirm sheet (`MCConfirmSheet`).
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

  /// The entry loaded into the form, or null when the form adds a new one.
  GrowthEntry? _editing;

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
    final editing = _editing;
    final result = editing == null
        ? await ref.read(recordGrowthEntryUseCaseProvider)(
            measuredOn: _day,
            weightKg: w,
            heightCm: h,
            now: DateTime.now(),
            profileId: widget.id,
          )
        : await ref.read(updateGrowthEntryUseCaseProvider)(
            id: editing.id,
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
    _reset();
  }

  /// Back to adding a new entry, with an empty form dated today.
  void _reset() => setState(() {
        _weight.clear();
        _height.clear();
        _day = DateTime.now();
        _editing = null;
      });

  void _startEdit(GrowthEntry e) => setState(() {
        _editing = e;
        _weight.text = e.weightKg == null ? '' : formatMeasure(e.weightKg!);
        _height.text = e.heightCm == null ? '' : formatMeasure(e.heightCm!);
        _day = e.measuredOn;
      });

  Future<void> _delete(GrowthEntry e) async {
    final g = s.strings.growth;
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showFamilyConfirmSheet(context, title: g.delete_t, body: g.delete_b);
    if (!yes || !mounted) return;
    final result = await ref.read(deleteGrowthEntryUseCaseProvider)(e.id, profileId: widget.id);
    if (!mounted) return;
    if (result.isFailure) {
      messenger.showSnackBar(SnackBar(content: Text(s.strings.family.save_failed(s.gender))));
      return;
    }
    if (_editing?.id == e.id) _reset();
  }

  @override
  Widget build(BuildContext context) {
    final g = s.strings.growth;
    final entries = ref.watch(growthEntriesProvider(widget.id)).valueOrNull;
    final now = DateTime.now();
    final editing = _editing;
    return FamilyScaffold(
      title: g.title,
      bar: const ProfileBar(),
      children: [
        PCard(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
          border: editing == null ? null : s.accent.main,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (editing != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 12),
                child: Text(g.editing,
                    style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: s.accent.d)),
              ),
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
              editing == null ? g.add : g.save_changes,
              large: true,
              block: true,
              accent: s.accent,
              ar: s.rtl,
              onTap: _typed && !_saving ? _add : null,
            ),
            if (editing != null) ...[
              const SizedBox(height: 8),
              PButton(g.cancel_edit, variant: BtnVariant.ghost, block: true, ar: s.rtl, onTap: _reset),
            ],
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
                ...entries.indexed.map((e) => _EntryRow(
                      entry: e.$2,
                      divider: e.$1 > 0,
                      selected: editing?.id == e.$2.id,
                      onTap: () => _startEdit(e.$2),
                      onDelete: () => _delete(e.$2),
                    )),
              ]),
            ),
          ),
        if (entries != null && entries.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 10),
            child: Text(g.tap_hint(s.gender), style: Typo.meta(ar: s.rtl)),
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

/// One measurement: tap to edit it in the form above, or the bin to delete.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.divider,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });
  final GrowthEntry entry;
  final bool divider;

  /// The entry is the one loaded in the form.
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final g = s.strings.growth;
    final value = Typo.num(size: FS.md, weight: FontWeight.w600, color: T.fg1);
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          decoration: BoxDecoration(
            color: selected ? s.accent.bg : null,
            border: divider ? const Border(top: BorderSide(color: T.ink100)) : null,
          ),
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
            const SizedBox(width: 4),
            RoundBtn(
              icon: LucideIcons.trash2,
              semanticLabel: g.a11y_delete,
              ghost: true,
              iconSize: 16,
              fg: T.fg3,
              onTap: onDelete,
            ),
          ]),
        ),
      ),
    );
  }
}
