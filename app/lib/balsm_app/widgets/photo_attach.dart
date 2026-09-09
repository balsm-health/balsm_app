import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';

/// Picked local attachment — bytes stay in memory until the form saves.
class PickedAttach {
  const PickedAttach({required this.kind, this.bytes, this.url, this.name});

  /// `image` | `pdf` | `url`
  final String kind;
  final Uint8List? bytes;
  final String? url;
  final String? name;

  bool get isImage => kind == 'image' && bytes != null;
}

Future<PickedAttach?> pickImageAttach({required bool camera}) async {
  final file = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 85,
  );
  if (file == null) return null;
  return PickedAttach(kind: 'image', bytes: await file.readAsBytes(), name: file.name);
}

Future<PickedAttach?> pickFileAttach() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'heic'],
    withData: true,
  );
  final file = result?.files.single;
  if (file == null) return null;
  final ext = (file.extension ?? '').toLowerCase();
  final bytes = file.bytes;
  if (bytes == null) return null;
  if (ext == 'pdf') return PickedAttach(kind: 'pdf', bytes: bytes, name: file.name);
  return PickedAttach(kind: 'image', bytes: bytes, name: file.name);
}

/// Claude Design `NoteAttach` camera row under a note field.
class NotePhotoAttach extends StatelessWidget {
  const NotePhotoAttach({super.key, required this.photo, required this.onChanged});

  final PickedAttach? photo;
  final ValueChanged<PickedAttach?> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (photo?.isImage == true) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _ImagePreview(bytes: photo!.bytes!, onClear: () => onChanged(null)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: PressHighlight(
        onTap: () async {
          final picked = await pickImageAttach(camera: false);
          if (picked != null) onChanged(picked);
        },
        // `.photo-add` — 1.5px **dashed** --balsm-border-strong, radius-md.
        child: DashedBorder(
          color: T.borderStrong,
          strokeWidth: 1.5,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(T.rMd),
            ),
            child: Row(children: [
              const Icon(LucideIcons.camera, size: 20, color: T.fg3),
              const SizedBox(width: 12),
              Text(s.strings.settings.add_photo, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Claude Design upload dropzone (camera / files / paste URL).
class UploadDropzone extends StatelessWidget {
  const UploadDropzone({
    super.key,
    required this.attach,
    required this.url,
    required this.onAttach,
    required this.onUrl,
    this.takePhotoLabel,
    this.fromFilesLabel,
    this.orPasteLabel,
    this.urlHint,
    this.help,
  });

  final PickedAttach? attach;
  final String url;
  final ValueChanged<PickedAttach?> onAttach;
  final ValueChanged<String> onUrl;
  final String? takePhotoLabel;
  final String? fromFilesLabel;
  final String? orPasteLabel;
  final String? urlHint;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (attach?.isImage == true) {
      return _ImagePreview(bytes: attach!.bytes!, height: 180, onClear: () => onAttach(null));
    }
    if (attach?.kind == 'pdf') {
      return _FileChip(name: attach!.name ?? 'PDF', onClear: () => onAttach(null));
    }
    // Design dropzone — 1.5px **dashed** --balsm-border-strong, radius-md.
    return DashedBorder(
      color: T.borderStrong,
      strokeWidth: 1.5,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 16),
        decoration: BoxDecoration(
          color: T.cream50,
          borderRadius: BorderRadius.circular(T.rMd),
        ),
        child: Column(children: [
          const Icon(LucideIcons.uploadCloud, size: 28, color: T.fg3),
          if (help != null) ...[
            const SizedBox(height: 12),
            Text(help!, textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
          ],
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(
              child: PButton(
                takePhotoLabel ?? s.strings.meds.rx_take_photo,
                icon: LucideIcons.camera,
                variant: BtnVariant.soft,
                size: BtnSize.sm,
                accent: s.accent,
                ar: s.rtl,
                onTap: () async {
                  final picked = await pickImageAttach(camera: true);
                  if (picked != null) onAttach(picked);
                },
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: PButton(
                fromFilesLabel ?? s.strings.meds.rx_from_files,
                icon: LucideIcons.folder,
                variant: BtnVariant.secondary,
                size: BtnSize.sm,
                ar: s.rtl,
                onTap: () async {
                  final picked = await pickFileAttach();
                  if (picked != null) onAttach(picked);
                },
              ),
            ),
          ]),
          if (orPasteLabel != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Expanded(child: Divider(color: T.ink100)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(orPasteLabel!,
                    style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg4)),
              ),
              const Expanded(child: Divider(color: T.ink100)),
            ]),
            const SizedBox(height: 8),
            TextField(
              textDirection: TextDirection.ltr,
              onChanged: onUrl,
              style: Typo.body(ar: false).copyWith(color: T.fg1, fontSize: FS.lg),
              decoration: InputDecoration(
                hintText: urlHint,
                hintStyle: Typo.body(ar: false).copyWith(color: T.fg4, fontSize: FS.lg),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(T.rMd),
                    borderSide: const BorderSide(color: T.border, width: 1.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(T.rMd),
                    borderSide: const BorderSide(color: T.border, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(T.rMd),
                    borderSide: BorderSide(color: s.accent.main, width: 1.5)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes, required this.onClear, this.height = 130});
  final Uint8List bytes;
  final VoidCallback onClear;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(T.rMd),
        child: Image.memory(
          bytes,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          // Decode to the box, not to the sensor. A phone-camera capture is
          // ~12 MP — about 48 MB once decoded — for a 130pt strip. Only one
          // axis is given, so the aspect ratio is preserved.
          cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).round(),
        ),
      ),
      Positioned(
        top: 8,
        right: 8,
        child: Material(
          color: const Color(0x8C1A1A17),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onClear,
            child: const SizedBox(
              width: 30,
              height: 30,
              child: Icon(LucideIcons.x, size: 15, color: Colors.white),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.name, required this.onClear});
  final String name;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(T.rLg),
        border: Border.all(color: T.border),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: T.petalViolet50, borderRadius: BorderRadius.circular(T.rMd)),
          child: const Icon(LucideIcons.fileText, size: 20, color: T.petalViolet),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600)),
        ),
        IconButton(onPressed: onClear, icon: const Icon(LucideIcons.x, size: 16, color: T.fg4)),
      ]),
    );
  }
}

/// One decrypted vault blob, keyed by path.
///
/// `FutureBuilder(future: ref.read(...).read(path))` rebuilt the future on
/// every rebuild, so the blob was decrypted again on each frame that touched
/// the widget. A family provider caches per path, dedupes concurrent readers,
/// and `autoDispose` drops the plaintext from memory as soon as nothing is
/// showing it — which is what we want for PHI.
final vaultBlobProvider = FutureProvider.autoDispose.family<Uint8List?, String>(
  (ref, path) => ref.watch(userFileStoreProvider).read(path),
);

/// Renders an encrypted vault image. Bytes are never logged.
class VaultImage extends ConsumerWidget {
  const VaultImage({
    super.key,
    required this.path,
    this.height = 180,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });
  final String path;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radius = borderRadius ?? BorderRadius.circular(T.rLg);
    final placeholder = Container(
      height: height ?? 180,
      decoration: BoxDecoration(color: T.cream100, borderRadius: radius),
    );
    // A failed decrypt shows the placeholder rather than an error surface: the
    // caller already frames this as an attachment, and the reason is not
    // something to render over PHI.
    final bytes = ref.watch(vaultBlobProvider(path)).valueOrNull;
    if (bytes == null) return placeholder;
    final h = height;
    return ClipRRect(
      borderRadius: radius,
      child: Image.memory(
        bytes,
        width: double.infinity,
        height: h,
        fit: fit,
        // See [_ImagePreview]: record scans are camera-resolution, and several
        // thumbnails at full decode will evict everything else from the image
        // cache. Unbounded only when the caller lets the image size itself.
        cacheHeight: h == null ? null : (h * MediaQuery.devicePixelRatioOf(context)).round(),
      ),
    );
  }
}
