import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pregnancy/pregnancy.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../tokens.dart';
import '../../widgets/photo_attach.dart';
import '../family/family_kit.dart';
import 'pregnancy_kit.dart';

/// Opens the attach flow, preselecting [babyIds] (from a baby's screen).
Future<void> openPregnancyAdd(BuildContext context, {List<HealthProfileId> babyIds = const []}) =>
    pushFamilyScreen<void>(context, (_) => PregnancyAddScreen(babyIds: babyIds));

/// Attach a pregnancy record (mother-child.jsx `MCPregAddScreen`): about me,
/// one baby or several (a shared report); a scan, measurements (one baby at a
/// time) or a test/document. The file is stored encrypted on this phone.
class PregnancyAddScreen extends ConsumerStatefulWidget {
  const PregnancyAddScreen({super.key, this.babyIds = const []});
  final List<HealthProfileId> babyIds;
  @override
  ConsumerState<PregnancyAddScreen> createState() => _PregnancyAddScreenState();
}

class _PregnancyAddScreenState extends ConsumerState<PregnancyAddScreen> {
  bool _me = false;
  late final Set<HealthProfileId> _babies = {...widget.babyIds};
  ItemKind _kind = ItemKind.scan;
  final _title = TextEditingController();
  DateTime _date = DateTime.now();
  final _hr = TextEditingController();
  final _efw = TextEditingController();
  final _otherLabel = TextEditingController();
  final _otherValue = TextEditingController();
  PickedAttach? _file;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _hr, _efw, _otherLabel, _otherValue]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canMeasure => !_me && _babies.length == 1;
  ItemKind get _effectiveKind => _kind == ItemKind.measure && !_canMeasure ? ItemKind.scan : _kind;

  static int? _int(String s) => int.tryParse(s.trim());

  /// The form as the domain sees it; its rules decide whether Save is on.
  AppResult<PregnancyItem> _draft(Pregnancy preg, {String? fileRef}) => PregnancyItem.create(
        id: const PregnancyItemId.value('draft'),
        pregnancyId: preg.id,
        about: _me ? ItemAbout.me : ItemAbout.baby,
        babyIds: _me ? const [] : _babies.toList(),
        kind: _effectiveKind,
        recordedOn: _date,
        now: DateTime.now(),
        title: _title.text,
        fetalHeartRateBpm: _int(_hr.text),
        estimatedFetalWeightG: _int(_efw.text),
        otherLabel: _otherLabel.text,
        otherValue: _otherValue.text,
        attachmentRef: fileRef ?? (_file == null ? null : 'picked'),
      );

  bool _numbersParse() =>
      (_hr.text.trim().isEmpty || _int(_hr.text) != null) && (_efw.text.trim().isEmpty || _int(_efw.text) != null);

  Future<void> _pickFile() async {
    final picked = await pickAttachment(context);
    if (picked == null || picked.bytes == null || !mounted) return;
    setState(() => _file = picked);
  }

  Future<void> _save(Pregnancy preg) async {
    if (_saving) return;
    setState(() => _saving = true);
    String? ref0;
    try {
      final f = _file;
      if (f != null && _effectiveKind != ItemKind.measure) {
        ref0 = await ref.read(userFileStoreProvider).save(f.name ?? 'pregnancy-record', f.bytes!);
      }
    } catch (_) {
      ref0 = null;
    }
    if (_file != null && ref0 == null && _effectiveKind != ItemKind.measure) return _fail();
    final r = await ref.read(pregnancyRecordsUseCaseProvider).addItem(
          pregnancyId: preg.id,
          motherId: preg.motherId,
          about: _me ? ItemAbout.me : ItemAbout.baby,
          babyIds: _me ? const [] : _babies.toList(),
          kind: _effectiveKind,
          recordedOn: _date,
          now: DateTime.now(),
          title: _title.text,
          fetalHeartRateBpm: _int(_hr.text),
          estimatedFetalWeightG: _int(_efw.text),
          otherLabel: _otherLabel.text,
          otherValue: _otherValue.text,
          attachmentRef: ref0,
        );
    if (!mounted) return;
    if (r.isFailure) return _fail();
    Navigator.pop(context);
  }

  void _fail() {
    if (!mounted) return;
    setState(() => _saving = false);
    final s = AppScope.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.strings.family.save_failed(s.gender))));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final preg = ref.watch(activePregnancyProvider);
    if (preg == null) return const Scaffold(backgroundColor: Colors.white);
    final all = ref.watch(pregnancyBabiesProvider(preg.id)).valueOrNull ?? const <PregnancyBaby>[];
    final active = all.where((b) => b.isActive).toList();
    final chosen = _me || _babies.isNotEmpty;
    final kinds = _canMeasure ? ItemKind.values : const [ItemKind.scan, ItemKind.doc];
    final kind = _effectiveKind;
    final ok = chosen && _numbersParse() && _draft(preg).isSuccess;
    final allOn = active.length > 1 && active.every((b) => _babies.contains(b.id));

    return FamilyScaffold(
      title: p.attach_t,
      footer: PButton(s.strings.family.save,
          large: true, block: true, accent: s.accent, ar: s.rtl, onTap: ok && !_saving ? () => _save(preg) : null),
      children: [
        LabelledField(
          label: p.who,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _WhoOption(
              me: true,
              label: p.me,
              on: _me,
              onTap: () => setState(() {
                _me = !_me;
                _babies.clear();
              }),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, c) {
              const gap = 8.0;
              final w = active.length > 1 ? (c.maxWidth - gap) / 2 : c.maxWidth;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                for (final b in active)
                  SizedBox(
                    width: w,
                    child: _WhoOption(
                      label: babyLabel(s, b, all),
                      on: _babies.contains(b.id),
                      onTap: () => setState(() {
                        _me = false;
                        _babies.contains(b.id) ? _babies.remove(b.id) : _babies.add(b.id);
                      }),
                    ),
                  ),
              ]);
            }),
            if (active.length > 1)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => setState(() {
                    _me = false;
                    allOn ? _babies.clear() : _babies.addAll(active.map((b) => b.id));
                  }),
                  child: Text(allOn ? p.clear_babies : p.all_babies,
                      style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: s.accent.d)),
                ),
              ),
          ]),
        ),
        if (chosen) ...[
          LabelledField(
            label: p.type,
            help: !_me && _babies.length > 1 ? p.one_at_a_time : null,
            child: BalsmSegmented<ItemKind>(
              options: kinds,
              labelOf: (k) => itemKindLabel(s, k),
              selected: kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
          ),
          LabelledField(
            label: kind == ItemKind.measure ? '${p.title_l} · ${s.strings.family.optional}' : p.title_l,
            child: TextField(
              controller: _title,
              maxLength: PregnancyItem.maxTitleLength,
              onChanged: (_) => setState(() {}),
              decoration: fieldDecoration(s, kind == ItemKind.measure ? p.title_ph_measure : p.title_ph)
                  .copyWith(counterText: ''),
            ),
          ),
          LabelledField(
            label: p.date,
            child: DayField(
              value: _date,
              placeholder: p.pick_date,
              onTap: () async {
                final now = DateTime.now();
                final picked = await pickDay(context,
                    title: p.date, initial: _date, first: now.subtract(const Duration(days: 400)), last: now);
                if (picked != null && mounted) setState(() => _date = picked);
              },
            ),
          ),
          if (kind == ItemKind.measure) ..._measureFields(s) else _fileField(s),
        ],
      ],
    );
  }

  List<Widget> _measureFields(PatientAppState s) {
    final p = s.strings.pregnancy;
    Widget field(String label, TextEditingController c, {String? hint, bool number = false}) => Expanded(
          child: LabelledField(
            label: label,
            child: TextField(
              controller: c,
              keyboardType: number ? TextInputType.number : TextInputType.text,
              maxLength: PregnancyItem.maxOtherLength,
              onChanged: (_) => setState(() {}),
              decoration: fieldDecoration(s, hint).copyWith(counterText: ''),
            ),
          ),
        );
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        field(p.hr_field, _hr, number: true),
        const SizedBox(width: 10),
        field(p.efw_field, _efw, number: true),
      ]),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        field(p.other_field, _otherLabel, hint: p.other_ph),
        const SizedBox(width: 10),
        field(p.value, _otherValue, hint: p.value_ph),
      ]),
      Text(p.as_written, style: Typo.meta(ar: s.rtl)),
    ];
  }

  Widget _fileField(PatientAppState s) {
    final p = s.strings.pregnancy;
    final f = _file;
    return LabelledField(
      label: p.file,
      child: Semantics(
        button: true,
        child: PCard(
          flat: true,
          onTap: _pickFile,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            IconSquare(f == null ? LucideIcons.camera : LucideIcons.paperclip, bg: T.ink50, fg: T.fg2, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f == null ? p.file_pick : (f.name ?? p.file_attached),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                Text(p.file_local, style: Typo.meta(ar: s.rtl)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// "Me" (round tick) or a baby (square tick) in the who-is-this-about list.
class _WhoOption extends StatelessWidget {
  const _WhoOption({required this.label, required this.on, required this.onTap, this.me = false});
  final String label;
  final bool on;
  final VoidCallback onTap;
  final bool me;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Semantics(
      button: true,
      selected: on,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: on ? s.accent.bg : Colors.white,
            borderRadius: BorderRadius.circular(T.rLg),
            border: Border.all(color: on ? s.accent.main : T.border, width: 1.5),
          ),
          child: Row(children: [
            IconSquare(me ? LucideIcons.user : LucideIcons.sprout,
                bg: me ? s.accent.bg : babyWash, fg: me ? s.accent.d : babyInk, size: 32, iconSize: 17, radius: 9),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: on ? s.accent.main : Colors.white,
                borderRadius: BorderRadius.circular(me ? 999 : 5),
                border: on ? null : Border.all(color: T.borderStrong, width: 1.5),
              ),
              child: on ? const Icon(LucideIcons.check, size: 13, color: Colors.white) : null,
            ),
          ]),
        ),
      ),
    );
  }
}
