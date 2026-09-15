import 'package:core/core.dart' show currentUserIdProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:records/records.dart' show RecordDocument, recordsDataSourceProvider;

import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import 'photo_attach.dart' show VaultImage;
import 'vault_file_viewer.dart';

/// Design `attachments.jsx AttachmentThumb`: one tap target for every stored
/// attachment. Images render as a cover thumbnail with a centre affordance and
/// a name strip; PDFs render as a row card (icon tile · name · kind/size ·
/// eye). Tapping opens [VaultFileViewer] — decrypted bytes never touch disk.
class VaultAttachmentThumb extends ConsumerWidget {
  const VaultAttachmentThumb({super.key, required this.path, this.title, this.height = 140});

  final String path;
  final String? title;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final isPdf = path.toLowerCase().endsWith('.pdf');
    if (!isPdf) {
      return GestureDetector(
        onTap: () => VaultFileViewer.open(context, path: path, title: title),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(T.rLg),
          child: Stack(children: [
            VaultImage(path: path, height: height),
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: Color(0xB81F2D3D), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.maximize2, size: 18, color: Colors.white),
                ),
              ),
            ),
            if (title != null && title!.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xB31F2D3D)],
                    ),
                  ),
                  child: Row(children: [
                    const Icon(LucideIcons.image, size: 13, color: Colors.white),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Typo.bodySm(ar: s.rtl)
                              .copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: FS.xs)),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      );
    }
    // Non-visual kinds: row card.
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(T.rLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(T.rLg),
        onTap: () => VaultFileViewer.open(context, path: path, title: title),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(T.rLg),
            border: Border.all(color: T.border),
          ),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: T.petalViolet50, borderRadius: BorderRadius.circular(T.rMd)),
              child: const Icon(LucideIcons.fileText, size: 20, color: T.petalViolet),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title ?? path.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                const SizedBox(height: 2),
                Text('PDF', style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3, fontSize: FS.xs)),
              ]),
            ),
            const Icon(LucideIcons.eye, size: 18, color: T.fg4),
          ]),
        ),
      ),
    );
  }
}

/// Resolves a records-vault document by id and renders its attachment thumb.
/// Renders nothing while loading, when the record is gone, or when it carries
/// no file — a missing back-reference must never break the host screen.
class RecordAttachmentThumb extends ConsumerWidget {
  const RecordAttachmentThumb({super.key, required this.recordId, this.height = 140});

  final String recordId;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUserIdProvider) == null) return const SizedBox.shrink();
    final records = ref.watch(_allRecordsProvider).valueOrNull;
    final record = records?.where((r) => r.id.value == recordId).firstOrNull;
    final path = record?.filePath;
    if (record == null || path == null) return const SizedBox.shrink();
    return VaultAttachmentThumb(path: path, title: record.title, height: height);
  }
}

/// All vault rows including check-in photos — [RecordAttachmentThumb] resolves
/// back-references that the document-library list deliberately filters out.
final _allRecordsProvider = StreamProvider.autoDispose<List<RecordDocument>>((ref) {
  return ref.watch(recordsDataSourceProvider).watchAll();
});
