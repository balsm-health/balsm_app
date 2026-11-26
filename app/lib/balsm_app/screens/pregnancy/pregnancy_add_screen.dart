import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pregnancy/pregnancy.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../widgets/photo_attach.dart';
import '../family/family_kit.dart';
import 'pregnancy_drafts.dart';
import 'pregnancy_kit.dart';

/// Opens the attach flow, preselecting [babyIds] (from a baby's screen).
Future<void> openPregnancyAdd(
  BuildContext context, {
  List<HealthProfileId> babyIds = const [],
  HealthProfileId? mother,
}) =>
    pushFamilyScreen<void>(context, (_) => PregnancyAddScreen(babyIds: babyIds, mother: mother));

/// Attach a pregnancy record (mother-child.jsx `MCPregAddScreen`): about me,
/// one baby or several (a shared report); a scan, measurements (one baby at a
/// time) or a test/document. The file is stored encrypted on this phone.
class PregnancyAddScreen extends ConsumerStatefulWidget {
  const PregnancyAddScreen({super.key, this.babyIds = const [], this.mother});
  final List<HealthProfileId> babyIds;

  /// Whose pregnancy (null = the account holder's own).
  final HealthProfileId? mother;
  @override
  ConsumerState<PregnancyAddScreen> createState() => _PregnancyAddScreenState();
}

class _PregnancyAddScreenState extends ConsumerState<PregnancyAddScreen> {
  late final PregnancyItemDraftKey _key = (form: Object(), babyIds: widget.babyIds);
  final _title = TextEditingController();
  final _hr = TextEditingController();
  final _efw = TextEditingController();
  final _otherLabel = TextEditingController();
  final _otherValue = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _hr, _efw, _otherLabel, _otherValue]) {
      c.dispose();
    }
    super.dispose();
  }

  PregnancyItemDraftNotifier get _notifier => ref.read(pregnancyItemDraftProvider(_key).notifier);

  static int? _int(String s) => int.tryParse(s.trim());

  /// The form as the domain sees it; its rules decide whether Save is on.
  AppResult<PregnancyItem> _asItem(Pregnancy preg, PregnancyItemDraft d) => PregnancyItem.create(
        id: const PregnancyItemId.value('draft'),
        pregnancyId: preg.id,
        about: d.me ? ItemAbout.me : ItemAbout.baby,
        babyIds: d.me ? const [] : d.babies.toList(),
        kind: d.effectiveKind,
        recordedOn: d.date,
        now: DateTime.now(),
        title: _title.text,
        fetalHeartRateBpm: _int(_hr.text),
        estimatedFetalWeightG: _int(_efw.text),
        otherLabel: _otherLabel.text,
        otherValue: _otherValue.text,
        attachmentRef: d.file == null ? null : 'picked',
      );

  bool _numbersParse() =>
      (_hr.text.trim().isEmpty || _int(_hr.text) != null) && (_efw.text.trim().isEmpty || _int(_efw.text) != null);

  Future<void> _pickFile() async {
    final picked = await pickAttachment(context);
    if (picked == null || picked.bytes == null || !mounted) return;
    _notifier.attach(picked);
  }

  Future<void> _save(Pregnancy preg) async {
    if (_saving) return;
    setState(() => _saving = true);
    final d = ref.read(pregnancyItemDraftProvider(_key));
    final kind = d.effectiveKind;
    String? ref0;
    try {
      final f = d.file;
      if (f != null && kind != ItemKind.measure) {
        // pickAttachment only hands over a file with its bytes (see _pickFile).
        ref0 = await ref.read(userFileStoreProvider).save(f.name ?? 'pregnancy-record', f.bytes!);
      }
    } on Object catch (_) {
      ref0 = null;
    }
    if (!mounted) return;
    if (d.file != null && ref0 == null && kind != ItemKind.measure) return _fail();
    final r = await ref.read(pregnancyRecordsUseCaseProvider).addItem(
          pregnancyId: preg.id,
          motherId: preg.motherId,
          about: d.me ? ItemAbout.me : ItemAbout.baby,
          babyIds: d.me ? const [] : d.babies.toList(),
          kind: kind,
          recordedOn: d.date,
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

  Future<void> _pickDate(DateTime current) async {
    final p = AppScope.of(context).strings.pregnancy;
    final now = DateTime.now();
    final picked = await pickDay(
      context,
      title: p.date,
      initial: current,
      first: now.subtract(const Duration(days: 400)),
      last: now,
    );
    if (picked != null && mounted) _notifier.setDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final preg = ref.watch(activePregnancyOfProvider(widget.mother));
    final owner = pregnancyOwner(ref, widget.mother);
    if (preg == null) return const Scaffold(backgroundColor: AppColors.white);
    final all = ref.watch(pregnancyBabiesProvider(preg.id)).value ?? const <PregnancyBaby>[];
    final active = all.where((b) => b.isActive).toList();
    final d = ref.watch(pregnancyItemDraftProvider(_key));
    final kinds = d.canMeasure ? ItemKind.values : const [ItemKind.scan, ItemKind.doc];
    final kind = d.effectiveKind;
    final ok = d.chosen && _numbersParse() && _asItem(preg, d).isSuccess;
    final allOn = active.length > 1 && active.every((b) => d.babies.contains(b.id));

    return FamilyScaffold(
      title: p.attach_t,
      footer: PButton(
        s.strings.family.save,
        large: true,
        block: true,
        accent: s.accent,
        ar: s.rtl,
        onTap: ok && !_saving ? () => _save(preg) : null,
      ),
      children: [
        LabelledField(
          label: p.who,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WhoOption(
                me: true,
                label: owner == null ? p.me : p.me_of(owner.shortName),
                on: d.me,
                onTap: () => _notifier.toggleMe(),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, c) {
                  const gap = 8.0;
                  final w = active.length > 1 ? (c.maxWidth - gap) / 2 : c.maxWidth;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: active
                        .map(
                          (b) => SizedBox(
                            width: w,
                            child: _WhoOption(
                              label: babyLabel(s, b, all),
                              on: d.babies.contains(b.id),
                              onTap: () => _notifier.toggleBaby(b.id),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              if (active.length > 1)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => _notifier.toggleAll(active.map((b) => b.id)),
                    child: Text(
                      allOn ? p.clear_babies : p.all_babies,
                      style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: s.accent.d),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (d.chosen) ...[
          LabelledField(
            label: p.type,
            help: !d.me && d.babies.length > 1 ? p.one_at_a_time : null,
            child: BalsmSegmented<ItemKind>(
              options: kinds,
              labelOf: (k) => itemKindLabel(s, k),
              selected: kind,
              onChanged: (k) => _notifier.setKind(k),
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
            child: DayField(value: d.date, placeholder: p.pick_date, onTap: () => _pickDate(d.date)),
          ),
          if (kind == ItemKind.measure)
            _MeasureFields(
              hr: _hr,
              efw: _efw,
              otherLabel: _otherLabel,
              otherValue: _otherValue,
              onChanged: () => setState(() {}),
            )
          else
            _FileField(file: d.file, onTap: _pickFile),
        ],
      ],
    );
  }
}

/// A scan's measurements, as written on the report.
class _MeasureFields extends StatelessWidget {
  const _MeasureFields({
    required this.hr,
    required this.efw,
    required this.otherLabel,
    required this.otherValue,
    required this.onChanged,
  });
  final TextEditingController hr;
  final TextEditingController efw;
  final TextEditingController otherLabel;
  final TextEditingController otherValue;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MeasureField(label: p.hr_field, controller: hr, number: true, onChanged: onChanged),
            const SizedBox(width: 10),
            _MeasureField(label: p.efw_field, controller: efw, number: true, onChanged: onChanged),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MeasureField(label: p.other_field, controller: otherLabel, hint: p.other_ph, onChanged: onChanged),
            const SizedBox(width: 10),
            _MeasureField(label: p.value, controller: otherValue, hint: p.value_ph, onChanged: onChanged),
          ],
        ),
        Text(p.as_written, style: Typo.meta(ar: s.rtl)),
      ],
    );
  }
}

class _MeasureField extends StatelessWidget {
  const _MeasureField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.number = false,
  });
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? hint;
  final bool number;

  @override
  Widget build(BuildContext context) => Expanded(
        child: LabelledField(
          label: label,
          child: TextField(
            controller: controller,
            keyboardType: number ? TextInputType.number : TextInputType.text,
            maxLength: PregnancyItem.maxOtherLength,
            onChanged: (_) => onChanged(),
            decoration: fieldDecoration(AppScope.of(context), hint).copyWith(counterText: ''),
          ),
        ),
      );
}

/// The scan or document to attach; stored encrypted on this phone.
class _FileField extends StatelessWidget {
  const _FileField({required this.file, required this.onTap});
  final PickedAttach? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final f = file;
    return LabelledField(
      label: p.file,
      child: Semantics(
        button: true,
        child: PCard(
          flat: true,
          onTap: onTap,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              IconSquare(
                f == null ? LucideIcons.camera : LucideIcons.paperclip,
                bg: AppColors.ink50,
                fg: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f == null ? p.file_pick : (f.name ?? p.file_attached),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    Text(p.file_local, style: Typo.meta(ar: s.rtl)),
                  ],
                ),
              ),
            ],
          ),
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
            color: on ? s.accent.bg : AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: on ? s.accent.main : AppColors.border, width: 1.5),
          ),
          child: Row(
            children: [
              IconSquare(
                me ? LucideIcons.user : LucideIcons.sprout,
                bg: me ? s.accent.bg : babyWash,
                fg: me ? s.accent.d : babyInk,
                size: 32,
                iconSize: 17,
                radius: 9,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: on ? s.accent.main : AppColors.white,
                  borderRadius: BorderRadius.circular(me ? 999 : 5),
                  border: on ? null : Border.all(color: AppColors.borderStrong, width: 1.5),
                ),
                child: on ? const Icon(LucideIcons.check, size: 13, color: AppColors.white) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
