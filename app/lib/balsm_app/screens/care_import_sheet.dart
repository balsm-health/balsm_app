import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart';

import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import 'care_team_screen.dart';

/// Review sheet for contacts picked from the phone's address book
/// (design: `care-import.jsx`, the `initial` branch).
///
/// The OS picker is the selection surface, so this sheet's job is confirmation,
/// not browsing: it shows what was picked, proposes a type per contact that the
/// patient can correct in one tap, and marks anyone already on the team.
///
/// Two deliberate departures from `care-import.jsx`:
///
///  * The prototype's other branch renders its own address book over
///    `CI_DEMO_CONTACTS`. That is prototype sample data, and browsing contacts
///    is a surface the platform already owns — this sheet only ever lists what
///    the OS picker handed back, and adds [_EmptyPick] for the cancelled-pick
///    state the prototype cannot reach.
///  * The prototype's note says every record stays on the device. Care-team
///    records sync to the Balsm account (RR-005), so the note says that
///    instead. The design is the source of truth for the layout, not for a
///    claim about where data lives.
///
/// Carries its own chrome — grab handle, header, scroll, pinned footer —
/// because [showAppSheet] supplies only the route and the width cap, exactly as
/// `AddCareProviderSheet` does.
class CareImportSheet extends ConsumerStatefulWidget {
  const CareImportSheet({super.key});

  @override
  ConsumerState<CareImportSheet> createState() => _CareImportSheetState();
}

class _CareImportSheetState extends ConsumerState<CareImportSheet> {
  /// Drafts the patient has picked so far, newest last.
  final List<ImportedContact> _picked = [];

  /// Ids currently ticked. Everything picked starts ticked — the patient chose
  /// it in the OS picker a moment ago.
  final Set<String> _selected = {};

  /// Which row has its type chips open.
  String? _typeOpen;

  final TextEditingController _search = TextEditingController();

  bool _busy = false;

  /// Opened once on entry so the patient lands in their own contacts rather
  /// than on an empty sheet they have to act on.
  bool _openedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_openedOnce) {
        _openedOnce = true;
        _pick();
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picker = ref.read(contactPickerProvider);
    final picked = await picker.pick();
    if (picked == null || picked.isEmpty || !mounted) return;

    setState(() {
      for (final c in picked) {
        // The OS lets the same contact be chosen twice; the sheet should not
        // show it twice.
        final key = contactPhoneKey(c.phones.isEmpty ? null : c.phones.first);
        final already = _picked.any((p) =>
            p.id == c.id || (key.isNotEmpty && contactPhoneKey(p.phones.isEmpty ? null : p.phones.first) == key));
        if (already) continue;
        _picked.add(c);
        _selected.add(c.id);
      }
    });
  }

  Future<void> _import(List<CareProvider> team) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _busy) return;

    final chosen = _picked.where((c) => _selected.contains(c.id) && !c.isAlreadyOnTeam(team)).toList();
    if (chosen.isEmpty) return;

    setState(() => _busy = true);
    final result = await ref.read(importCareContactsUseCaseProvider).execute(userId: userId, contacts: chosen);
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _busy = false);
      return;
    }
    Navigator.pop(context, result.value.length);
  }

  void _setType(ImportedContact c, CareProviderType type) {
    setState(() {
      final i = _picked.indexWhere((p) => p.id == c.id);
      if (i != -1) _picked[i] = c.withType(type);
      _typeOpen = null;
    });
  }

  /// Rows matching the search box, by name or number.
  List<ImportedContact> _shown() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _picked;
    return _picked.where((c) => '${c.name} ${c.phones.join(' ')}'.toLowerCase().contains(q)).toList();
  }

  /// Ticks or clears every row the patient is still allowed to tick.
  void _toggleAll(List<ImportedContact> selectable, {required bool allOn}) {
    setState(() {
      if (allOn) {
        _selected.removeAll(selectable.map((c) => c.id));
      } else {
        _selected.addAll(selectable.map((c) => c.id));
      }
    });
    unawaited(HapticFeedback.selectionClick());
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = s.strings.care;
    final team = ref.watch(careTeamProvider).valueOrNull ?? const <CareProvider>[];
    final picker = ref.read(contactPickerProvider);

    final shown = _shown();
    // Rows the patient can still act on: anyone already on the team is shown as
    // such rather than offered again, so they are not part of "select all".
    final selectable = shown.where((p) => !p.isAlreadyOnTeam(team)).toList();
    final allOn = selectable.isNotEmpty && selectable.every((p) => _selected.contains(p.id));
    final count = _picked.where((p) => !p.isAlreadyOnTeam(team) && _selected.contains(p.id)).length;

    // A real material surface, not a decorated box: the search field is a
    // `TextField`, which asserts on a missing [Material] ancestor, and
    // `showAppSheet` supplies only the route.
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(T.rXl)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        // `.app-sheet { height: 88% }`.
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          const SheetGrab(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
            child: Row(children: [
              Expanded(
                child: Text(c.care_import_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
              ),
              RoundBtn(
                  icon: LucideIcons.x,
                  semanticLabel: s.strings.common.a11y_close,
                  ghost: true,
                  iconSize: 18,
                  onTap: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1, color: T.ink100),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(
                  picker.isAvailable ? c.care_import_note : c.care_import_unavailable,
                  style: Typo.meta(ar: s.rtl).copyWith(height: 1.5),
                ),
                const SizedBox(height: 14),
                // The design puts "choose more contacts" above the list, not under
                // it: reaching the picker again should not mean scrolling past
                // everything already picked.
                if (picker.isAvailable && _picked.isNotEmpty) ...[
                  PButton(
                    c.care_import_more,
                    icon: LucideIcons.contactRound,
                    variant: BtnVariant.secondary,
                    block: true,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: _busy ? null : _pick,
                  ),
                  const SizedBox(height: 14),
                ],
                if (_picked.isEmpty)
                  _EmptyPick(s: s, onPick: picker.isAvailable && !_busy ? _pick : null)
                else ...[
                  // The prototype searches a full address book. Here it filters
                  // what the picker returned, which earns a box once the patient
                  // has picked a screenful.
                  if (_picked.length >= 8) ...[
                    _SearchField(controller: _search, onChanged: () => setState(() {})),
                    const SizedBox(height: 12),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          c.care_import_count('${shown.length}').toUpperCase(),
                          style: Typo.meta(ar: s.rtl).copyWith(
                            fontSize: FS.xs,
                            fontWeight: FontWeight.w700,
                            letterSpacing: s.rtl ? 0 : 1.4,
                            color: T.fg3,
                          ),
                        ),
                      ),
                      if (selectable.isNotEmpty)
                        PButton(
                          allOn ? c.care_import_clear : c.care_import_select_all,
                          variant: BtnVariant.ghost,
                          accent: s.accent,
                          ar: s.rtl,
                          color: s.accent.main,
                          onTap: _busy ? null : () => _toggleAll(selectable, allOn: allOn),
                        ),
                    ]),
                  ),
                  for (final contact in shown)
                    _ContactRow(
                      s: s,
                      contact: contact,
                      onTeam: contact.isAlreadyOnTeam(team),
                      selected: _selected.contains(contact.id),
                      typeOpen: _typeOpen == contact.id,
                      onToggle: () {
                        setState(() {
                          _selected.contains(contact.id) ? _selected.remove(contact.id) : _selected.add(contact.id);
                        });
                        unawaited(HapticFeedback.selectionClick());
                      },
                      onTypeTap: () => setState(() => _typeOpen = _typeOpen == contact.id ? null : contact.id),
                      onType: (t) => _setType(contact, t),
                    ),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
                      child: Text(c.care_import_no_match, textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
                    ),
                ],
              ]),
            ),
          ),
          // Pinned footer. The CTA is the point of the sheet, so it does not
          // scroll away behind a long pick list.
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: T.ink100))),
            padding: EdgeInsets.fromLTRB(20, 12, 20, sheetBottomInset(context, base: 28)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PButton(
                count == 0 ? c.care_import_none : c.care_import_cta('$count'),
                variant: BtnVariant.primary,
                large: true,
                block: true,
                accent: s.accent,
                ar: s.rtl,
                onTap: (count == 0 || _busy) ? null : () => _import(team),
              ),
              const SizedBox(height: 6),
              PButton(
                c.care_import_manual,
                icon: LucideIcons.pencilLine,
                variant: BtnVariant.ghost,
                block: true,
                accent: s.accent,
                ar: s.rtl,
                onTap: _busy ? null : () => Navigator.pop(context, -1),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Filters the picked list by name or number (`.b-input` with a leading search
/// glyph).
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg1),
      decoration: InputDecoration(
        hintText: s.strings.care.care_import_search,
        hintStyle: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg4),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        prefixIcon: const Icon(LucideIcons.search, size: 17, color: T.fg3),
        prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: kMinTapTarget),
        border: _border(T.border),
        enabledBorder: _border(T.border),
        focusedBorder: _border(s.accent.main),
      ),
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(T.rMd),
        borderSide: BorderSide(color: c, width: 1.5),
      );
}

/// Nothing picked yet — the picker either has not opened or was cancelled.
///
/// No counterpart in `care-import.jsx`: the prototype always has its demo
/// address book to fall back on.
class _EmptyPick extends StatelessWidget {
  const _EmptyPick({required this.s, required this.onPick});
  final PatientAppState s;

  /// Null when the platform has no picker, which leaves the card as an
  /// explanation rather than a dead button.
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final c = s.strings.care;
    return PCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: s.accent.bg, shape: BoxShape.circle),
          child: Icon(LucideIcons.contactRound, size: 24, color: s.accent.main),
        ),
        const SizedBox(height: 12),
        Text(
          c.care_import_empty,
          textAlign: TextAlign.center,
          style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2),
        ),
        const SizedBox(height: 4),
        Text(
          c.care_import_empty_h,
          textAlign: TextAlign.center,
          style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3, height: 1.5),
        ),
        if (onPick != null) ...[
          const SizedBox(height: 16),
          PButton(
            c.care_import_pick,
            icon: LucideIcons.contactRound,
            variant: BtnVariant.primary,
            block: true,
            accent: s.accent,
            ar: s.rtl,
            onTap: onPick,
          ),
        ],
      ]),
    );
  }
}

/// One picked contact: tick, initials, name, number, and the type it will be
/// saved as.
///
/// A flat divider-separated row rather than a card, per `care-import.jsx` — a
/// stack of ringed cards read as ten competing surfaces. Selection shows in the
/// tick, not in the row's border.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.s,
    required this.contact,
    required this.onTeam,
    required this.selected,
    required this.typeOpen,
    required this.onToggle,
    required this.onTypeTap,
    required this.onType,
  });

  final PatientAppState s;
  final ImportedContact contact;
  final bool onTeam;
  final bool selected;
  final bool typeOpen;
  final VoidCallback onToggle;
  final VoidCallback onTypeTap;
  final ValueChanged<CareProviderType> onType;

  /// Two letters, with any doctor prefix dropped so "Dr. Sara Kamal" reads SK.
  static String _initials(String name) {
    final words = name.replaceFirst(RegExp(r'^(dr\.?|د\.)\s*', caseSensitive: false), '').trim().split(RegExp(r'\s+'));
    final first = words.isEmpty || words.first.isEmpty ? '?' : words.first[0];
    final second = words.length > 1 && words[1].isNotEmpty ? words[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = s.strings.care;
    final phone = contact.phones.isEmpty ? '' : contact.phones.first;
    final extra = contact.phones.length > 1 ? ' +${contact.phones.length - 1}' : '';
    final initials = _initials(contact.name);

    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: T.ink100))),
      child: Opacity(
        opacity: onTeam ? 0.55 : 1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Row(children: [
              Expanded(
                child: Semantics(
                  button: !onTeam,
                  checked: onTeam ? null : selected,
                  label: onTeam ? '${contact.name}, ${c.care_import_on_team}' : contact.name,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onTeam ? null : onToggle,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        if (onTeam)
                          const Icon(LucideIcons.check, size: 18, color: T.ink300)
                        else
                          _Tick(on: selected, accent: s.accent.main),
                        const SizedBox(width: 12),
                        // Neutral, not accent: the design keeps colour for the
                        // tick and the type, so ten avatars do not all shout.
                        Avatar(
                          initials: initials,
                          color: T.ink100,
                          size: 40,
                          fontSize: FS.sm,
                          ar: s.rtl,
                          child: Text(
                            initials,
                            style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1),
                              ),
                              if (phone.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      '$phone$extra',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: s.rtl ? TextAlign.right : TextAlign.left,
                                      style: Typo.meta(ar: s.rtl).copyWith(color: T.fg3),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
              if (onTeam)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: _OnTeamBadge(s: s),
                )
              // The type only matters for a row that is actually going to be
              // saved, so it rides with the tick rather than sitting on every
              // row.
              else if (selected)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: _TypeChip(s: s, type: contact.type, open: typeOpen, onTap: onTypeTap),
                ),
            ]),
          ),
          if (selected && !onTeam && typeOpen)
            Padding(
              // Indented to the name column, so the chips read as belonging to
              // this row rather than to the list.
              padding: const EdgeInsetsDirectional.only(start: 34, bottom: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in CareProviderType.values)
                    BChip(
                      careTypeLabel(c, t),
                      active: t == contact.type,
                      accent: s.accent.main,
                      ar: s.rtl,
                      onTap: () => onType(t),
                    ),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}

/// `.b-badge` — already on the team, so this row is information, not an offer.
class _OnTeamBadge extends StatelessWidget {
  const _OnTeamBadge({required this.s});
  final PatientAppState s;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: T.ink50, borderRadius: BorderRadius.circular(T.rPill)),
        child: Text(
          s.strings.care.care_import_on_team,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg3),
        ),
      );
}

/// The row's own tick. Not interactive on its own — the whole row toggles, and a
/// nested tap target inside a tappable row only creates dead zones.
class _Tick extends StatelessWidget {
  const _Tick({required this.on, required this.accent});
  final bool on;
  final Color accent;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.easeOut,
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: on ? accent : T.borderStrong, width: 1.5),
          color: on ? accent : Colors.white,
        ),
        child: on ? const Icon(LucideIcons.check, size: 14, color: Colors.white) : null,
      );
}

/// Current type, tapped to open the full set.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.s, required this.type, required this.open, required this.onTap});
  final PatientAppState s;
  final CareProviderType type;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = careTypeLabel(s.strings.care, type);
    return Semantics(
      button: true,
      expanded: open,
      label: label,
      excludeSemantics: true,
      child: MinTapTarget(
        child: Pressable(
          onTap: onTap,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(T.rPill),
              border: Border.all(color: s.accent.main),
              color: s.accent.bg,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(careTypeIcon(type), size: 13, color: s.accent.d),
              const SizedBox(width: 5),
              Text(label, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: s.accent.d)),
              const SizedBox(width: 3),
              Icon(open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 12, color: s.accent.d),
            ]),
          ),
        ),
      ),
    );
  }
}
