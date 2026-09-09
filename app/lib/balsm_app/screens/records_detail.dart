import 'package:core/core.dart' show currentUserIdProvider, userFileStoreProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:records/records.dart';
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/badges.dart';
import 'records_screen.dart';
import '../vault/vault_blob.dart';
import '../widgets/date_time_row.dart';
import '../widgets/photo_attach.dart';

/// One vault entry in full — metadata, preview, result note, tags, source.
class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({super.key, required this.record});
  final RecordDocument record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final r = s.strings.records;
    final style = recordTypeStyle(record.type);

    final meta = <String>[
      formatRecordDate(record.takenAt, s),
      if (record.fileType != null && record.fileType!.isNotEmpty) record.fileType!,
      if ((record.pages ?? 0) > 1) '${record.pages} ${s.strings.common.pages}',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: ContentColumn(
        maxWidth: 720,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PadTop(),
          AppBarRow(children: [
            RoundBtn(icon: backArrow(context), onTap: () => Navigator.of(context).pop()),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(T.rPill)),
              child: Text(recordTypeLabelOne(s, record.type),
                  style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: style.fg)),
            ),
          ]),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(record.title, style: Typo.heading(ar: s.rtl)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(LucideIcons.calendar, size: 13, color: T.fg3),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(meta.join('  ·  '),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: Typo.meta(ar: s.rtl)),
                    ),
                  ]),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _DocPreview(type: record.type, filePath: record.filePath),
              ),
              if (record.resultNote != null && record.resultNote!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _ResultCallout(note: record.resultNote!, color: style.fg),
                ),
              if (record.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final tag in record.tags) _TagChip(tag)],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _StorageRow(s: s, record: record),
              ),
              RowHead(r.rec_source, ar: s.rtl),
              PCard(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: T.ink100, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.user, size: 20, color: T.fg2),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(record.source.isSelf ? r.rec_self : record.source.value,
                        style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(children: [
                  PButton(r.rec_view,
                      icon: LucideIcons.eye,
                      large: true,
                      block: true,
                      accent: s.accent,
                      ar: s.rtl,
                      onTap: _canViewRecord(record)
                          ? () => Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _VaultImageViewer(path: record.filePath!),
                                ),
                              )
                          : null),
                  const SizedBox(height: 10),
                  PButton(r.rec_share,
                      icon: LucideIcons.share2, variant: BtnVariant.secondary, block: true, ar: s.rtl, onTap: null),
                ]),
              ),
              const SizedBox(height: 28),
            ]),
          ),
        ]),
      ),
    );
  }
}

bool _canViewRecord(RecordDocument record) {
  final path = record.filePath;
  if (path == null || path.isEmpty) return false;
  final type = (record.fileType ?? '').toLowerCase();
  if (type == 'image' || type.startsWith('image/')) return true;
  final lower = path.toLowerCase();
  return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp');
}

/// Full-screen decrypt-in-memory viewer. Bytes stay on-device; never logged.
class _VaultImageViewer extends StatelessWidget {
  const _VaultImageViewer({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: VaultImage(
              path: path,
              height: MediaQuery.sizeOf(context).height,
              fit: BoxFit.contain,
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 12,
          child: RoundBtn(icon: LucideIcons.x, onTap: () => Navigator.of(context).pop()),
        ),
      ]),
    );
  }
}

/// Document plate — vault images render in-place; other types show a type placeholder.
class _DocPreview extends StatelessWidget {
  const _DocPreview({required this.type, this.filePath});
  final RecordType type;
  final String? filePath;

  @override
  Widget build(BuildContext context) {
    if (filePath != null && filePath!.isNotEmpty) {
      return VaultImage(path: filePath!, height: 200);
    }
    final s = AppScope.of(context);
    final style = recordTypeStyle(type);
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: T.cream100,
        borderRadius: BorderRadius.circular(T.rLg),
        border: Border.all(color: T.ink100),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(T.rMd)),
          child: Icon(style.icon, size: 28, color: style.fg),
        ),
        const SizedBox(height: 10),
        Text(s.strings.records.rec_preview, style: Typo.meta(ar: s.rtl)),
      ]),
    );
  }
}

/// Key-result strip — a 3px accent rule on the leading edge.
class _ResultCallout extends StatelessWidget {
  const _ResultCallout({required this.note, required this.color});
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(T.rLg),
        border: Border.all(color: T.border),
        boxShadow: T.shadowSm,
      ),
      child: Row(children: [
        Container(width: 3, height: 34, color: color),
        const SizedBox(width: 12),
        Icon(LucideIcons.sparkles, size: 17, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(note, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
        ),
      ]),
    );
  }
}

/// Where this record's backup lives. Backup target is an app-wide setting —
/// records follow it as a set — so the row reports the real target and taps
/// through to the storage sheet rather than pretending to be per-record.
class _StorageRow extends StatelessWidget {
  const _StorageRow({required this.s, required this.record});
  final PatientAppState s;
  final RecordDocument record;

  @override
  Widget build(BuildContext context) {
    final target = s.storageProvider;
    final c = storageCfg(target);
    return Pressable(
      // records.jsx opens the per-record manage sheet here, not the global
      // Storage & sync sheet — this row is about *this* record's copy.
      onTap: () => showManageRecordStorage(context, record: record),
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(T.rLg),
          border: Border.all(color: c.border, width: 1.5),
        ),
        child: Row(children: [
          Icon(c.icon, size: 18, color: c.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: target.isLocal ? s.strings.storage.store_local_only : s.strings.storage.store_backed,
                      style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                  TextSpan(
                      text: '  · ${target.label(s.strings.storage)}',
                      style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(LucideIcons.settings2, size: 11, color: T.fg3),
                const SizedBox(width: 5),
                Text(s.strings.storage.store_manage, style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          StorageBadge(storage: target),
        ]),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      height: 28,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(T.rPill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.tag, size: 12, color: s.accent.d),
        const SizedBox(width: 5),
        Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: s.accent.d)),
      ]),
    );
  }
}

/// Per-record storage sheet (records.jsx `ManageStorageSheet`).
///
/// The design's cloud actions (back up / move / remove from cloud / remove from
/// device) are all gated on a connected cloud provider. Cloud backup is off —
/// every record lives on-device only — so the sheet reduces to what the design
/// shows in that state: the current-location card, the local-only notice, and
/// the destructive delete. Restore the cloud rows alongside a real backend.
Future<void> showManageRecordStorage(
  BuildContext context, {
  required RecordDocument record,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x5C14202B),
      builder: (_) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _ManageStorageSheet(record: record),
        ),
      ),
    );

class _ManageStorageSheet extends ConsumerStatefulWidget {
  const _ManageStorageSheet({required this.record});
  final RecordDocument record;

  @override
  ConsumerState<_ManageStorageSheet> createState() => _ManageStorageSheetState();
}

class _ManageStorageSheetState extends ConsumerState<_ManageStorageSheet> {
  bool confirming = false;
  bool deleting = false;

  /// Removes the row and its encrypted attachment. Both are PHI: the blob is
  /// dropped first so a failed row delete can never orphan a readable file.
  Future<void> _delete() async {
    if (deleting) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => deleting = true);
    final record = widget.record;
    final path = record.filePath;
    try {
      if (path != null && path.isNotEmpty) {
        await ref.read(userFileStoreProvider).delete(path, scope: userId);
      }
      await ref.read(recordsDataSourceProvider).delete(record.id, scope: userId);
    } catch (_) {
      if (mounted) setState(() => deleting = false);
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final label = AppScope.of(context).strings.storage.store_deleted_rec;
    Navigator.of(context).pop(); // sheet
    Navigator.of(context).pop(); // detail screen — the record is gone
    messenger.showSnackBar(SnackBar(content: Text(label)));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final st = s.strings.storage;
    final target = s.storageProvider;
    final cfg = storageCfg(target);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration:
          const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(children: [
            Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink100))),
              child: Row(children: [
                Icon(cfg.icon, size: 19, color: cfg.color),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(confirming ? st.store_delete_rec : st.store_manage,
                        style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700))),
                RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 17, onTap: () => Navigator.pop(context)),
              ]),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, sheetBottomInset(context, base: 36)),
            child: confirming ? _confirm(s) : _actions(s),
          ),
        ),
      ]),
    );
  }

  Widget _actions(PatientAppState s) {
    final st = s.strings.storage;
    final target = s.storageProvider;
    final cfg = storageCfg(target);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Current location — `.b-badge` row over the provider's tinted card.
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: cfg.bg,
          borderRadius: BorderRadius.circular(T.rLg),
          border: Border.all(color: cfg.border),
        ),
        child: Row(children: [
          Icon(cfg.icon, size: 16, color: cfg.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: target.isLocal ? st.store_local_only : st.store_backed,
                    style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                TextSpan(text: '  · ${target.label(st)}', style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          StorageBadge(storage: target),
        ]),
      ),
      const SizedBox(height: 16),
      // Design's "no clouds connected" hint — the same copy the storage sheet
      // shows, so the two never disagree about what backup is available.
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rLg)),
        child: Row(children: [
          const Icon(LucideIcons.info, size: 16, color: T.fg3),
          const SizedBox(width: 10),
          Expanded(child: Text(st.store_choose_help, style: Typo.meta(ar: s.rtl).copyWith(height: 1.4))),
        ]),
      ),
      const SizedBox(height: 10),
      PButton(st.store_delete_rec,
          icon: LucideIcons.trash2,
          variant: BtnVariant.danger,
          block: true,
          ar: s.rtl,
          onTap: () => setState(() => confirming = true)),
    ]);
  }

  Widget _confirm(PatientAppState s) {
    final st = s.strings.storage;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(st.store_delete_rec_h, style: Typo.meta(ar: s.rtl).copyWith(height: 1.5)),
      const SizedBox(height: 16),
      PButton(st.store_delete_rec,
          variant: BtnVariant.danger, large: true, block: true, ar: s.rtl, onTap: deleting ? null : _delete),
      const SizedBox(height: 10),
      PButton(s.strings.common.cancel,
          variant: BtnVariant.secondary,
          block: true,
          ar: s.rtl,
          onTap: deleting ? null : () => setState(() => confirming = false)),
    ]);
  }
}

/// Add-record bottom sheet: pick a type, then fill in the metadata.
Future<void> showAddRecord(BuildContext context, {RecordType? initialType}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _AddRecordSheet(initialType: initialType),
        ),
      ),
    );

class _AddRecordSheet extends ConsumerStatefulWidget {
  const _AddRecordSheet({this.initialType});
  final RecordType? initialType;

  @override
  ConsumerState<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends ConsumerState<_AddRecordSheet> {
  RecordType? _type;
  final _title = TextEditingController();
  final _tagDraft = TextEditingController();
  final _tags = <String>[];
  late DateTime _date;
  PickedAttach? _attach;
  bool _saving = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose();
    _tagDraft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _type == null || _saving) return;
    setState(() => _saving = true);
    final s = AppScope.of(context);
    final now = DateTime.now();
    final id = RecordDocumentId.value('rec-${now.microsecondsSinceEpoch}');
    String? filePath;
    String? fileType;
    if (_attach?.bytes != null) {
      final ext = _attach!.kind == 'pdf' ? 'pdf' : 'jpg';
      filePath = await saveVaultBytes(ref, fileName: '${id.value}.$ext', bytes: _attach!.bytes!);
      fileType = _attach!.kind == 'pdf' ? 'PDF' : 'Image';
    }
    final doc = RecordDocument(
      id: id,
      userId: userId,
      type: _type!,
      title: _title.text.trim().isEmpty ? recordTypeLabelOne(s, _type!) : _title.text.trim(),
      tags: List.unmodifiable(_tags),
      fileType: fileType,
      filePath: filePath,
      takenAt: _date,
      createdAt: now,
    );
    await ref.read(recordsDataSourceProvider).put(id, doc);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _done = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = s.strings.records;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            if (_type != null && widget.initialType == null)
              RoundBtn(icon: backArrow(context), ghost: true, iconSize: 18, onTap: () => setState(() => _type = null)),
            Expanded(
              child: Text(
                  _done
                      ? ''
                      : _type == null
                          ? r.rec_pick_type
                          : recordTypeLabelOne(s, _type!),
                  style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
            ),
            RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 18, onTap: () => Navigator.of(context).pop()),
          ]),
        ),
        const Divider(height: 1, color: T.ink100),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, sheetBottomInset(context, base: 36)),
            child: _done
                ? _RecordAdded(s: s)
                : _type == null
                    ? _typePicker(s)
                    : _form(s),
          ),
        ),
      ]),
    );
  }

  Widget _typePicker(PatientAppState s) => Column(
        children: [
          for (final type in RecordType.values) ...[
            _TypeRow(type: type, onTap: () => setState(() => _type = type)),
            const SizedBox(height: 12),
          ],
        ],
      );

  Widget _form(PatientAppState s) {
    final r = s.strings.records;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Field(label: r.rec_title, child: _input(s, _title, r.rec_title_ph)),
      const SizedBox(height: 18),
      DateTimeWhen(when: _date, onChanged: (v) => setState(() => _date = v)),
      const SizedBox(height: 18),
      _Field(
        label: r.rec_tags,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_tags.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in _tags) _RemovableTag(label: tag, onRemove: () => setState(() => _tags.remove(tag))),
              ],
            ),
            const SizedBox(height: 8),
          ],
          _input(s, _tagDraft, r.rec_tags_ph, onSubmitted: (v) {
            final t = v.trim();
            if (t.isEmpty || _tags.contains(t)) return;
            setState(() {
              _tags.add(t);
              _tagDraft.clear();
            });
          }),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in _suggestedTags(s, _type!))
                if (!_tags.contains(tag))
                  GestureDetector(
                    onTap: () => setState(() => _tags.add(tag)),
                    // Suggestion chips are **dashed** in the design — the
                    // dashed outline is what distinguishes "tap to add" from
                    // the solid, already-applied tags.
                    child: DashedBorder(
                      color: T.borderStrong,
                      strokeWidth: 1.5,
                      radius: T.rPill,
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(T.rPill),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(LucideIcons.plus, size: 13, color: T.fg3),
                          const SizedBox(width: 5),
                          Text(tag, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
                        ]),
                      ),
                    ),
                  ),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 18),
      Text(r.rec_attach, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
      const SizedBox(height: 8),
      UploadDropzone(
        attach: _attach,
        url: '',
        onAttach: (a) => setState(() => _attach = a),
        onUrl: (_) {},
        takePhotoLabel: r.rec_take_photo,
        fromFilesLabel: r.rec_from_files,
        help: r.rec_attach_h,
      ),
      const SizedBox(height: 24),
      PButton(s.strings.settings.add_record,
          large: true, block: true, accent: s.accent, ar: s.rtl, onTap: _type == null || _saving ? null : _save),
    ]);
  }

  List<String> _suggestedTags(PatientAppState s, RecordType type) {
    final r = s.strings.records;
    return switch (type) {
      RecordType.lab => [r.tag_diabetes, r.tag_cholesterol, r.tag_kidney, r.tag_thyroid],
      RecordType.scan => [r.tag_chest, r.tag_abdomen, r.tag_bone, r.tag_follow_up],
      RecordType.report => [r.tag_cardiology, r.tag_surgery, r.tag_follow_up, r.tag_referral],
    };
  }

  Widget _input(PatientAppState s, TextEditingController c, String hint, {ValueChanged<String>? onSubmitted}) =>
      TextField(
        controller: c,
        onSubmitted: onSubmitted,
        textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
        style: Typo.body(ar: s.rtl).copyWith(color: T.fg1, fontSize: FS.lg),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4, fontSize: FS.lg),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: _b(T.border),
          enabledBorder: _b(T.border),
          focusedBorder: _b(s.accent.main),
        ),
      );

  OutlineInputBorder _b(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: c, width: 1.5));
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type, required this.onTap});
  final RecordType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final style = recordTypeStyle(type);
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(T.rLg),
          border: Border.all(color: T.border, width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(T.rMd)),
            child: Icon(style.icon, size: 23, color: style.fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(recordTypeLabelOne(s, type),
                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
          ),
          Chevron(rtl: s.rtl),
        ]),
      ),
    );
  }
}

class _RecordAdded extends StatelessWidget {
  const _RecordAdded({required this.s});
  final PatientAppState s;

  @override
  Widget build(BuildContext context) {
    final r = s.strings.records;
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
        Text(r.rec_added, style: Typo.heading(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(r.rec_added_h, textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
      const SizedBox(height: 8),
      child,
    ]);
  }
}

class _RemovableTag extends StatelessWidget {
  const _RemovableTag({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      height: 30,
      padding: const EdgeInsetsDirectional.only(start: 12, end: 6),
      decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(T.rPill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: s.accent.d)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onRemove,
          child: Icon(LucideIcons.x, size: 13, color: s.accent.d),
        ),
      ]),
    );
  }
}
