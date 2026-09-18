import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdfrx/pdfrx.dart';

import '../app_state.dart';
import '../kit.dart';
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
class VaultFileViewer extends ConsumerWidget {
  const VaultFileViewer({super.key, required this.path, this.title});

  final String path;
  final String? title;

  /// Pushes the viewer as a full-screen route.
  static Future<void> open(BuildContext context, {required String path, String? title}) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => VaultFileViewer(path: path, title: title)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final blob = ref.watch(vaultBlobProvider(path));
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
                  '${vaultFileKind(path, b) == VaultFileKind.pdf ? 'PDF' : s.strings.settings.add_photo} · ${_fmtSize(b.length)}',
                  textAlign: TextAlign.center,
                  style: Typo.bodySm(ar: s.rtl).copyWith(color: Colors.white54, fontSize: FS.xs),
                ),
            ]),
          ),
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
