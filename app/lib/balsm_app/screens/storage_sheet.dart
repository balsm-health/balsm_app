import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../i18n/strings.i69n.dart';
import '../kit.dart';
import '../storage_target.dart';
import '../tokens.dart';
import '../widgets/badges.dart';

/// Storage & sync (design: `storage.jsx` `StorageSyncSheet`).
///
/// The design's model: this device always holds a copy, and each data category
/// can additionally sync to any connected cloud. That model is ported whole —
/// cloud accounts, the per-category map, the per-category editor — but every
/// cloud in it is rendered unavailable, because none of them can receive a
/// byte in this build:
///
///  * `ICloudBackupAdapter` throws on every call (the `cloud_kit` plugin was
///    removed and not replaced).
///  * Balsm Cloud has no adapter at all.
///  * `BackupService` is not wired to `DriveBackupAdapter`, and backs up the
///    journal as one blob, so it has no concept of a category either.
///
/// So there is no Connect, no toggle and no "synced N minutes ago" — a screen
/// that tells a patient their health record reached a cloud it never left for
/// is the one failure this screen cannot have. [StorageTargetAvailability]
/// holds the gate; when an adapter lands, flipping it lights this screen up.
void showStorageSync(BuildContext context) {
  final s = AppScope.of(context);
  showAppSheet<void>(
    context,
    textDirection: s.dir,
    builder: (_) => _StorageSyncSheet(s: s),
  );
}

/// Where a category's data actually is. Device-only today; a list rather than a
/// single target because the design's model is additive and the pill, the
/// summary line and the stacked icons all read from it.
List<StorageTarget> syncTargetsFor(DataCategory _) =>
    StorageTarget.picker.where((t) => !t.isLocal && t.isAvailable).toList();

/// "This device only" / "Device + iCloud" / "Device + 2 clouds".
String locSummary(StorageStrings s, List<StorageTarget> targets) => switch (targets.length) {
      0 => s.store_device_only_sum,
      1 => s.store_device_plus(targets.first.label(s)),
      _ => s.store_device_plus_n('${targets.length}'),
    };

class _StorageSyncSheet extends ConsumerStatefulWidget {
  const _StorageSyncSheet({required this.s});
  final PatientAppState s;
  @override
  ConsumerState<_StorageSyncSheet> createState() => _StorageSyncSheetState();
}

class _StorageSyncSheetState extends ConsumerState<_StorageSyncSheet> {
  /// Null is the map; a category (or [_allData]) is its editor.
  DataCategory? _view;

  /// The design's `cat === 'all'` branch, which edits every category at once.
  bool _allView = false;

  PatientAppState get s => widget.s;
  bool get ar => s.rtl;

  @override
  Widget build(BuildContext context) {
    final st = s.strings.storage;
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(T.rXl)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(children: [
              const Padding(padding: EdgeInsets.only(bottom: 12), child: SheetGrab()),
              Container(
                padding: const EdgeInsets.only(bottom: 12),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink100))),
                child: Row(children: [
                  const Icon(LucideIcons.hardDrive, size: 20, color: T.fg3),
                  const SizedBox(width: 10),
                  Expanded(child: Text(st.storage, style: Typo.subhead(ar: ar).copyWith(fontWeight: FontWeight.w700))),
                  RoundBtn(
                      icon: LucideIcons.x,
                      semanticLabel: s.strings.common.a11y_close,
                      ghost: true,
                      iconSize: 17,
                      onTap: () => Navigator.pop(context)),
                ]),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, sheetBottomInset(context, base: 36)),
              child: (_view != null || _allView)
                  ? CategorySyncBody(
                      s: s,
                      category: _view,
                      onBack: () => setState(() {
                        _view = null;
                        _allView = false;
                      }),
                    )
                  : _map(),
            ),
          ),
        ]),
      ),
    );
  }

  /// The map: cloud accounts, then every data category and where it lives.
  Widget _map() {
    final st = s.strings.storage;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
        child: Text(st.store_intro, style: Typo.meta(ar: ar).copyWith(height: 1.5)),
      ),
      _Eyebrow(st.store_accounts, ar: ar),
      const SizedBox(height: 10),
      _Grouped(children: [
        for (final t in StorageTarget.picker.where((t) => !t.isLocal)) _CloudAccountRow(s: s, target: t),
      ]),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: _Eyebrow(st.store_your_data, ar: ar)),
        // `storage.jsx` puts "Sync all" here. It opens the every-category
        // editor, which is the honest half of it — there is nothing to sync.
        PButton(
          st.store_all_data,
          icon: LucideIcons.layers,
          variant: BtnVariant.ghost,
          accent: s.accent,
          ar: ar,
          color: s.accent.main,
          onTap: () => setState(() => _allView = true),
        ),
      ]),
      const SizedBox(height: 10),
      _Grouped(children: [
        for (final cat in DataCategory.values)
          _CategoryRow(s: s, category: cat, onTap: () => setState(() => _view = cat)),
      ]),
      const SizedBox(height: 14),
      Text(st.store_whole_journal, style: Typo.meta(ar: ar).copyWith(height: 1.5)),
    ]);
  }
}

/// Where one category — or every category, when [category] is null — is kept.
///
/// The design lets the patient tick clouds here and hit "Save & sync". Nothing
/// is tickable while no cloud is available, so what remains is the honest part:
/// the device row, the clouds greyed with why, and what will happen when they
/// do arrive.
class CategorySyncBody extends StatelessWidget {
  const CategorySyncBody({super.key, required this.s, required this.category, this.onBack});
  final PatientAppState s;

  /// Null means the design's `cat === 'all'` branch.
  final DataCategory? category;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final st = s.strings.storage;
    final ar = s.rtl;
    final all = category == null;
    final targets = all ? const <StorageTarget>[] : syncTargetsFor(category!);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (onBack != null)
        Align(
          alignment: ar ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: PButton(
              st.store_all_data_back,
              icon: ar ? LucideIcons.arrowRight : LucideIcons.arrowLeft,
              variant: BtnVariant.ghost,
              accent: s.accent,
              ar: ar,
              color: s.accent.main,
              onTap: onBack,
            ),
          ),
        ),
      const SizedBox(height: 8),
      Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rMd)),
          child: Icon(all ? LucideIcons.layers : categoryIcon(category!), size: 20, color: T.fg2),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(all ? st.store_all_data : category!.label(st),
                style: Typo.body(ar: ar).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(all ? st.store_all_applies : locSummary(st, targets), style: Typo.meta(ar: ar)),
            ),
          ]),
        ),
      ]),
      const SizedBox(height: 18),
      _Eyebrow(st.store_stored_in, ar: ar),
      const SizedBox(height: 10),
      _Grouped(children: [
        _StoredInRow(s: s, target: StorageTarget.local, on: true),
        for (final t in StorageTarget.picker.where((t) => !t.isLocal))
          _StoredInRow(s: s, target: t, on: targets.contains(t)),
      ]),
      const SizedBox(height: 14),
      Text(st.store_whole_journal, style: Typo.meta(ar: ar).copyWith(height: 1.5)),
      const SizedBox(height: 10),
      Text(st.store_encrypted_note, textAlign: TextAlign.center, style: Typo.meta(ar: ar).copyWith(height: 1.5)),
    ]);
  }
}

/// Glyph per data category, matching `DATA_CATS`.
IconData categoryIcon(DataCategory c) => switch (c) {
      DataCategory.records => LucideIcons.folder,
      DataCategory.rx => LucideIcons.fileText,
      DataCategory.meds => LucideIcons.pill,
      DataCategory.checkins => LucideIcons.clipboardCheck,
      DataCategory.symptoms => LucideIcons.activity,
      DataCategory.vitals => LucideIcons.heartPulse,
      DataCategory.medical => LucideIcons.clipboardList,
      DataCategory.care => LucideIcons.users,
      DataCategory.appts => LucideIcons.calendar,
    };

/// Uppercase section label (`eyebrow` in `storage.jsx`).
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {required this.ar});
  final String text;
  final bool ar;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Typo.meta(ar: ar).copyWith(
          fontSize: FS.xs,
          fontWeight: FontWeight.w700,
          letterSpacing: ar ? 0 : 1.4,
          color: T.fg3,
        ),
      );
}

/// Hairline-separated rows inside one rounded outline.
class _Grouped extends StatelessWidget {
  const _Grouped({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(T.rLg),
          border: Border.all(color: T.border),
          color: Colors.white,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: T.ink100),
            children[i],
          ],
        ]),
      );
}

/// One cloud account. Unavailable, so it carries the reason rather than a
/// Connect button that would fail.
class _CloudAccountRow extends StatelessWidget {
  const _CloudAccountRow({required this.s, required this.target});
  final PatientAppState s;
  final StorageTarget target;

  @override
  Widget build(BuildContext context) {
    final st = s.strings.storage;
    final cfg = storageCfg(target);
    final available = target.isAvailable;
    return Opacity(
      opacity: available ? 1 : 0.65,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: T.ink100, borderRadius: BorderRadius.circular(T.rMd)),
              child: Icon(cfg.icon, size: 18, color: T.fg3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(target.label(st),
                    style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child:
                      Text(available ? st.store_not_connected : st.store_available_soon, style: Typo.meta(ar: s.rtl)),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            // The design's Connect button. Present but inert: an enabled
            // control here would start a flow that cannot finish.
            Pill(available ? st.store_connect : st.store_coming_soon, ar: s.rtl),
          ]),
        ),
      ),
    );
  }
}

/// One data category on the map: glyph, name, where it lives, chevron.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.s, required this.category, required this.onTap});
  final PatientAppState s;
  final DataCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st = s.strings.storage;
    final targets = syncTargetsFor(category);
    return Semantics(
      button: true,
      label: '${category.label(st)}, ${locSummary(st, targets)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(children: [
              Icon(categoryIcon(category), size: 18, color: T.fg3),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(category.label(st),
                      style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(locSummary(st, targets), style: Typo.meta(ar: s.rtl)),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              LocIcons(targets: targets, size: 22),
              const SizedBox(width: 6),
              Chevron(rtl: s.rtl),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A destination inside the editor: on, off, or not available at all.
class _StoredInRow extends StatelessWidget {
  const _StoredInRow({required this.s, required this.target, required this.on});
  final PatientAppState s;
  final StorageTarget target;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final st = s.strings.storage;
    final cfg = storageCfg(target);
    final available = target.isAvailable;
    return Opacity(
      opacity: available ? 1 : 0.65,
      child: ColoredBox(
        color: on && !target.isLocal ? cfg.bg : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? cfg.color : T.ink100,
                  borderRadius: BorderRadius.circular(T.rMd),
                ),
                child: Icon(cfg.icon, size: 18, color: on ? Colors.white : T.fg3),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(target.label(st),
                      style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      target.isLocal
                          ? st.store_local_always
                          : available
                              ? st.store_not_connected
                              : st.store_available_soon,
                      style: Typo.meta(ar: s.rtl),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              // The device row is locked in the design too — it is the one
              // copy that always exists.
              Icon(target.isLocal ? LucideIcons.lock : LucideIcons.minus, size: 16, color: T.fg3),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Overlapping location glyphs: the device, then each cloud the category syncs
/// to (`LocIcons` in `storage.jsx`).
class LocIcons extends StatelessWidget {
  const LocIcons({super.key, required this.targets, this.size = 22});
  final List<StorageTarget> targets;
  final double size;

  @override
  Widget build(BuildContext context) {
    final all = [StorageTarget.local, ...targets];
    return SizedBox(
      width: size + (all.length - 1) * (size - 6),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < all.length; i++)
            PositionedDirectional(
              // Stacked start-to-end, so the order survives in Arabic.
              start: i * (size - 6),
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: storageCfg(all[i]).bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(storageCfg(all[i]).icon, size: size * 0.55, color: storageCfg(all[i]).color),
              ),
            ),
        ],
      ),
    );
  }
}
