import 'package:app/balsm_app/care/map_packs/map_pack_download_controller.dart';
import 'package:app/balsm_app/care/map_packs/map_pack_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';

/// Offline map packs: view/download/update/delete a governorate's basemap +
/// places pair. See docs/superpowers/specs/2026-09-14-map-pack-download-manager-design.md.
void showMapPacksSheet(BuildContext context) {
  final s = AppScope.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x5C14202B),
    builder: (ctx) => Directionality(
      textDirection: s.dir,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const _MapPacksSheet(),
        ),
      ),
    ),
  );
}

class _MapPacksSheet extends ConsumerStatefulWidget {
  const _MapPacksSheet();
  @override
  ConsumerState<_MapPacksSheet> createState() => _MapPacksSheetState();
}

class _MapPacksSheetState extends ConsumerState<_MapPacksSheet> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      final lang = AppScope.of(context).lang.value;
      Future.microtask(() => ref.read(mapPackDownloadControllerProvider.notifier).load(lang));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ar = s.rtl;
    final state = ref.watch(mapPackDownloadControllerProvider);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
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
                const Icon(LucideIcons.download, size: 20, color: T.fg3),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(s.strings.map_packs.title,
                        style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700))),
                RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 17, onTap: () => Navigator.pop(context)),
              ]),
            ),
          ]),
        ),
        if (state.offline)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(s.strings.map_packs.offline_notice, style: Typo.bodySm(ar: ar).copyWith(color: T.fg3)),
          ),
        Flexible(
          child: state.loading && state.items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, sheetBottomInset(context, base: 24)),
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _row(s, ar, state.items[i]),
                ),
        ),
      ]),
    );
  }

  Widget _row(PatientAppState s, bool ar, MapPackListItem item) {
    final sizeLabel = '${(item.totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(T.rLg),
        border: Border.all(color: T.border, width: 1.5),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
            const SizedBox(height: 2),
            Text(
              item.availability == MapPackAvailability.downloading
                  ? '$sizeLabel · ${(item.progress * 100).round()}%'
                  : '$sizeLabel · ${_statusLabel(s, item.availability)}',
              style: Typo.bodySm(ar: ar).copyWith(color: T.fg3),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        _action(s, ar, item),
      ]),
    );
  }

  String _statusLabel(PatientAppState s, MapPackAvailability a) => switch (a) {
        MapPackAvailability.notDownloaded => s.strings.map_packs.not_downloaded,
        MapPackAvailability.downloaded => s.strings.map_packs.downloaded,
        MapPackAvailability.updateAvailable => s.strings.map_packs.update_available,
        MapPackAvailability.failed => s.strings.map_packs.failed,
        MapPackAvailability.downloading => '', // shown as a percentage instead, see _row
      };

  Widget _action(PatientAppState s, bool ar, MapPackListItem item) {
    final notifier = ref.read(mapPackDownloadControllerProvider.notifier);
    switch (item.availability) {
      case MapPackAvailability.notDownloaded:
        return _btn(s, ar, s.strings.map_packs.download, () => notifier.download(item.governorateId));
      case MapPackAvailability.updateAvailable:
        return _btn(s, ar, s.strings.map_packs.update, () => notifier.download(item.governorateId));
      case MapPackAvailability.failed:
        return _btn(s, ar, s.strings.map_packs.retry, () => notifier.download(item.governorateId));
      case MapPackAvailability.downloading:
        return _btn(s, ar, s.strings.map_packs.cancel, () => notifier.cancel(item.governorateId));
      case MapPackAvailability.downloaded:
        return _btn(s, ar, s.strings.map_packs.delete, () => notifier.delete(item.governorateId), destructive: true);
    }
  }

  // T.danger/T.dangerBg are this codebase's real destructive tokens (see
  // tokens.dart); accent isn't a T constant — it's the user's chosen brand
  // accent, s.accent.{main,bg}, the same fields the recenter button
  // (RoundBtn(..., fg: s.accent.main, ...)) already reads.
  Widget _btn(PatientAppState s, bool ar, String label, VoidCallback onTap, {bool destructive = false}) => Pressable(
        onTap: onTap,
        scale: 0.97,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: destructive ? T.dangerBg : s.accent.bg,
            borderRadius: BorderRadius.circular(T.rPill),
          ),
          child: Text(label,
              style: Typo.bodySm(ar: ar)
                  .copyWith(fontWeight: FontWeight.w700, color: destructive ? T.danger : s.accent.main)),
        ),
      );
}
