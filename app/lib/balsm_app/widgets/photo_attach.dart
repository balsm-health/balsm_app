import 'dart:async';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:profile/profile.dart';
import 'package:pasteboard/pasteboard.dart';
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

/// Where an attachment comes from.
///
/// The web prototype has one `<input type="file">` and no chooser, because the
/// browser supplies it. iOS and Android put Files and Photos behind different
/// pickers, so the choice has to be made in-app before either opens.
enum AttachSource {
  /// The system document picker — a PDF or an image already saved on device.
  files,

  /// The photo library.
  gallery,

  /// Whatever is on the clipboard: an image if there is one, otherwise a link.
  paste,

  /// A web address the patient types or pastes. Stored as an address only —
  /// Balsm never fetches it.
  url,
}

/// Reads the clipboard: an image if it holds one, otherwise a link.
///
/// Returns null when the clipboard holds neither, so the caller treats
/// "nothing usable" uniformly.
///
/// `pasteboard`, not `super_clipboard`: the latter builds its Rust side through
/// cargokit, whose Gradle plugin calls `Project.exec()` — removed in Gradle 9,
/// which this app is on (9.3.1 / AGP 9.1.0). It failed the Android build
/// outright. The cost is per-format negotiation: a PDF on the clipboard is no
/// longer offered, only an image or a link. Copying a PDF as clipboard *data*
/// is vanishingly rare on a phone, and Files still covers it.
Future<PickedAttach?> pasteAttachment() async {
  Uint8List? image;
  try {
    image = await Pasteboard.image;
  } catch (_) {
    image = null;
  }
  if (image != null && image.isNotEmpty) {
    return PickedAttach(kind: 'image', bytes: image, name: 'pasted-image');
  }

  String? text;
  try {
    text = await Pasteboard.text;
  } catch (_) {
    text = null;
  }
  final trimmed = text?.trim() ?? '';
  if (isStorableLink(trimmed)) return PickedAttach(kind: 'url', url: trimmed);
  return null;
}

/// Asks where the file should come from, then opens that picker.
///
/// Returns null when the sheet or the picker was dismissed, so a cancel at
/// either step is indistinguishable to the caller — as it should be.
Future<PickedAttach?> pickAttachment(BuildContext context) async {
  final source = await showAppSheet<AttachSource>(
    context,
    textDirection: AppScope.of(context).dir,
    builder: (_) => const AttachSourceSheet(),
  );
  if (source == null || !context.mounted) return null;
  return switch (source) {
    AttachSource.files => pickFileAttach(),
    AttachSource.gallery => pickImageAttach(camera: false),
    AttachSource.paste => pasteAttachment(),
    AttachSource.url => askForLink(context),
  };
}

/// Small sheet for typing or pasting a web address.
///
/// Says plainly that the address is all that is kept: an attachment the patient
/// cannot open offline, and that Balsm never downloads, should not be mistaken
/// for a copy of the document.
Future<PickedAttach?> askForLink(BuildContext context) async {
  final s = AppScope.of(context);
  final url = await showAppSheet<String>(
    context,
    textDirection: s.dir,
    builder: (_) => const _LinkPromptSheet(),
  );
  final trimmed = url?.trim() ?? '';
  return isStorableLink(trimmed) ? PickedAttach(kind: 'url', url: trimmed) : null;
}

class _LinkPromptSheet extends StatefulWidget {
  const _LinkPromptSheet();

  @override
  State<_LinkPromptSheet> createState() => _LinkPromptSheetState();
}

class _LinkPromptSheetState extends State<_LinkPromptSheet> {
  final _url = TextEditingController();
  bool _touched = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final v = (await Pasteboard.text)?.trim();
    if (v == null || v.isEmpty || !mounted) return;
    setState(() => _url.text = v);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = s.strings.records;
    final typed = _url.text.trim();
    final bad = _touched && typed.isNotEmpty && !isStorableLink(typed);

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(T.rXl)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          const SheetGrab(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
            child: Row(children: [
              Expanded(
                child: Text(r.att_url_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
              ),
              RoundBtn(
                  icon: LucideIcons.x,
                  semanticLabel: s.strings.common.a11y_close,
                  ghost: true,
                  iconSize: 17,
                  onTap: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1, color: T.ink100),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, sheetBottomInset(context, base: 28)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _url,
                autofocus: true,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                onChanged: (_) => setState(() => _touched = true),
                style: Typo.body(ar: s.rtl).copyWith(fontSize: FS.md, color: T.fg1),
                decoration: InputDecoration(
                  hintText: r.att_url_hint,
                  hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4, fontSize: FS.sm),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  prefixIcon: const Icon(LucideIcons.link, size: 16, color: T.fg3),
                  prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: kMinTapTarget),
                  suffixIcon: IntrinsicWidth(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: PButton(
                        s.strings.care.care_paste,
                        icon: LucideIcons.clipboardPaste,
                        variant: BtnVariant.ghost,
                        size: BtnSize.sm,
                        accent: s.accent,
                        ar: s.rtl,
                        onTap: _paste,
                      ),
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(T.rMd),
                      borderSide: BorderSide(color: bad ? T.danger : T.border, width: 1.5)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(T.rMd),
                      borderSide: BorderSide(color: bad ? T.danger : s.accent.main, width: 1.5)),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: bad,
                child: Text(
                  bad ? r.att_url_bad : r.att_url_note,
                  style: Typo.meta(ar: s.rtl).copyWith(height: 1.5, color: bad ? T.danger : T.fg3),
                ),
              ),
              const SizedBox(height: 16),
              PButton(
                s.strings.common.continue_,
                variant: BtnVariant.primary,
                large: true,
                block: true,
                accent: s.accent,
                ar: s.rtl,
                onTap: isStorableLink(typed) ? () => Navigator.pop(context, typed) : null,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class AttachSourceSheet extends StatelessWidget {
  const AttachSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = s.strings.records;
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(T.rXl)),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        const SheetGrab(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
          child: Row(children: [
            Expanded(
              child: Text(r.att_source_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
            ),
            RoundBtn(
                icon: LucideIcons.x,
                semanticLabel: s.strings.common.a11y_close,
                ghost: true,
                iconSize: 17,
                onTap: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1, color: T.ink100),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, sheetBottomInset(context, base: 28)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _SourceRow(
              s: s,
              icon: LucideIcons.folderOpen,
              label: r.att_src_files,
              sub: r.att_src_files_h,
              onTap: () => Navigator.pop(context, AttachSource.files),
            ),
            const Divider(height: 1, color: T.ink100),
            _SourceRow(
              s: s,
              icon: LucideIcons.image,
              label: r.att_src_gallery,
              sub: r.att_src_gallery_h,
              onTap: () => Navigator.pop(context, AttachSource.gallery),
            ),
            const Divider(height: 1, color: T.ink100),
            _SourceRow(
              s: s,
              icon: LucideIcons.clipboardPaste,
              label: r.att_src_paste,
              sub: r.att_src_paste_h,
              onTap: () => Navigator.pop(context, AttachSource.paste),
            ),
            const Divider(height: 1, color: T.ink100),
            _SourceRow(
              s: s,
              icon: LucideIcons.link,
              label: r.att_src_url,
              sub: r.att_src_url_h,
              onTap: () => Navigator.pop(context, AttachSource.url),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.s,
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });
  final PatientAppState s;
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$label. $sub',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: s.accent.bg, borderRadius: BorderRadius.circular(T.rMd)),
                  child: Icon(icon, size: 19, color: s.accent.main),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(sub, style: Typo.meta(ar: s.rtl)),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                Chevron(rtl: s.rtl, size: 16),
              ]),
            ),
          ),
        ),
      );
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
          // Wrap, not Row: three labels at the largest text scale — and in
          // Arabic, which runs longer — overflow a single line on a small phone.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              PButton(
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
              // The photo library is a separate source from Files: on iOS the
              // document picker cannot see Photos, so a prescription
              // photographed earlier was unreachable without this.
              PButton(
                s.strings.meds.rx_from_gallery,
                icon: LucideIcons.image,
                variant: BtnVariant.secondary,
                size: BtnSize.sm,
                ar: s.rtl,
                onTap: () async {
                  final picked = await pickImageAttach(camera: false);
                  if (picked != null) onAttach(picked);
                },
              ),
              PButton(
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
            ],
          ),
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
          decoration: BoxDecoration(color: T.hueViolet50, borderRadius: BorderRadius.circular(T.rMd)),
          child: const Icon(LucideIcons.fileText, size: 20, color: T.hueViolet),
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
