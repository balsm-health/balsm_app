import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:records/records.dart';

import '../app_state.dart';
import '../kit.dart';
import '../maintenance/maintenance_guard.dart';
import '../responsive.dart';
import '../vault/vault_blob.dart';
import '../widgets/attachment_thumb.dart';
import '../widgets/badges.dart';
import '../widgets/date_time_row.dart';
import '../widgets/entry_attribution.dart';
import '../widgets/photo_attach.dart';
import '../widgets/vault_file_viewer.dart';
import 'record_draft.dart';
import 'records_screen.dart';

/// One record, live from the active profile's vault — so an edit saved from
/// the detail screen shows there at once. Null when the record is gone.
final StreamProviderFamily<RecordDocument?, RecordDocumentId> recordDocumentProvider =
    StreamProvider.autoDispose.family<RecordDocument?, RecordDocumentId>((ref, id) {
  final profileId = ref.watch(currentProfileIdProvider);
  if (profileId == null) return Stream.value(null);
  return ref.watch(recordsDataSourceProvider).watch(id, scope: profileId);
});

/// One vault entry in full — metadata, preview, result note, tags, source.
class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({required this.record, super.key});

  /// The record as the list showed it; the screen follows the stored row from
  /// there, falling back to this while it loads.
  final RecordDocument record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(recordDocumentProvider(this.record.id)).value ?? this.record;
    final s = AppScope.of(context);
    final r = s.strings.records;
    final style = recordTypeStyle(record.type);

    final meta = <String>[
      formatRecordDate(record.takenAt, s),
      // fileType is stored ('PDF' / 'Image'); the image kind is shown in the
      // UI language, PDF reads the same everywhere.
      if (record.fileType case final fileType? when record.fileType!.isNotEmpty)
        if (fileType.toLowerCase() == 'image') s.strings.records.rec_kind_image else fileType,
      if ((record.pages ?? 0) > 1) '${record.pages} ${s.strings.common.pages}',
    ];

    return Scaffold(
      backgroundColor: AppColors.white,
      body: ContentColumn(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PadTop(),
            AppBarRow(
              children: [
                RoundBtn(
                  icon: backArrow(context),
                  semanticLabel: s.strings.common.a11y_back,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
                  child: Text(
                    recordTypeLabelOne(s, record.type),
                    style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: style.fg),
                  ),
                ),
                const SizedBox(width: 10),
                RoundBtn(
                  icon: LucideIcons.pencil,
                  semanticLabel: s.strings.common.a11y_edit,
                  iconSize: 18,
                  onTap: () => showAddRecord(context, initial: record),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.title, style: Typo.heading(ar: s.rtl)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(LucideIcons.calendar, size: 13, color: AppColors.textTertiary),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                meta.join('  ·  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Typo.meta(ar: s.rtl),
                              ),
                            ),
                          ],
                        ),
                        if (record.history.isAttributed)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(top: 8),
                            child: EntryAttributionChip(history: record.history),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
                    child: GestureDetector(
                      onTap: _canViewRecord(record)
                          ? () => VaultFileViewer.open(context, path: record.filePath!, title: record.title)
                          : null,
                      child: _DocPreview(type: record.type, filePath: record.filePath, isPdf: _isPdfRecord(record)),
                    ),
                  ),
                  if (record.resultNote case final resultNote? when record.resultNote!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
                      child: _ResultCallout(note: resultNote, color: style.fg),
                    ),
                  if (record.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final tag in record.tags) _TagChip(tag)],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
                    child: _StorageRow(s: s, record: record),
                  ),
                  RowHead(r.rec_source, ar: s.rtl),
                  PCard(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.ink100, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.user, size: 20, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Text(
                            attributedName(ref, s, record.history) ??
                                (record.source.isSelf ? r.rec_self : record.source.value),
                            style: Typo.body(ar: s.rtl)
                                .copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 0),
                    child: Column(
                      children: [
                        PButton(
                          r.rec_view,
                          icon: LucideIcons.eye,
                          large: true,
                          block: true,
                          accent: s.accent,
                          ar: s.rtl,
                          onTap: _canViewRecord(record)
                              ? () => VaultFileViewer.open(context, path: record.filePath!, title: record.title)
                              : null,
                        ),
                        const SizedBox(height: 10),
                        PButton(
                          r.rec_share,
                          icon: LucideIcons.share2,
                          variant: BtnVariant.secondary,
                          block: true,
                          ar: s.rtl,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _canViewRecord(RecordDocument record) {
  final path = record.filePath;
  if (path == null || path.isEmpty) return false;
  final type = (record.fileType ?? '').toLowerCase();
  if (type == 'image' || type.startsWith('image/') || type == 'pdf' || type == 'application/pdf') return true;
  final lower = path.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.pdf');
}

bool _isPdfRecord(RecordDocument record) {
  final type = (record.fileType ?? '').toLowerCase();
  return type == 'pdf' || type == 'application/pdf' || (record.filePath ?? '').toLowerCase().endsWith('.pdf');
}

/// Document plate — vault images render in-place; other types show a type placeholder.
class _DocPreview extends StatelessWidget {
  const _DocPreview({required this.type, this.filePath, this.isPdf = false});
  final RecordType type;
  final String? filePath;
  final bool isPdf;

  @override
  Widget build(BuildContext context) {
    // A PDF's bytes can't render through Image.memory — the old path fed them
    // to VaultImage and showed a silent blank plate. Type plate + tap-to-view.
    if (filePath case final filePathValue? when filePath!.isNotEmpty && !isPdf) {
      return VaultImage(path: filePathValue, height: 200);
    }
    final s = AppScope.of(context);
    final style = recordTypeStyle(type);
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.cream100,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.ink100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(AppRadii.md)),
            child: Icon(style.icon, size: 28, color: style.fg),
          ),
          const SizedBox(height: 10),
          Text(s.strings.records.rec_preview, style: Typo.meta(ar: s.rtl)),
        ],
      ),
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Container(width: 3, height: 34, color: color),
          const SizedBox(width: 12),
          Icon(LucideIcons.sparkles, size: 17, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              note,
              style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
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
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: c.border, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(c.icon, size: 18, color: c.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: target.isLocal ? s.strings.storage.store_local_only : s.strings.storage.store_backed,
                          style: Typo.bodySm(ar: s.rtl)
                              .copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        TextSpan(
                          text: '  · ${target.label(s.strings.storage)}',
                          style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(LucideIcons.settings2, size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 5),
                      Text(
                        s.strings.storage.store_manage,
                        style: Typo.meta(ar: s.rtl).copyWith(fontSize: FontSizes.meta),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StorageBadge(storage: target),
          ],
        ),
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
      decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.tag, size: 12, color: s.accent.d),
          const SizedBox(width: 5),
          Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: s.accent.d)),
        ],
      ),
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
    showAppSheet<void>(
      context,
      builder: (_) => _ManageStorageSheet(record: record),
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

  /// Delegates to the application layer — the blob-before-row ordering is
  /// domain policy and does not belong in a sheet.
  Future<void> _delete() async {
    if (deleting) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => deleting = true);
    try {
      await ref.read(deleteRecordDocumentUseCaseProvider)(widget.record, scope: userId);
    } on Object catch (_) {
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
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 0),
            child: Column(
              children: [
                const Padding(padding: EdgeInsets.only(bottom: 12), child: SheetGrab()),
                Container(
                  padding: const EdgeInsets.only(bottom: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.ink100))),
                  child: Row(
                    children: [
                      StorageIcon(target, size: 19, color: cfg.color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          confirming ? st.store_delete_rec : st.store_manage,
                          style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      RoundBtn(
                        icon: LucideIcons.x,
                        semanticLabel: s.strings.common.a11y_close,
                        ghost: true,
                        iconSize: 17,
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, sheetBottomInset(context, base: 36)),
              child: confirming ? _confirm(s) : _actions(s),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(PatientAppState s) {
    final st = s.strings.storage;
    final target = s.storageProvider;
    final cfg = storageCfg(target);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Current location — `.b-badge` row over the provider's tinted card.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: cfg.bg,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: cfg.border),
          ),
          child: Row(
            children: [
              StorageIcon(target, size: 16, color: cfg.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: target.isLocal ? st.store_local_only : st.store_backed,
                        style:
                            Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      TextSpan(
                        text: '  · ${target.label(st)}',
                        style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              StorageBadge(storage: target),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Design's "no clouds connected" hint — the same copy the storage sheet
        // shows, so the two never disagree about what backup is available.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.ink50, borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: Row(
            children: [
              const Icon(LucideIcons.info, size: 16, color: AppColors.textTertiary),
              const SizedBox(width: 10),
              Expanded(child: Text(st.store_choose_help, style: Typo.meta(ar: s.rtl).copyWith(height: 1.4))),
            ],
          ),
        ),
        const SizedBox(height: 10),
        PButton(
          st.store_delete_rec,
          icon: LucideIcons.trash2,
          variant: BtnVariant.danger,
          block: true,
          ar: s.rtl,
          onTap: () => setState(() => confirming = true),
        ),
      ],
    );
  }

  Widget _confirm(PatientAppState s) {
    final st = s.strings.storage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(st.store_delete_rec_h, style: Typo.meta(ar: s.rtl).copyWith(height: 1.5)),
        const SizedBox(height: 16),
        PButton(
          st.store_delete_rec,
          variant: BtnVariant.danger,
          large: true,
          block: true,
          ar: s.rtl,
          onTap: deleting ? null : _delete,
        ),
        const SizedBox(height: 10),
        PButton(
          s.strings.common.cancel,
          variant: BtnVariant.secondary,
          block: true,
          ar: s.rtl,
          onTap: deleting ? null : () => setState(() => confirming = false),
        ),
      ],
    );
  }
}

/// Add-record bottom sheet: pick a type, then fill in the metadata.
///
/// With [initial], the same sheet edits that record (records-mc.jsx
/// `AddRecordSheet` `initial`): it opens on the form, filled in with the
/// record's title, type, date, time and tags, and keeps its attachment.
Future<void> showAddRecord(BuildContext context, {RecordType? initialType, RecordDocument? initial}) async =>
    maintenancePaused(context)
        ? null
        : showAppSheet<void>(
            context,
            size: SheetSize.lg,
            builder: (_) => _AddRecordSheet(initialType: initialType, initial: initial),
          );

class _AddRecordSheet extends ConsumerStatefulWidget {
  const _AddRecordSheet({this.initialType, this.initial});
  final RecordType? initialType;

  /// The record being edited; null when adding one.
  final RecordDocument? initial;

  @override
  ConsumerState<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends ConsumerState<_AddRecordSheet> {
  final _title = TextEditingController();
  final _tagDraft = TextEditingController();
  bool _saving = false;
  bool _done = false;

  /// This sheet's [recordDraftProvider] key: type, date, tags and file live there.
  late final RecordDraftKey _key = (form: Object(), initial: widget.initial, initialType: widget.initialType);

  RecordDraft get _draft => ref.read(recordDraftProvider(_key));
  RecordDraftNotifier get _drafts => ref.read(recordDraftProvider(_key).notifier);

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    if (widget.initial case final initial?) _title.text = initial.title;
  }

  @override
  void dispose() {
    _title.dispose();
    _tagDraft.dispose();
    super.dispose();
  }

  /// Stores the edit through the records module; the attachment stays. A
  /// blank name falls back to the type, as a new record does.
  Future<void> _saveEdit(RecordDocument record) async {
    final draft = _draft;
    final typeValue = draft.type;
    if (typeValue == null || _saving) return;
    setState(() => _saving = true);
    final s = AppScope.of(context);
    final title = _title.text.trim();
    final result = await ref.read(updateRecordDocumentUseCaseProvider)(
      record.id,
      title: title.isEmpty ? recordTypeLabelOne(s, typeValue) : title,
      type: typeValue,
      takenAt: draft.takenAt,
      tags: draft.tags,
    );
    if (!mounted) return;
    if (result.isFailure) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.strings.records.rec_save_failed(s.gender))));
      return;
    }
    setState(() {
      _saving = false;
      _done = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (widget.initial case final record?) return _saveEdit(record);
    final userId = ref.read(currentUserIdProvider);
    final draft = _draft;
    final typeValue = draft.type;
    if (userId == null || typeValue == null || _saving) return;
    // Read before the first await: the store is written even if the sheet
    // closes while the file is being saved.
    final records = ref.read(recordsDataSourceProvider);
    setState(() => _saving = true);
    final s = AppScope.of(context);
    final now = DateTime.now();
    final id = RecordDocumentId.value('rec-${now.microsecondsSinceEpoch}');
    final title = _title.text.trim();
    String? filePath;
    String? fileType;
    if (draft.attach case PickedAttach(:final kind, :final bytes?)) {
      final ext = kind == 'pdf' ? 'pdf' : 'jpg';
      filePath = await saveVaultBytes(ref, fileName: '${id.value}.$ext', bytes: bytes);
      fileType = kind == 'pdf' ? 'PDF' : 'Image';
    }
    final doc = RecordDocument(
      id: id,
      userId: userId,
      type: typeValue,
      title: title.isEmpty ? recordTypeLabelOne(s, typeValue) : title,
      tags: draft.tags,
      fileType: fileType,
      filePath: filePath,
      takenAt: draft.takenAt,
      createdAt: now,
    );
    await records.put(id, doc);
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
    final type = ref.watch(recordDraftProvider(_key).select((d) => d.type));
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
            child: Row(
              children: [
                if (type != null && widget.initialType == null)
                  RoundBtn(
                    icon: backArrow(context),
                    semanticLabel: s.strings.common.a11y_back,
                    ghost: true,
                    iconSize: 18,
                    onTap: () => _drafts.setType(null),
                  ),
                Expanded(
                  child: Text(
                    switch (type) {
                      _ when _done => '',
                      null => r.rec_pick_type,
                      final t when _editing => r.rec_edit_title(recordTypeLabelOne(s, t)),
                      final t => recordTypeLabelOne(s, t),
                    },
                    style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                RoundBtn(
                  icon: LucideIcons.x,
                  semanticLabel: s.strings.common.a11y_close,
                  ghost: true,
                  iconSize: 18,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.ink100),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, sheetBottomInset(context, base: 36)),
              child: switch (type) {
                _ when _done => _RecordAdded(s: s, edited: _editing),
                null => _TypePicker(onPick: _drafts.setType),
                final t => _RecordForm(
                    s: s,
                    draftKey: _key,
                    type: t,
                    title: _title,
                    tagDraft: _tagDraft,
                    initial: widget.initial,
                    onSave: _saving ? null : _save,
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The add-record sheet's first step: one row per record type.
class _TypePicker extends StatelessWidget {
  const _TypePicker({required this.onPick});
  final ValueChanged<RecordType> onPick;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final type in RecordType.values) ...[
            _TypeRow(type: type, onTap: () => onPick(type)),
            const SizedBox(height: 12),
          ],
        ],
      );
}

/// The add-record sheet's form, once a type is picked. The date, tags and
/// file come from the sheet's [recordDraftProvider]; the title and the tag
/// being typed from their text fields.
class _RecordForm extends ConsumerWidget {
  const _RecordForm({
    required this.s,
    required this.draftKey,
    required this.type,
    required this.title,
    required this.tagDraft,
    required this.initial,
    required this.onSave,
  });
  final PatientAppState s;
  final RecordDraftKey draftKey;
  final RecordType type;
  final TextEditingController title;
  final TextEditingController tagDraft;

  /// The record being edited; null when adding one.
  final RecordDocument? initial;

  /// Null while a save is in flight.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = s.strings.records;
    final draft = ref.watch(recordDraftProvider(draftKey));
    final drafts = ref.read(recordDraftProvider(draftKey).notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(label: r.rec_title, child: _RecordInput(controller: title, hint: r.rec_title_ph)),
        const SizedBox(height: 18),
        DateTimeWhen(when: draft.takenAt, onChanged: drafts.setDate),
        const SizedBox(height: 18),
        _Field(
          label: r.rec_tags,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (draft.tags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: draft.tags
                      .map((tag) => _RemovableTag(label: tag, onRemove: () => drafts.removeTag(tag)))
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
              _RecordInput(
                controller: tagDraft,
                hint: r.rec_tags_ph(s.gender),
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isEmpty || draft.tags.contains(t)) return;
                  drafts.addTag(t);
                  tagDraft.clear();
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _suggestedTags(s, type)
                    .where((tag) => !draft.tags.contains(tag))
                    .map((tag) => _SuggestedTag(s: s, label: tag, onTap: () => drafts.addTag(tag)))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _RecordAttachment(
          s: s,
          initial: initial,
          attach: draft.attach,
          onAttach: (a) {
            // The picker answers after an await, by which time the sheet may be gone.
            if (context.mounted) ref.read(recordDraftProvider(draftKey).notifier).attach(a);
          },
        ),
        const SizedBox(height: 24),
        PButton(
          initial != null ? r.rec_save_changes : s.strings.settings.add_record,
          large: true,
          block: true,
          accent: s.accent,
          ar: s.rtl,
          onTap: onSave,
        ),
      ],
    );
  }
}

/// A tag the type suggests. Dashed in the design — the dashed outline is what
/// distinguishes "tap to add" from the solid, already-applied tags.
class _SuggestedTag extends StatelessWidget {
  const _SuggestedTag({required this.s, required this.label, required this.onTap});
  final PatientAppState s;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: DashedBorder(
          color: AppColors.borderStrong,
          strokeWidth: 1.5,
          radius: AppRadii.pill,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.plus, size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
}

/// A new record picks its file here; an edited one keeps the file it has,
/// shown as it is.
class _RecordAttachment extends StatelessWidget {
  const _RecordAttachment({required this.s, required this.initial, required this.attach, required this.onAttach});
  final PatientAppState s;
  final RecordDocument? initial;
  final PickedAttach? attach;
  final ValueChanged<PickedAttach?> onAttach;

  @override
  Widget build(BuildContext context) {
    final r = s.strings.records;
    final label = Text(
      r.rec_attach,
      style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
    );
    if (initial case final record?) {
      final path = record.filePath;
      if (path == null || path.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label,
          const SizedBox(height: 8),
          VaultAttachmentThumb(path: path, title: record.title, height: 120),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label,
        const SizedBox(height: 8),
        UploadDropzone(
          attach: attach,
          url: '',
          onAttach: onAttach,
          onUrl: (_) {},
          takePhotoLabel: r.rec_take_photo,
          fromFilesLabel: r.rec_from_files,
          help: r.rec_attach_h,
        ),
      ],
    );
  }
}

List<String> _suggestedTags(PatientAppState s, RecordType type) {
  final r = s.strings.records;
  return switch (type) {
    RecordType.lab => [r.tag_diabetes, r.tag_cholesterol, r.tag_kidney, r.tag_thyroid],
    RecordType.scan => [r.tag_chest, r.tag_abdomen, r.tag_bone, r.tag_follow_up],
    RecordType.report => [r.tag_cardiology, r.tag_surgery, r.tag_follow_up, r.tag_referral],
  };
}

/// `.b-input` as the record sheets draw it — add record and edit record.
class _RecordInput extends StatelessWidget {
  const _RecordInput({required this.controller, this.hint, this.onSubmitted});
  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    OutlineInputBorder b(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: c, width: 1.5),
        );
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textPrimary, fontSize: FontSizes.subhead),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Typo.body(ar: s.rtl).copyWith(color: AppColors.textHint, fontSize: FontSizes.subhead),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: b(AppColors.border),
        enabledBorder: b(AppColors.border),
        focusedBorder: b(s.accent.main),
      ),
    );
  }
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
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(AppRadii.md)),
              child: Icon(style.icon, size: 23, color: style.fg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                recordTypeLabelOne(s, type),
                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
            Chevron(rtl: s.rtl),
          ],
        ),
      ),
    );
  }
}

class _RecordAdded extends StatelessWidget {
  const _RecordAdded({required this.s, this.edited = false});
  final PatientAppState s;

  /// "Changes saved", with no subtitle, after an edit.
  final bool edited;

  @override
  Widget build(BuildContext context) {
    final r = s.strings.records;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.hueMint50, shape: BoxShape.circle),
            child: const Icon(LucideIcons.check, size: 36, color: AppColors.hueMint600),
          ),
          const SizedBox(height: 14),
          Text(
            edited ? r.rec_changes_saved : r.rec_added,
            style: Typo.heading(ar: s.rtl).copyWith(fontWeight: FontWeight.w700),
          ),
          if (!edited) ...[
            const SizedBox(height: 8),
            Text(r.rec_added_h, textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
          ],
        ],
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
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
      decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: s.accent.d)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(LucideIcons.x, size: 13, color: s.accent.d),
          ),
        ],
      ),
    );
  }
}
