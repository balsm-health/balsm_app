import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../kit.dart';
import '../screens/storage_sheet.dart';
import '../storage_target.dart';
import '../tokens.dart';

/// Header pill naming where this screen's data is kept, tapped to see or change
/// it (`DataLocPill` in `storage.jsx`).
///
/// It reports what is true rather than what is configured: [syncTargetsFor]
/// returns only destinations that can actually hold a copy, which today is none
/// of the clouds — so the pill reads "Device" and the sheet behind it explains
/// why. See `storage_sheet.dart` for the gate.
class DataLocPill extends StatelessWidget {
  const DataLocPill({super.key, required this.category});
  final DataCategory category;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final st = s.strings.storage;
    final targets = syncTargetsFor(category);
    final label = switch (targets.length) {
      0 => st.store_device,
      1 => targets.first.label(st),
      _ => st.store_places('${targets.length + 1}'),
    };

    return Semantics(
      button: true,
      label: '${st.store_loc_label}: ${locSummary(st, targets)}',
      excludeSemantics: true,
      child: MinTapTarget(
        child: Pressable(
          onTap: () => showAppSheet<void>(
            context,
            textDirection: s.dir,
            builder: (_) => _WhereSheet(s: s, category: category),
          ),
          child: Container(
            height: 34,
            padding: const EdgeInsetsDirectional.only(start: 5, end: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(T.rPill),
              border: Border.all(color: T.border),
              color: Colors.white,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              LocIcons(targets: targets, size: 24),
              const SizedBox(width: 6),
              Text(label, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The pill's sheet: one category's storage, with its own chrome because
/// [showAppSheet] supplies only the route.
class _WhereSheet extends StatelessWidget {
  const _WhereSheet({required this.s, required this.category});
  final PatientAppState s;
  final DataCategory category;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(T.rXl)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            const SheetGrab(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
              child: Row(children: [
                const Icon(LucideIcons.hardDrive, size: 19, color: T.fg3),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(s.strings.storage.store_where,
                      style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
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
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, sheetBottomInset(context, base: 32)),
                child: CategorySyncBody(s: s, category: category),
              ),
            ),
          ]),
        ),
      );
}
