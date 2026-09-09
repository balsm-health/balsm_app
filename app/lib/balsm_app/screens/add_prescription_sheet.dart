import 'package:core/core.dart' show currentUserIdProvider, userFileStoreProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:prescriptions/prescriptions.dart';
import '../app_state.dart';
import '../i18n/strings.i69n.dart';
import '../kit.dart';
import '../tokens.dart';
import '../widgets/date_time_row.dart';
import '../widgets/photo_attach.dart';

Future<void> showAddPrescription(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const AddPrescriptionSheet(),
        ),
      ),
    );

class AddPrescriptionSheet extends ConsumerStatefulWidget {
  const AddPrescriptionSheet({super.key});

  @override
  ConsumerState<AddPrescriptionSheet> createState() => _AddPrescriptionSheetState();
}

class _MedDraft {
  _MedDraft();
  final name = TextEditingController();
  final dose = TextEditingController();
  final desc = TextEditingController();
  final freqOther = TextEditingController();
  final durOther = TextEditingController();
  final freqN = TextEditingController(text: '2');
  final durN = TextEditingController();
  String freqType = 'once';
  String freqUnit = 'hours';
  String durType = 'ongoing';

  void dispose() {
    name.dispose();
    dose.dispose();
    desc.dispose();
    freqOther.dispose();
    durOther.dispose();
    freqN.dispose();
    durN.dispose();
  }
}

class _AddPrescriptionSheetState extends ConsumerState<AddPrescriptionSheet> {
  final _title = TextEditingController();
  final _doctor = TextEditingController();
  final _url = TextEditingController();
  final _meds = [_MedDraft()];
  DateTime _issued = DateTime.now();
  DateTime? _expiry;
  PickedAttach? _attach;
  bool _saving = false;
  bool _done = false;

  @override
  void dispose() {
    _title.dispose();
    _doctor.dispose();
    _url.dispose();
    for (final m in _meds) {
      m.dispose();
    }
    super.dispose();
  }

  bool get _ready {
    final hasFile = _attach != null || _url.text.trim().isNotEmpty;
    final hasMeds = _meds.any((m) => m.name.text.trim().isNotEmpty);
    return hasFile || hasMeds;
  }

  String _freqDisplay(MedsStrings m, _MedDraft d) {
    return switch (d.freqType) {
      'once' => m.freq_once,
      'per_day' => m.freq_n_per_day(d.freqN.text.isEmpty ? '1' : d.freqN.text),
      'every_x' =>
        '${m.freq_every} ${d.freqN.text.isEmpty ? '1' : d.freqN.text} ${d.freqUnit == 'days' ? m.unit_days : m.unit_hours}',
      _ => d.freqOther.text.trim().isEmpty ? m.freq_other : d.freqOther.text.trim(),
    };
  }

  String? _durDisplay(MedsStrings m, _MedDraft d) {
    return switch (d.durType) {
      'until_empty' => m.dur_until_empty,
      'ongoing' => null,
      'other' => d.durOther.text.trim().isEmpty ? null : d.durOther.text.trim(),
      'weeks' => d.durN.text.isEmpty ? null : '${d.durN.text} ${m.unit_weeks}',
      'months' => d.durN.text.isEmpty ? null : '${d.durN.text} ${m.unit_months}',
      _ => d.durN.text.isEmpty ? null : '${d.durN.text} ${m.unit_days}',
    };
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _saving || !_ready) return;
    setState(() => _saving = true);
    final s = AppScope.of(context);
    final m = s.strings.meds;
    final named = _meds.where((d) => d.name.text.trim().isNotEmpty).toList();
    final items = [
      for (final d in named)
        PrescribedItem(
          name: d.name.text.trim(),
          dose: [
            d.dose.text.trim(),
            _freqDisplay(m, d),
            _durDisplay(m, d),
          ].where((p) => p != null && p.isNotEmpty).join(' · '),
          notes: d.desc.text.trim().isEmpty ? null : d.desc.text.trim(),
        ),
    ];
    String? attachPath;
    String? attachKind;
    if (_attach?.bytes != null) {
      final id = 'rx-${DateTime.now().microsecondsSinceEpoch}';
      final ext = _attach!.kind == 'pdf' ? 'pdf' : 'jpg';
      attachPath = await ref.read(userFileStoreProvider).save('$id.$ext', _attach!.bytes!);
      attachKind = _attach!.kind;
    } else if (_url.text.trim().isNotEmpty) {
      attachPath = _url.text.trim();
      attachKind = 'url';
    }
    final title = _title.text.trim().isEmpty ? m.rx_default_title : _title.text.trim();
    final doctor = _doctor.text.trim();
    final id = PrescriptionId.value('rx-${DateTime.now().microsecondsSinceEpoch}');
    await ref.read(prescriptionsDataSourceProvider).put(
          id,
          Prescription(
            id: id,
            userId: userId,
            clinician: doctor.isEmpty ? title : doctor,
            title: title,
            source: 'self',
            attachmentPath: attachPath,
            attachmentKind: attachKind,
            items: items,
            issuedAt: _issued,
            validUntil: _expiry,
            createdAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _done = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final m = s.strings.meds;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(children: [
            if (!_done)
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999)),
                ),
              ),
            if (!_done) const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child:
                    Text(_done ? '' : m.rx_add, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
              ),
              RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 18, onTap: () => Navigator.pop(context)),
            ]),
          ]),
        ),
        const Divider(height: 1, color: T.ink100),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(14, 14, 14, sheetBottomInset(context, base: 36)),
            child: _done ? _Done(s: s, label: m.rx_added) : _form(s, m),
          ),
        ),
      ]),
    );
  }

  Widget _form(PatientAppState s, MedsStrings m) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionLabel(icon: LucideIcons.fileText, label: s.strings.common.details, accent: s.accent.main),
      _LabeledField(s: s, label: m.rx_name, controller: _title, hint: m.rx_name_ph),
      const SizedBox(height: 14),
      _LabeledField(
          s: s, label: m.rx_doctor_name, controller: _doctor, hint: m.rx_doctor_name_ph, icon: LucideIcons.stethoscope),
      DateTimeWhen(
        when: _issued,
        onChanged: (v) => setState(() => _issued = v),
        dateLabel: m.rx_date,
        lastDate: DateTime.now(),
        expiry: _expiry,
        onExpiryChanged: (v) => setState(() => _expiry = v),
        expiryLabel: m.rx_expiry,
      ),
      const SizedBox(height: 8),
      _SectionLabel(icon: LucideIcons.uploadCloud, label: m.rx_upload, accent: s.accent.main),
      UploadDropzone(
        attach: _attach,
        url: _url.text,
        onAttach: (a) => setState(() => _attach = a),
        onUrl: (v) => setState(() => _url.text = v),
        orPasteLabel: m.rx_or_paste_url,
        urlHint: m.rx_url_ph,
      ),
      const SizedBox(height: 18),
      _SectionLabel(icon: LucideIcons.pill, label: m.rx_manual, accent: s.accent.main),
      for (var i = 0; i < _meds.length; i++) ...[
        _MedCard(
          draft: _meds[i],
          canRemove: _meds.length > 1,
          onRemove: () => setState(() {
            _meds.removeAt(i).dispose();
          }),
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 10),
      ],
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: PButton(
          m.rx_add_med,
          icon: LucideIcons.plus,
          variant: BtnVariant.soft,
          size: BtnSize.sm,
          accent: s.accent,
          ar: s.rtl,
          onTap: () => setState(() => _meds.add(_MedDraft())),
        ),
      ),
      const SizedBox(height: 20),
      Opacity(
        opacity: _ready && !_saving ? 1 : 0.4,
        child: PButton(m.rx_add,
            large: true, block: true, accent: s.accent, ar: s.rtl, onTap: _ready && !_saving ? _save : null),
      ),
    ]);
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.s, required this.label});
  final PatientAppState s;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: T.petalMint50, shape: BoxShape.circle),
          child: const Icon(LucideIcons.check, size: 36, color: T.petalMint600),
        ),
        const SizedBox(height: 14),
        Text(label, style: Typo.heading(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label, required this.accent});
  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 15, color: accent),
        const SizedBox(width: 7),
        Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
      ]),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.s,
    required this.label,
    required this.controller,
    required this.hint,
    this.icon,
  });
  final PatientAppState s;
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: T.fg4),
          const SizedBox(width: 6),
        ],
        Text(label, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
      ]),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        onChanged: (_) => (context as Element).markNeedsBuild(),
        style: Typo.body(ar: s.rtl).copyWith(color: T.fg1, fontSize: FS.lg),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4, fontSize: FS.lg),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
        ),
      ),
    ]);
  }
}

class _MedCard extends StatelessWidget {
  const _MedCard({required this.draft, required this.canRemove, required this.onRemove, required this.onChanged});
  final _MedDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final m = s.strings.meds;
    return PCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _plain(s, draft.name, m.rx_med_name_ph, onChanged),
          const SizedBox(height: 12),
          _plain(s, draft.dose, m.rx_med_dose_ph, onChanged),
          const SizedBox(height: 12),
          _plain(s, draft.desc, m.rx_med_desc_ph, onChanged, lines: 2),
          const SizedBox(height: 12),
          Text(m.rx_frequency, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: _Select(
                value: draft.freqType,
                items: [
                  ('once', m.freq_once),
                  ('per_day', m.freq_per_day),
                  ('every_x', m.freq_every_x),
                  ('other', m.freq_other),
                ],
                onChanged: (v) {
                  draft.freqType = v;
                  onChanged();
                },
              ),
            ),
            if (draft.freqType == 'per_day' || draft.freqType == 'every_x') ...[
              const SizedBox(width: 8),
              SizedBox(width: 64, child: _plain(s, draft.freqN, '', onChanged, number: true)),
            ],
            if (draft.freqType == 'every_x') ...[
              const SizedBox(width: 8),
              Expanded(
                child: _Select(
                  value: draft.freqUnit,
                  items: [('hours', m.unit_hours), ('days', m.unit_days)],
                  onChanged: (v) {
                    draft.freqUnit = v;
                    onChanged();
                  },
                ),
              ),
            ],
          ]),
          if (draft.freqType == 'other') ...[
            const SizedBox(height: 8),
            _plain(s, draft.freqOther, m.freq_other_ph, onChanged),
          ],
          const SizedBox(height: 12),
          Text(m.rx_duration, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: _Select(
                value: draft.durType,
                items: [
                  ('days', m.dur_days),
                  ('weeks', m.dur_weeks),
                  ('months', m.dur_months),
                  ('until_empty', m.dur_until_empty),
                  ('ongoing', m.dur_ongoing),
                  ('other', m.dur_other),
                ],
                onChanged: (v) {
                  draft.durType = v;
                  onChanged();
                },
              ),
            ),
            if (draft.durType == 'days' || draft.durType == 'weeks' || draft.durType == 'months') ...[
              const SizedBox(width: 8),
              SizedBox(width: 64, child: _plain(s, draft.durN, '', onChanged, number: true)),
            ],
          ]),
          if (draft.durType == 'other') ...[
            const SizedBox(height: 8),
            _plain(s, draft.durOther, m.dur_other_ph, onChanged),
          ],
        ]),
        if (canRemove)
          PositionedDirectional(
            top: 0,
            end: 0,
            child: Material(
              color: T.ink50,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const SizedBox(width: 26, height: 26, child: Icon(LucideIcons.x, size: 13, color: T.fg3)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _plain(
    PatientAppState s,
    TextEditingController c,
    String hint,
    VoidCallback onChanged, {
    int lines = 1,
    bool number = false,
  }) {
    return TextField(
      controller: c,
      minLines: lines,
      maxLines: lines,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      textAlign: number ? TextAlign.center : TextAlign.start,
      onChanged: (_) => onChanged(),
      style: Typo.body(ar: s.rtl).copyWith(color: T.fg1, fontSize: FS.lg),
      decoration: InputDecoration(
        hintText: hint.isEmpty ? null : hint,
        hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4, fontSize: FS.lg),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
      ),
    );
  }
}

class _Select extends StatelessWidget {
  const _Select({required this.value, required this.items, required this.onChanged});
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(LucideIcons.chevronDown, size: 15, color: T.fg3),
          style: Typo.body(ar: s.rtl).copyWith(color: T.fg1),
          items: [
            for (final (v, label) in items)
              DropdownMenuItem(value: v, child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
