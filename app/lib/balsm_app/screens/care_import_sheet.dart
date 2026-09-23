import 'package:core/core.dart';
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
/// Carries its own chrome — grab handle, header, scroll — because
/// [showAppSheet] supplies only the route and the width cap, exactly as
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

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = s.strings.care;
    final team = ref.watch(careTeamProvider).valueOrNull ?? const <CareProvider>[];
    final picker = ref.read(contactPickerProvider);

    final selectable = _picked.where((p) => !p.isAlreadyOnTeam(team)).toList();
    final count = selectable.where((p) => _selected.contains(p.id)).length;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        const SheetGrab(),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
          child: Row(children: [
            Expanded(
              child: Text(c.care_import_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
            ),
            RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 18, onTap: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1, color: T.ink100),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 14, 20, sheetBottomInset(context, base: 32)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                picker.isAvailable ? c.care_import_note : c.care_import_unavailable,
                style: Typo.meta(ar: s.rtl).copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
              if (_picked.isEmpty)
                _EmptyPick(s: s, onPick: picker.isAvailable && !_busy ? _pick : null)
              else ...[
                for (final contact in _picked) ...[
                  _ContactRow(
                    s: s,
                    contact: contact,
                    onTeam: contact.isAlreadyOnTeam(team),
                    selected: _selected.contains(contact.id),
                    typeOpen: _typeOpen == contact.id,
                    onToggle: () => setState(() {
                      _selected.contains(contact.id) ? _selected.remove(contact.id) : _selected.add(contact.id);
                    }),
                    onTypeTap: () => setState(() => _typeOpen = _typeOpen == contact.id ? null : contact.id),
                    onType: (t) => _setType(contact, t),
                  ),
                  const SizedBox(height: 10),
                ],
                if (picker.isAvailable)
                  PButton(
                    c.care_import_more,
                    icon: LucideIcons.contactRound,
                    variant: BtnVariant.secondary,
                    block: true,
                    accent: s.accent,
                    ar: s.rtl,
                    onTap: _busy ? null : _pick,
                  ),
              ],
              const SizedBox(height: 18),
              PButton(
                count == 0 ? c.care_import_none : c.care_import_cta('$count'),
                variant: BtnVariant.primary,
                block: true,
                accent: s.accent,
                ar: s.rtl,
                onTap: (count == 0 || _busy) ? null : () => _import(team),
              ),
              const SizedBox(height: 8),
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
        ),
      ]),
    );
  }
}

/// Nothing picked yet — the picker either has not opened or was cancelled.
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
/// The whole card toggles, so the tick is a target rather than the only one —
/// a 22px box is a poor tap area on a phone.
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

    return Opacity(
      opacity: onTeam ? 0.55 : 1,
      child: PCard(
        padding: const EdgeInsets.all(12),
        // A ticked row is ringed in the accent, the same selected-row language
        // the records list uses.
        border: !onTeam && selected ? s.accent.main : null,
        onTap: onTeam ? null : onToggle,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (onTeam)
              const Icon(LucideIcons.check, size: 18, color: T.ink300)
            else
              _Tick(on: selected, accent: s.accent.main),
            const SizedBox(width: 12),
            Avatar(
              initials: _initials(contact.name),
              color: onTeam ? T.ink300 : s.accent.main,
              size: 40,
              fontSize: FS.sm,
              ar: s.rtl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1),
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
                        style: Typo.meta(ar: s.rtl).copyWith(color: T.fg3),
                      ),
                    ),
                  ),
              ]),
            ),
            if (onTeam) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  c.care_import_on_team,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Typo.meta(ar: s.rtl).copyWith(color: T.fg3, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ]),
          // The type only matters for a row that is actually going to be
          // saved, so it appears with the tick rather than on every row.
          if (selected && !onTeam) ...[
            const SizedBox(height: 10),
            Align(
              alignment: s.rtl ? Alignment.centerRight : Alignment.centerLeft,
              child: _TypeChip(s: s, type: contact.type, open: typeOpen, onTap: onTypeTap),
            ),
            if (typeOpen)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
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
          ],
        ]),
      ),
    );
  }
}

/// The card's own tick. Not interactive on its own — the whole card toggles,
/// and a nested tap target inside a tappable card only creates dead zones.
class _Tick extends StatelessWidget {
  const _Tick({required this.on, required this.accent});
  final bool on;
  final Color accent;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.easeOut,
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: on ? accent : T.ink300, width: 1.5),
          color: on ? accent : Colors.white,
        ),
        child: on ? const Icon(LucideIcons.check, size: 13, color: Colors.white) : null,
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
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(T.rPill),
            border: Border.all(color: s.accent.main.withValues(alpha: 0.45), width: 1.5),
            color: s.accent.bg,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(careTypeIcon(type), size: 14, color: s.accent.d),
            const SizedBox(width: 6),
            Text(
              careTypeLabel(s.strings.care, type),
              style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: s.accent.d),
            ),
            const SizedBox(width: 4),
            Icon(open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 13, color: s.accent.d),
          ]),
        ),
      );
}
