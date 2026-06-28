import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../data.dart';
import '../kit.dart';
import '../tokens.dart';
import '../widgets/badges.dart';
import '../widgets/balsm_flower.dart';

/// Health records vault (records.jsx) — list + filters + add + detail.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<HealthRecord> records = List.of(kHealthRecords);
  String filter = 'all';
  HealthRecord? selected;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (selected != null) {
      return _RecordDetail(
        rec: selected!,
        onBack: () => setState(() => selected = null),
        onStorageChange: (st) => setState(() {
          records = [for (final r in records) r.id == selected!.id ? r.copyWith(storage: st) : r];
          selected = selected!.copyWith(storage: st);
        }),
        onDelete: () => setState(() { records = records.where((r) => r.id != selected!.id).toList(); selected = null; }),
      );
    }
    final shown = filter == 'all' ? records : records.where((r) => r.type == filter).toList();
    return Column(children: [
      const PadTop(),
      AppBarRow(
        leading: RoundBtn(icon: LucideIcons.arrowLeft, onTap: () => s.setTab('home')),
        children: [
          Expanded(child: Text(s.t('records'), style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl))),
          GestureDetector(
            onTap: () => _showAdd(s),
            child: Container(
              height: 40, padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(T.rMd)),
              child: Row(children: [Icon(LucideIcons.plus, size: 16, color: s.accent.d), const SizedBox(width: 6), Text(s.t('add_record'), style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: s.accent.d))]),
            ),
          ),
        ],
      ),
      SizedBox(
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            for (final f in const ['all', 'lab', 'scan', 'report'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Filter(
                  label: f == 'all' ? s.t('all_records') : s.t(kRecordTypes[f]!.labelKey),
                  active: filter == f, accent: s.accent, ar: s.rtl,
                  onTap: () => setState(() => filter = f),
                ),
              ),
          ],
        ),
      ),
      Expanded(child: shown.isEmpty
          ? ListView(children: [Padding(padding: const EdgeInsets.all(20), child: _empty(s))])
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [for (final r in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: _RecordCard(rec: r, onTap: () => setState(() => selected = r)))],
            )),
    ]);
  }

  Widget _empty(PatientAppState s) => PCard(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 36),
        child: Column(children: [
          const Icon(LucideIcons.folderOpen, size: 36, color: T.fg4),
          const SizedBox(height: 14),
          Text(s.t('rec_empty'), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2)),
          const SizedBox(height: 8),
          Text(s.t('rec_empty_h'), textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
        ]),
      );

  void _showAdd(PatientAppState s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5C2B2B25),
      builder: (ctx) => Directionality(textDirection: s.dir, child: _AddRecordSheet(onAdd: (r) => setState(() => records = [r, ...records]))),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.active, required this.accent, required this.ar, required this.onTap});
  final String label;
  final bool active;
  final Accent accent;
  final bool ar;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: active ? accent.bg : Colors.white,
            borderRadius: BorderRadius.circular(T.rPill),
            border: Border.all(color: active ? accent.main : T.border, width: 1.5),
          ),
          child: Text(label, style: Typo.bodySm(ar: ar).copyWith(fontWeight: FontWeight.w600, color: active ? accent.d : T.fg2)),
        ),
      );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.rec, required this.onTap});
  final HealthRecord rec;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cfg = kRecordTypes[rec.type]!;
    final doc = rec.sourceId == 'self' ? null : doctorById(rec.sourceId);
    return PCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(children: [
        IconSquare(cfg.icon, bg: cfg.bg, fg: cfg.color, size: 46, iconSize: 22),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rec.title.of(s.lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
          Text('${rec.date.of(s.lang)} · ${doc?.name.of(s.lang) ?? s.t('rec_self')}', style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
        ])),
        const SizedBox(width: 8),
        StorageBadge(storage: rec.storage),
        const SizedBox(width: 8),
        Chevron(rtl: s.rtl),
      ]),
    );
  }
}

// ── Detail ───────────────────────────────────────────────────
class _RecordDetail extends StatelessWidget {
  const _RecordDetail({required this.rec, required this.onBack, required this.onStorageChange, required this.onDelete});
  final HealthRecord rec;
  final VoidCallback onBack;
  final ValueChanged<String> onStorageChange;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final cfg = kRecordTypes[rec.type]!;
    final doc = rec.sourceId == 'self' ? null : doctorById(rec.sourceId);
    final st = storageCfg(rec.storage);
    return ListView(padding: EdgeInsets.zero, children: [
      const PadTop(),
      AppBarRow(
        leading: RoundBtn(icon: LucideIcons.arrowLeft, onTap: onBack),
        children: [const Spacer(), Pill(s.t(cfg.oneKey), kind: PillKind.neutral, dot: false, ar: s.rtl)],
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rec.title.of(s.lang), style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl)),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(LucideIcons.calendar, size: 13, color: T.fg3),
            const SizedBox(width: 7),
            Text(rec.date.of(s.lang), style: Typo.meta(ar: s.rtl)),
            Text('  ·  ', style: Typo.meta(ar: s.rtl).copyWith(color: T.ink300)),
            Text(rec.fileType, style: Typo.num(size: FS.xs, color: T.fg3)),
            if (rec.pages > 1) ...[Text('  ·  ', style: Typo.meta(ar: s.rtl).copyWith(color: T.ink300)), Text('${rec.pages} ${s.t('pages')}', style: Typo.meta(ar: s.rtl))],
          ]),
        ]),
      ),
      // Doc preview placeholder
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Container(
          height: 200,
          decoration: BoxDecoration(color: T.cream100, borderRadius: BorderRadius.circular(T.rLg), border: Border.all(color: T.ink100)),
          child: Stack(alignment: Alignment.center, children: [
            Positioned(right: -28, bottom: -28, child: BalsmFlower(size: 130, opacity: 0.07)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              IconSquare(cfg.icon, bg: cfg.bg, fg: cfg.color, size: 56, iconSize: 28),
              const SizedBox(height: 10),
              Text('Document preview', style: Typo.meta(ar: s.rtl)),
            ]),
          ]),
        ),
      ),
      if (rec.result != null)
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(T.rLg),
            border: Border.all(color: T.border), boxShadow: T.shadowSm,
            // left accent strip
          ),
          child: Row(children: [
            Container(width: 3, height: 28, color: cfg.color),
            const SizedBox(width: 12),
            Icon(LucideIcons.sparkles, size: 17, color: cfg.color),
            const SizedBox(width: 10),
            Expanded(child: Text(rec.result!.of(s.lang), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1))),
          ]),
        ),
      // Storage row (tap to manage)
      GestureDetector(
        onTap: () => _showManageStorage(context, rec, onStorageChange, onDelete),
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(T.rLg), border: Border.all(color: st.border, width: 1.5)),
          child: Row(children: [
            Icon(st.icon, size: 18, color: st.color),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(rec.storage == 'local' ? s.t('store_local_only') : s.t('store_backed'), style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
              Row(children: [Text(st.label.of(s.lang), style: Typo.meta(ar: s.rtl)), Text('  ·  ', style: Typo.meta(ar: s.rtl).copyWith(color: T.ink300)), const Icon(LucideIcons.settings2, size: 11, color: T.fg3), const SizedBox(width: 4), Text(s.t('store_manage'), style: Typo.meta(ar: s.rtl))]),
            ])),
            StorageBadge(storage: rec.storage),
          ]),
        ),
      ),
      RowHead(s.t('rec_source'), ar: s.rtl),
      PCard(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(children: [
          if (doc != null) DoctorAvatar(doctor: doc, size: 42)
          else Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: T.ink100, shape: BoxShape.circle), child: const Icon(LucideIcons.user, size: 20, color: T.fg2)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc?.name.of(s.lang) ?? s.t('rec_self'), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            if (doc != null) Text(doc.specialty.of(s.lang), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ])),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(children: [
          PButton(s.t('rec_view'), icon: LucideIcons.eye, variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: s.rtl),
          const SizedBox(height: 10),
          PButton(s.t('rec_share'), icon: LucideIcons.share2, variant: BtnVariant.secondary, block: true, ar: s.rtl),
        ]),
      ),
    ]);
  }
}

// ── Add record sheet ─────────────────────────────────────────
class _AddRecordSheet extends StatefulWidget {
  const _AddRecordSheet({required this.onAdd});
  final ValueChanged<HealthRecord> onAdd;
  @override
  State<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<_AddRecordSheet> {
  String step = 'type'; // type | form | done
  String? type;
  final title = TextEditingController();

  void _save() {
    final s = AppScope.of(context);
    widget.onAdd(HealthRecord(
      'r${DateTime.now().millisecondsSinceEpoch}', type!, 'local',
      {'en': title.text.isEmpty ? s.t(kRecordTypes[type]!.oneKey) : title.text, 'ar': title.text.isEmpty ? s.t(kRecordTypes[type]!.oneKey) : title.text},
      {'en': 'Today', 'ar': 'اليوم'}, 'self', 'PDF', 1, null));
    setState(() => step = 'done');
    Future.delayed(const Duration(milliseconds: 1600), () { if (mounted) Navigator.pop(context); });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(children: [
            if (step == 'type') Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
            Container(
              padding: const EdgeInsets.only(bottom: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink100))),
              child: Row(children: [
                if (step == 'form') RoundBtn(icon: LucideIcons.arrowLeft, ghost: true, iconSize: 18, onTap: () => setState(() => step = 'type')),
                Expanded(child: Padding(padding: const EdgeInsets.only(left: 4), child: Text(
                  step == 'done' ? '' : step == 'type' ? s.t('rec_pick_type') : s.t(kRecordTypes[type]!.oneKey),
                  style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)))),
                RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 18, onTap: () => Navigator.pop(context)),
              ]),
            ),
          ]),
        ),
        Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 36), child: _body(s))),
      ]),
    );
  }

  Widget _body(PatientAppState s) => switch (step) {
        'type' => Column(children: [
            for (final e in kRecordTypes.entries)
              GestureDetector(
                onTap: () => setState(() { type = e.key; step = 'form'; }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(T.rLg), border: Border.all(color: T.border, width: 1.5)),
                  child: Row(children: [
                    IconSquare(e.value.icon, bg: e.value.bg, fg: e.value.color, size: 46, iconSize: 23),
                    const SizedBox(width: 14),
                    Expanded(child: Text(s.t(e.value.oneKey), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1))),
                    Chevron(rtl: s.rtl),
                  ]),
                ),
              ),
          ]),
        'form' => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.t('rec_title'), style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
            const SizedBox(height: 8),
            TextField(
              controller: title, textDirection: s.dir,
              style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.lg, color: T.fg1),
              decoration: InputDecoration(
                hintText: s.t('rec_title_ph'), hintStyle: Typo.body(ar: s.rtl).copyWith(fontSize: FS.lg, color: T.fg4),
                filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.all(16),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.border, width: 1.5)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: s.accent.main, width: 1.5)),
              ),
            ),
            const SizedBox(height: 18),
            Text(s.t('rec_attach'), style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
              decoration: BoxDecoration(color: T.cream50, borderRadius: BorderRadius.circular(T.rMd), border: Border.all(color: T.borderStrong, width: 1.5)),
              child: Column(children: [
                const Icon(LucideIcons.uploadCloud, size: 30, color: T.fg3),
                const SizedBox(height: 12),
                Text(s.t('rec_attach_h'), textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  PButton(s.t('rec_take_photo'), icon: LucideIcons.camera, variant: BtnVariant.soft, accent: s.accent, ar: s.rtl),
                  const SizedBox(width: 10),
                  PButton(s.t('rec_from_files'), icon: LucideIcons.folder, variant: BtnVariant.secondary, ar: s.rtl),
                ]),
              ]),
            ),
            const SizedBox(height: 18),
            PButton(s.t('add_record'), variant: BtnVariant.primary, large: true, block: true, accent: s.accent, ar: s.rtl, onTap: _save),
          ]),
        _ => Column(children: [
            const SizedBox(height: 20),
            Container(width: 72, height: 72, alignment: Alignment.center, decoration: BoxDecoration(color: T.petalMint50, shape: BoxShape.circle), child: const Icon(LucideIcons.check, size: 36, color: T.petalMint600)),
            const SizedBox(height: 14),
            Text(s.t('rec_added'), style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl)),
            const SizedBox(height: 8),
            Text(s.t('rec_added_h'), textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
          ]),
      };
}

// ── Per-record storage management sheet (records.jsx ManageStorageSheet) ──
void _showManageStorage(BuildContext context, HealthRecord rec, ValueChanged<String> onChange, VoidCallback onDelete) {
  final s = AppScope.of(context);
  final isCloud = rec.storage == 'icloud' || rec.storage == 'gdrive';
  final clouds = const ['icloud', 'gdrive'];
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x5C2B2B25),
    builder: (ctx) {
      final cfg = storageCfg(rec.storage);
      Widget action(IconData icon, Color iconBg, Color iconColor, String label, {String? sub, required VoidCallback onTap, bool danger = false}) => GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 52, padding: const EdgeInsetsDirectional.only(start: 14, end: 14),
              decoration: BoxDecoration(
                color: danger ? T.dangerBg : (iconBg == s.accent.bg ? s.accent.bg : Colors.white),
                borderRadius: BorderRadius.circular(T.rMd),
                border: danger || iconBg == s.accent.bg ? null : Border.all(color: T.borderStrong),
              ),
              child: Row(children: [
                Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: danger ? const Color(0x1FD44A3C) : iconBg, borderRadius: BorderRadius.circular(T.rMd)), child: Icon(icon, size: 18, color: iconColor)),
                const SizedBox(width: 14),
                Expanded(child: Text.rich(TextSpan(children: [
                  TextSpan(text: label, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: danger ? T.danger : T.fg1)),
                  if (sub != null) TextSpan(text: '  · $sub', style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                ]))),
              ]),
            ),
          );

      void confirmDelete() {
        Navigator.pop(ctx);
        showDialog(context: context, builder: (dctx) => Directionality(textDirection: s.dir, child: AlertDialog(
          backgroundColor: Colors.white,
          title: Text(s.t('store_delete_rec'), style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
          content: Text(s.t('rec_added_h'), style: Typo.bodySm(ar: s.rtl)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx), child: Text(s.t('cancel'), style: TextStyle(color: T.fg2))),
            TextButton(onPressed: () { Navigator.pop(dctx); onDelete(); }, child: Text(s.t('store_delete_rec'), style: const TextStyle(color: T.danger, fontWeight: FontWeight.w700))),
          ],
        )));
      }

      return Directionality(
        textDirection: s.dir,
        child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
          padding: const EdgeInsets.only(bottom: 36),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(width: 38, height: 4, decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(children: [Icon(cfg.icon, size: 19, color: cfg.color), const SizedBox(width: 10), Expanded(child: Text(s.t('store_manage'), style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700))), RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 17, onTap: () => Navigator.pop(ctx))])),
            const Divider(height: 1, color: T.ink100),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                if (!isCloud)
                  for (final p in clouds)
                    action(storageCfg(p).icon, storageCfg(p).bg, storageCfg(p).color, '${s.t('store_backup_to')} ${storageCfg(p).label.of(s.lang)}', onTap: () { Navigator.pop(ctx); onChange(p); }),
                if (isCloud) ...[
                  for (final p in clouds.where((p) => p != rec.storage))
                    action(storageCfg(p).icon, storageCfg(p).bg, storageCfg(p).color, '${s.t('store_move_to')} ${storageCfg(p).label.of(s.lang)}', onTap: () { Navigator.pop(ctx); onChange(p); }),
                  action(LucideIcons.cloudOff, T.ink50, T.fg2, s.t('store_remove_cloud'), sub: s.rtl ? 'يبقى على الجهاز' : 'keep on device', onTap: () { Navigator.pop(ctx); onChange('local'); }),
                ],
                action(LucideIcons.trash2, const Color(0x1FD44A3C), T.danger, isCloud ? s.t('store_delete_all') : s.t('store_delete_rec'), danger: true, onTap: confirmDelete),
              ]),
            ),
          ]),
        ),
      );
    },
  );
}
