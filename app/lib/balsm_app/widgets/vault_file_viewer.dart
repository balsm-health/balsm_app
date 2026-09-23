import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdfrx/pdfrx.dart';

import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import 'balsm_mark.dart';
import 'photo_attach.dart';

/// What a vault attachment turns out to be once decrypted.
enum VaultFileKind { image, pdf }

/// Extension first, then content sniff: records store `<id>.pdf` / `<id>.jpg`,
/// but older rows carried free-form names, so `%PDF` in the header wins when
/// the extension says nothing.
VaultFileKind vaultFileKind(String path, Uint8List bytes) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.pdf')) return VaultFileKind.pdf;
  if (bytes.length >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
    return VaultFileKind.pdf; // "%PDF"
  }
  return VaultFileKind.image;
}

/// Full-screen viewer for encrypted vault attachments (records, prescriptions).
///
/// Decrypts through [vaultBlobProvider] (autoDispose — plaintext leaves memory
/// when the route closes) and renders in place: images in an
/// [InteractiveViewer], PDFs via pdfrx from the in-memory bytes. The decrypted
/// bytes NEVER touch disk — no temp files, no share/export — so the vault's
/// at-rest encryption holds for the whole preview path. Bytes are never logged.
class VaultFileViewer extends ConsumerStatefulWidget {
  const VaultFileViewer({super.key, required this.paths, this.index = 0, this.title});

  /// Every file in the set being viewed; the design pages a record's files in
  /// place rather than closing and reopening (`AttachmentViewer`).
  final List<String> paths;

  /// Where to start in [paths].
  final int index;

  final String? title;

  /// Pushes the viewer as a full-screen route on one file.
  static Future<void> open(BuildContext context, {required String path, String? title}) {
    return openAll(context, paths: [path], title: title);
  }

  /// Pushes the viewer on a whole set, starting at [index].
  static Future<void> openAll(BuildContext context, {required List<String> paths, int index = 0, String? title}) {
    if (paths.isEmpty) return Future<void>.value();
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => VaultFileViewer(paths: paths, index: index, title: title)),
    );
  }

  @override
  ConsumerState<VaultFileViewer> createState() => _VaultFileViewerState();
}

class _VaultFileViewerState extends ConsumerState<VaultFileViewer> {
  late int _i = widget.index.clamp(0, widget.paths.length - 1);

  String get path => widget.paths[_i];
  String? get title => widget.title;

  /// Wraps, like the design's `step`.
  void _step(int delta) {
    setState(() => _i = (_i + delta + widget.paths.length) % widget.paths.length);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final blob = ref.watch(vaultBlobProvider(path));
    final many = widget.paths.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(
          child: blob.when(
            loading: () => const Center(child: MarkSpinner(size: 44)),
            // The reason is not something to render over PHI — keep it generic.
            error: (_, __) => _CantOpen(s: s),
            data: (bytes) => bytes == null ? _CantOpen(s: s) : _content(bytes),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 12,
          child: RoundBtn(icon: LucideIcons.x, onTap: () => Navigator.of(context).pop()),
        ),
        if (title != null && title!.isNotEmpty)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 64,
            right: 64,
            child: Column(children: [
              Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Typo.bodySm(ar: s.rtl).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              // Kind · size meta (design att-bar) — derived from the decrypted
              // bytes; nothing else about the file is disclosed.
              if (blob.valueOrNull case final b?)
                Text(
                  '${vaultFileKind(path, b) == VaultFileKind.pdf ? 'PDF' : s.strings.settings.add_photo} · ${_fmtSize(b.length)}'
                  '${many ? ' · ${_i + 1}/${widget.paths.length}' : ''}',
                  textAlign: TextAlign.center,
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: Colors.white54, fontSize: FS.xs),
                ),
            ]),
          ),
        // `.att-nav` — 44px discs pinned to the stage's edges. Directional
        // insets so RTL puts "previous" on the right, as the design does.
        if (many) ...[
          PositionedDirectional(
            start: 10,
            top: 0,
            bottom: 0,
            // Chevrons, as `.att-nav` draws them — and they point toward the
            // edge they sit on, which RTL flips along with the position.
            child: Center(
              child: _NavDisc(
                icon: s.rtl ? LucideIcons.chevronRight : LucideIcons.chevronLeft,
                onTap: () => _step(-1),
              ),
            ),
          ),
          PositionedDirectional(
            end: 10,
            top: 0,
            bottom: 0,
            child: Center(
              child: _NavDisc(
                icon: s.rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
                onTap: () => _step(1),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ThumbStrip(
              paths: widget.paths,
              current: _i,
              bottomInset: MediaQuery.paddingOf(context).bottom,
              onPick: (n) => _step(n - _i),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _content(Uint8List bytes) {
    switch (vaultFileKind(path, bytes)) {
      case VaultFileKind.pdf:
        return PdfViewer.data(
          bytes,
          // Cache key only — the vault-relative path, never file content.
          sourceName: path,
          params: const PdfViewerParams(backgroundColor: Colors.black),
        );
      case VaultFileKind.image:
        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.memory(bytes, fit: BoxFit.contain, width: double.infinity),
          ),
        );
    }
  }
}

String _fmtSize(int b) =>
    b > 1048576 ? '${(b / 1048576).toStringAsFixed(1)} MB' : '${(b / 1024).clamp(1, double.infinity).round()} KB';

class _CantOpen extends StatelessWidget {
  const _CantOpen({required this.s});
  final PatientAppState s;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(LucideIcons.fileX, size: 40, color: Colors.white38),
        const SizedBox(height: 12),
        Text(s.strings.records.rec_preview_failed, style: Typo.bodySm(ar: s.rtl).copyWith(color: Colors.white70)),
      ]),
    );
  }
}

/// `.att-nav` — a 44px translucent disc over the stage.
class _NavDisc extends StatelessWidget {
  const _NavDisc({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0x991F2D3D),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 24, color: Colors.white),
          ),
        ),
      );
}

/// `.att-strip` — 54px chips, the current one ringed in white. Images preview
/// themselves; anything else shows its kind icon.
class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({
    required this.paths,
    required this.current,
    required this.onPick,
    required this.bottomInset,
  });

  final List<String> paths;
  final int current;
  final ValueChanged<int> onPick;
  final double bottomInset;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(14, 12, 14, bottomInset + 18),
        child: Row(children: [
          for (final (n, p) in paths.indexed)
            Padding(
              padding: EdgeInsetsDirectional.only(end: n == paths.length - 1 ? 0 : 8),
              child: GestureDetector(
                onTap: () => onPick(n),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0x1FFFFFFF),
                    borderRadius: BorderRadius.circular(T.rMd),
                    border: Border.all(color: n == current ? Colors.white : Colors.transparent, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: p.toLowerCase().endsWith('.pdf')
                      ? const Icon(LucideIcons.fileText, size: 18, color: Colors.white70)
                      : VaultImage(path: p, height: 54),
                ),
              ),
            ),
        ]),
      );
}
