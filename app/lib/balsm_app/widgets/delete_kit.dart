import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';

/// The shared delete pattern — port of the Claude Design `delete-kit.jsx`:
/// a row swipes toward the start edge to reveal Delete, its `⋮` opens a
/// one-item menu, Select ticks several rows, every path asks in a dialog, and
/// a short notice confirms. Used by the day's readings, medications and
/// prescriptions.
///
/// Mix into the screen's [State]; [K] identifies what a tick selects. Wrap
/// the screen body in a [Stack] and add [deleteKitOverlays] last.
mixin DeleteKit<W extends StatefulWidget, K> on State<W> {
  static const _toastFor = Duration(milliseconds: 2500);

  /// The row swiped open. Rows key it themselves, so two rows for the same
  /// item (a medication's morning and evening dose) open one at a time.
  Object? swipeOpen;
  bool selecting = false;
  final Set<K> selected = {};
  String? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void startSelect([K? first]) => setState(() {
        swipeOpen = null;
        selecting = true;
        selected
          ..clear()
          ..addAll([if (first != null) first]);
      });

  void endSelect() => setState(() {
        selecting = false;
        selected.clear();
      });

  void toggleSelected(K k) => setState(() => selected.contains(k) ? selected.remove(k) : selected.add(k));

  /// Asks with [title] and [body]. On Delete, closes any swipe and Select,
  /// runs [onConfirmed], then shows "[done] deleted". False on Cancel.
  Future<bool> confirmDelete({
    required String title,
    required String body,
    required String done,
    required FutureOr<void> Function() onConfirmed,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x6114202B),
      builder: (_) => ConfirmDeleteDialog(title: title, body: body),
    );
    if (!mounted) return false;
    if (ok != true) {
      setState(() => swipeOpen = null);
      return false;
    }
    setState(() {
      swipeOpen = null;
      selecting = false;
      selected.clear();
    });
    await onConfirmed();
    if (mounted) showDeleted(done);
    return true;
  }

  /// Shows "[what] deleted" for a moment — also for a delete confirmed on
  /// another screen, such as an item's detail page.
  void showDeleted(String what) {
    _toastTimer?.cancel();
    setState(() => _toast = AppScope.of(context).strings.common.del_done(what));
    _toastTimer = Timer(_toastFor, () {
      if (mounted) setState(() => _toast = null);
    });
  }

  /// The `⋮` popover under [button], aligned to its end edge, with one
  /// Delete item ([label] overrides its text). True when Delete was picked.
  Future<bool> openDeleteMenu(BuildContext button, {String? label}) async {
    setState(() => swipeOpen = null);
    final s = AppScope.of(context);
    final box = button.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final x = s.rtl ? rect.left : rect.right;
    final picked = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromLTRB(x, rect.bottom + 4, overlay.size.width - x, overlay.size.height - rect.bottom),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: const Color(0x3314202B),
      menuPadding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 184),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.rLg),
        side: const BorderSide(color: T.ink100),
      ),
      popUpAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 120), curve: Motion.easeOut),
      items: [
        PopupMenuItem<bool>(
          value: true,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            const Icon(LucideIcons.trash2, size: 18, color: T.danger),
            const SizedBox(width: 10),
            Text(label ?? s.strings.common.del,
                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.danger)),
          ]),
        ),
      ],
    );
    return picked == true;
  }

  /// A swipeable row for [item]. [rowKey] tells rows apart when one item has
  /// several (defaults to [item]).
  Widget kitSwipe({
    required K item,
    Object? rowKey,
    required String label,
    required VoidCallback onDelete,
    double radius = 0,
    required Widget child,
  }) {
    final key = rowKey ?? item;
    return SwipeRow(
      open: swipeOpen == key,
      radius: radius,
      deleteLabel: AppScope.of(context).strings.common.del,
      selecting: selecting,
      selected: selected.contains(item),
      label: label,
      onOpen: () => setState(() => swipeOpen = key),
      onClose: () => setState(() => swipeOpen = swipeOpen == key ? null : swipeOpen),
      onDelete: onDelete,
      onLongPress: () => startSelect(item),
      onToggle: () => toggleSelected(item),
      child: child,
    );
  }

  /// The tick box leading a row while selecting; nothing otherwise.
  Widget kitCheck(K item) => selecting
      ? Padding(
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: SelectCheck(on: selected.contains(item)),
        )
      : const SizedBox.shrink();

  /// The row's `⋮`, hidden while selecting. [onDelete] runs when its menu's
  /// Delete is picked.
  Widget kitMore({required String label, required VoidCallback onDelete, String? menuLabel}) => selecting
      ? const SizedBox(width: 8)
      : RowMoreButton(
          label: label,
          onTap: (button) async {
            if (await openDeleteMenu(button, label: menuLabel)) onDelete();
          },
        );

  /// Design `selectButton`: a round list-checks button that starts Select.
  Widget kitSelectButton() => RoundBtn(
        icon: LucideIcons.listChecks,
        semanticLabel: AppScope.of(context).strings.common.del_select,
        iconSize: 19,
        onTap: () => startSelect(),
      );

  /// Design `selectAppbar`: close, "N selected", Select all / Clear all.
  Widget kitSelectAppBar(Iterable<K> all, {String? title}) {
    final s = AppScope.of(context);
    final c = s.strings.common;
    final allOn = all.isNotEmpty && all.every(selected.contains);
    return AppBarRow(children: [
      RoundBtn(icon: LucideIcons.x, semanticLabel: c.del_select_done, onTap: endSelect),
      const SizedBox(width: 12),
      Expanded(
        child: Semantics(
          liveRegion: true,
          child: Text(
            selected.isEmpty ? (title ?? c.del_select_items) : c.del_selected(selected.length),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Typo.heading(ar: s.rtl),
          ),
        ),
      ),
      PButton(allOn ? c.del_clear_all : c.del_select_all,
          variant: BtnVariant.ghost,
          size: BtnSize.sm,
          ar: s.rtl,
          onTap: () => setState(() {
                if (allOn) {
                  selected.clear();
                } else {
                  selected.addAll(all);
                }
              })),
    ]);
  }

  /// Room to leave under a list so the bar and the notice never cover its
  /// last row.
  double get kitBottomRoom => selecting ? 104 : 28;

  /// The selection bar and the "deleted" notice, for the end of the screen's
  /// [Stack]. [count] names n ticked items ("2 medications").
  List<Widget> deleteKitOverlays({required String Function(int n) count, required VoidCallback onDeleteSelected}) {
    final s = AppScope.of(context);
    final c = s.strings.common;
    final toast = _toast;
    return [
      if (selecting)
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: SelectionBar(
            label: selected.isEmpty ? c.del : c.del_n(count(selected.length)),
            onDelete: selected.isEmpty ? null : onDeleteSelected,
          ),
        ),
      if (toast != null)
        PositionedDirectional(
          start: 16,
          end: 16,
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
          child: DoneToast(text: toast),
        ),
    ];
  }
}

/// Design `SwipeRow`: dragging toward the start edge reveals Delete; a swipe
/// past half the width asks to delete at once. Long-press starts Select; while
/// selecting, a tap toggles the row instead.
class SwipeRow extends StatefulWidget {
  const SwipeRow({
    super.key,
    required this.open,
    required this.radius,
    required this.deleteLabel,
    required this.selecting,
    required this.selected,
    required this.label,
    required this.onOpen,
    required this.onClose,
    required this.onDelete,
    required this.onLongPress,
    required this.onToggle,
    required this.child,
  });
  final bool open;
  final double radius;
  final String deleteLabel;
  final bool selecting;
  final bool selected;
  final String label;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;
  final VoidCallback onToggle;
  final Widget child;

  @override
  State<SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<SwipeRow> {
  static const _reveal = 88.0;

  /// Signed offset while a finger is down; null when the row rests.
  double? _drag;
  double _base = 0;
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // The row slides toward the start edge: left in English, right in Arabic.
    final dir = Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;
    final rest = widget.open ? dir * _reveal : 0.0;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final content = TweenAnimationBuilder<double>(
        tween: Tween(end: _drag ?? rest),
        duration: _drag != null ? Duration.zero : const Duration(milliseconds: 200),
        curve: Motion.easeOut,
        builder: (context, offset, child) {
          final amt = math.max(0.0, offset * dir);
          return Stack(children: [
            if (amt > 0)
              PositionedDirectional(
                top: 0,
                bottom: 0,
                end: 0,
                width: math.max(_reveal, amt),
                child: ExcludeSemantics(
                  child: GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      color: T.danger,
                      alignment: Alignment.center,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(LucideIcons.trash2, size: 20, color: Colors.white),
                        const SizedBox(height: 4),
                        Text(widget.deleteLabel,
                            style: Typo.meta(ar: s.rtl)
                                .copyWith(fontSize: FS.xs, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
              ),
            // While open or selecting, the row's own taps (open a dose, a
            // prescription) wait; the revealed Delete stays live.
            Transform.translate(
              offset: Offset(offset, 0),
              child: widget.open || widget.selecting ? AbsorbPointer(child: child) : child,
            ),
          ]);
        },
        child: widget.child,
      );
      final row = widget.selecting
          ? Semantics(
              checked: widget.selected,
              label: widget.label,
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onToggle, child: content),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.open ? widget.onClose : null,
              onLongPress: widget.onLongPress,
              onHorizontalDragStart: (_) {
                _base = rest;
                _dx = 0;
                setState(() => _drag = rest);
              },
              onHorizontalDragUpdate: (e) {
                _dx += e.delta.dx;
                setState(() => _drag = ((_base + _dx) * dir).clamp(0.0, w) * dir);
              },
              onHorizontalDragEnd: (_) => _settle(w),
              onHorizontalDragCancel: () => _settle(w),
              child: content,
            );
      return ClipRRect(borderRadius: BorderRadius.circular(widget.radius), child: row);
    });
  }

  void _settle(double w) {
    final a = (_drag ?? 0).abs();
    setState(() => _drag = null);
    if (a > w * 0.5) {
      widget.onDelete();
    } else if (a > _reveal / 2) {
      widget.onOpen();
    } else {
      widget.onClose();
    }
  }
}

/// Design `Check`: a row's tick box while selecting.
class SelectCheck extends StatelessWidget {
  const SelectCheck({super.key, required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Motion.easeOut,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: on ? AccentScope.of(context).main : Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: on ? null : Border.all(color: T.ink300, width: 2),
        ),
        child: on ? const Icon(LucideIcons.check, size: 16, color: Colors.white) : null,
      );
}

/// Design `More`: a row's `⋮`. Hands [onTap] its own context so the menu can
/// open under it.
class RowMoreButton extends StatelessWidget {
  const RowMoreButton({super.key, required this.label, required this.onTap});
  final String label;
  final void Function(BuildContext button) onTap;

  @override
  Widget build(BuildContext context) => RoundBtn(
        icon: LucideIcons.ellipsisVertical,
        semanticLabel: AppScope.of(context).strings.common.del_options(label),
        ghost: true,
        iconSize: 18,
        fg: T.fg3,
        onTap: () => onTap(context),
      );
}

/// Design's delete alert: what goes and what it means, then Delete or
/// Cancel. Pops `true` to delete.
class ConfirmDeleteDialog extends StatelessWidget {
  const ConfirmDeleteDialog({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(T.rXl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child:
                  IconSquare(LucideIcons.trash2, bg: T.dangerBg, fg: T.danger, size: 44, iconSize: 22, radius: T.rMd),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1, height: 1.35)),
            const SizedBox(height: 6),
            Text(body, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg2, height: 1.5)),
            const SizedBox(height: 20),
            PButton(s.strings.common.del,
                variant: BtnVariant.danger,
                large: true,
                block: true,
                ar: s.rtl,
                onTap: () => Navigator.pop(context, true)),
            const SizedBox(height: 10),
            PButton(s.strings.common.cancel,
                variant: BtnVariant.secondary,
                large: true,
                block: true,
                ar: s.rtl,
                onTap: () => Navigator.pop(context, false)),
          ]),
        ),
      ),
    );
  }
}

/// Pinned under the list while selecting; disabled until a row is ticked.
class SelectionBar extends StatelessWidget {
  const SelectionBar({super.key, required this.label, required this.onDelete});
  final String label;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: T.ink100)),
        boxShadow: [BoxShadow(color: Color(0x0F14202B), offset: Offset(0, -6), blurRadius: 18)],
      ),
      child: PButton(label,
          icon: LucideIcons.trash2, variant: BtnVariant.danger, large: true, block: true, ar: s.rtl, onTap: onDelete),
    );
  }
}

/// Design's dark "deleted" notice, announced to screen readers as it appears.
class DoneToast extends StatelessWidget {
  const DoneToast({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: T.ink800, borderRadius: BorderRadius.circular(T.rLg), boxShadow: T.shadowLg),
        child: Row(children: [
          const Icon(LucideIcons.check, size: 17, color: T.hueMint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}
