import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:records/records.dart';

import '../app_state.dart';
import '../kit.dart';
import 'photo_attach.dart';
import 'vault_file_viewer.dart';

/// Design `attachments.jsx AttachmentThumb`: one tap target for every stored
/// attachment. Images render as a cover thumbnail with a centre affordance and
/// a name strip; PDFs render as a row card (icon tile · name · kind/size ·
/// eye). Tapping opens [VaultFileViewer] — decrypted bytes never touch disk.
class VaultAttachmentThumb extends ConsumerWidget {
  const VaultAttachmentThumb({
    required this.path,
    super.key,
    this.title,
    this.height = 140,
    this.compact = false,
    this.onOpen,
  });

  final String path;
  final String? title;
  final double height;

  /// Design `AttachmentThumb`'s `compact` prop: a square grid tile rather than
  /// a full-width card. Images still cover the tile; everything else becomes a
  /// centred icon over its kind, because the row card cannot fit in 96px.
  final bool compact;

  /// Design `AttachmentThumb`'s `onOpen` prop. Null opens this file alone; a
  /// strip passes one so the viewer opens on the whole set at that index.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final isPdf = path.toLowerCase().endsWith('.pdf');
    if (compact) {
      return GestureDetector(
        onTap: onOpen ?? () => VaultFileViewer.open(context, path: path, title: title),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: isPdf ? AppColors.cream50 : AppColors.ink800,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: isPdf
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.fileText, size: 22, color: AppColors.hueViolet),
                      const SizedBox(height: 4),
                      Text(
                        'PDF',
                        style: Typo.bodySm(ar: s.rtl).copyWith(
                          fontSize: FontSizes.meta,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : VaultImage(path: path, height: height),
        ),
      );
    }
    if (!isPdf) {
      return GestureDetector(
        onTap: onOpen ?? () => VaultFileViewer.open(context, path: path, title: title),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Stack(
            children: [
              VaultImage(path: path, height: height),
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: AppColors.overPhoto, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.maximize2, size: 18, color: AppColors.white),
                  ),
                ),
              ),
              if (title case final titleValue? when title!.isNotEmpty)
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 14, 12, 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.overPhoto],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.image, size: 13, color: AppColors.white),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            titleValue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Typo.bodySm(ar: s.rtl).copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: FontSizes.meta,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    // Non-visual kinds: row card.
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onOpen ?? () => VaultFileViewer.open(context, path: path, title: title),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(color: AppColors.hueViolet50, borderRadius: BorderRadius.circular(AppRadii.md)),
                child: const Icon(LucideIcons.fileText, size: 20, color: AppColors.hueViolet),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? path.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PDF',
                      style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textTertiary, fontSize: FontSizes.meta),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.eye, size: 18, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resolves a records-vault document by id and renders its attachment thumb.
/// Renders nothing while loading, when the record is gone, or when it carries
/// no file — a missing back-reference must never break the host screen.
class RecordAttachmentThumb extends ConsumerWidget {
  const RecordAttachmentThumb({required this.recordId, super.key, this.height = 140});

  final String recordId;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUserIdProvider) == null) return const SizedBox.shrink();
    final records = ref.watch(_allRecordsProvider).value;
    final record = records?.where((r) => r.id.value == recordId).firstOrNull;
    final path = record?.filePath;
    if (record == null || path == null) return const SizedBox.shrink();
    return VaultAttachmentThumb(path: path, title: record.title, height: height);
  }
}

/// All vault rows including check-in photos — [RecordAttachmentThumb] resolves
/// back-references that the document-library list deliberately filters out.
final StreamProvider<List<RecordDocument>> _allRecordsProvider =
    StreamProvider.autoDispose<List<RecordDocument>>((ref) {
  final profileId = ref.watch(currentProfileIdProvider);
  if (profileId == null) return Stream.value(const []);
  return ref.watch(recordsDataSourceProvider).watchAll(scope: profileId);
});

/// Design `attachments.jsx AttachmentGallery`: a lead thumb, then the rest as
/// a tile grid, an optional dashed "add" tile, and a file count.
///
/// Every path is a vault-relative name; bytes are decrypted per tile and never
/// written to disk. Tapping any tile opens [VaultFileViewer] on the whole set
/// so the viewer can page in place, as the design does.
class VaultAttachmentGallery extends StatelessWidget {
  const VaultAttachmentGallery({
    required this.paths,
    super.key,
    this.height = 200,
    this.title,
    this.onRemove,
    this.onAdd,
    this.addLabel,
  });

  final List<String> paths;

  /// Height of the lead thumb (`AttachmentGallery` defaults to 200).
  final double height;

  /// Shown on the lead thumb and carried into the viewer.
  final String? title;

  /// Index-based, matching the design's `onRemove(i)`. Null hides the affordance.
  final ValueChanged<int>? onRemove;

  final VoidCallback? onAdd;
  final String? addLabel;

  /// `minmax(108px, 1fr)` tracks at an 8px gap.
  static const _tileMin = 108.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (paths.isEmpty && onAdd == null) return const SizedBox.shrink();

    final lead = paths.isEmpty ? null : paths.first;
    final rest = paths.length <= 1 ? const <String>[] : paths.sublist(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lead != null)
          _Removable(
            onRemove: switch (onRemove) { final onRemove? => () => onRemove(0), _ => null },
            child: GestureDetector(
              onTap: () => VaultFileViewer.openAll(context, paths: paths, title: title),
              child: AbsorbPointer(child: VaultAttachmentThumb(path: lead, title: title, height: height)),
            ),
          ),
        if (rest.isNotEmpty || onAdd != null) ...[
          if (lead != null) const SizedBox(height: _gap),
          LayoutBuilder(
            builder: (context, c) {
              // `repeat(auto-fill, minmax(108px, 1fr))`.
              final columns = math.max(1, ((c.maxWidth + _gap) / (_tileMin + _gap)).floor());
              final tileW = (c.maxWidth - _gap * (columns - 1)) / columns;
              // The add tile is shorter when it stands alone (design: 84 vs 96).
              final tileH = lead != null ? 96.0 : 84.0;
              return Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final (i, p) in rest.indexed)
                    SizedBox(
                      width: tileW,
                      height: 96,
                      child: _Removable(
                        onRemove: switch (onRemove) { final onRemove? => () => onRemove(i + 1), _ => null },
                        child: GestureDetector(
                          onTap: () => VaultFileViewer.openAll(context, paths: paths, index: i + 1, title: title),
                          child: AbsorbPointer(child: VaultAttachmentThumb(path: p, height: 96, compact: true)),
                        ),
                      ),
                    ),
                  if (onAdd case final onAdd?)
                    SizedBox(
                      width: tileW,
                      height: tileH,
                      child: Pressable(
                        onTap: onAdd,
                        child: DashedBorder(
                          color: AppColors.borderStrong,
                          radius: AppRadii.lg,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.cream50,
                              borderRadius: BorderRadius.circular(AppRadii.lg),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.plus, size: 18, color: AppColors.textTertiary),
                                const SizedBox(height: 6),
                                Text(
                                  addLabel ?? s.strings.records.att_add,
                                  textAlign: TextAlign.center,
                                  style: Typo.bodySm(ar: s.rtl).copyWith(
                                    fontSize: FontSizes.meta,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
        if (paths.isNotEmpty) ...[
          const SizedBox(height: _gap),
          Row(
            children: [
              const Icon(LucideIcons.paperclip, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 5),
              Text(
                // Arabic marks the singular differently, so it gets its own key
                // rather than an interpolated count.
                paths.length == 1 ? s.strings.records.att_one_file : s.strings.records.att_n_files('${paths.length}'),
                style: Typo.meta(ar: s.rtl),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Overlays the design's remove affordance on a tile.
class _Removable extends StatelessWidget {
  const _Removable({required this.child, this.onRemove});
  final Widget child;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    if (onRemove == null) return child;
    // The thumb must stay a NON-positioned child: a Stack of only positioned
    // children has no intrinsic size, and a PDF row card would then be asked
    // to lay out at infinite width.
    return Stack(
      children: [
        child,
        PositionedDirectional(
          top: 8,
          end: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.overPhoto, shape: BoxShape.circle),
              child: const Icon(LucideIcons.x, size: 14, color: AppColors.white),
            ),
          ),
        ),
      ],
    );
  }
}
