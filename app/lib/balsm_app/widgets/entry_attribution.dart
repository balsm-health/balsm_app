import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:profile/profile.dart';

import '../app_state.dart';
import '../kit.dart';
import '../screens/care_team_screen.dart';
import '../tokens.dart';

/// "Done by someone else" (design: `mother-child.jsx` `MCBy`, `MCByHistory`).
///
/// An entry someone other than the patient added, edited or shared — a
/// family member, a doctor, a clinic — carries an [EntryHistory]. The chip
/// names who (icon + name only) and opens the entry's edit history. The
/// patient's own entries have no history and show nothing.

/// The name to show for [actor]: "You" for the patient, the name they had
/// when they acted, or their current name in the care team. "Someone else"
/// when the care-team entry it pointed at is gone.
String attributionName(ProvenanceActor actor, PatientAppState s, List<CareProvider> team) {
  final a = s.strings.attribution;
  if (actor.isSelf) return a.you;
  if (actor.displayName case final name?) return name;
  for (final p in team) {
    if (p.id.value == actor.careProviderId) return p.name;
  }
  return a.someone;
}

/// Who an entry is shown as coming from, or null for the patient's own.
String? attributedName(WidgetRef ref, PatientAppState s, EntryHistory history) {
  final by = history.attribution;
  if (by == null) return null;
  return attributionName(by.actor, s, _teamFor(ref, history));
}

/// The care team, read only when some event names its actor by a care-team
/// reference alone.
List<CareProvider> _teamFor(WidgetRef ref, EntryHistory history) {
  final needed = history.events.any((e) => e.actor.displayName == null && e.actor.careProviderId != null);
  if (!needed) return const [];
  return ref.watch(careTeamProvider).valueOrNull ?? const [];
}

String _date(DateTime at, PatientAppState s, {required bool long}) {
  final l = at.toLocal();
  final months = (long ? s.strings.settings.cal_months : s.strings.settings.cal_months_short).split('|');
  final month = months[l.month - 1];
  return long ? '${l.day} $month ${l.year}' : '${l.day} $month';
}

/// `.mc-by` — the small pill under a record, medication or reading that
/// someone else added, edited or shared. Draws nothing for the patient's own.
class EntryAttributionChip extends ConsumerWidget {
  const EntryAttributionChip({super.key, required this.history});

  final EntryHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final by = history.attribution;
    if (by == null) return const SizedBox.shrink();
    final s = AppScope.of(context);
    final a = s.strings.attribution;
    final name = attributionName(by.actor, s, _teamFor(ref, history));
    final edited = history.wasEdited;
    final label = '${by.action == ProvenanceAction.edited ? a.edited_by(name) : a.by(name)} · '
        '${_date(by.at, s, long: false)}';
    final icon = edited
        ? LucideIcons.pencil
        : by.action == ProvenanceAction.shared
            ? LucideIcons.share2
            : LucideIcons.plus;
    return Semantics(
      button: true,
      label: a.chip_a11y(label),
      excludeSemantics: true,
      child: Pressable(
        onTap: () => showEntryHistorySheet(context, history),
        child: Container(
          constraints: const BoxConstraints(minHeight: 24),
          padding: const EdgeInsetsDirectional.fromSTEB(6, 2, 8, 2),
          decoration: BoxDecoration(color: T.hueBlue50, borderRadius: BorderRadius.circular(T.rPill)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: T.hueBlue),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.hueBlue, height: 1.3),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Opens the "Edit history" sheet for [history].
Future<void> showEntryHistorySheet(BuildContext context, EntryHistory history) {
  final s = AppScope.of(context);
  return showAppSheet<void>(context, textDirection: s.dir, builder: (_) => EntryHistorySheet(history: history));
}

/// `MCByHistory` — every event newest first, with role and date, and the
/// promise that the history can't be changed.
class EntryHistorySheet extends ConsumerWidget {
  const EntryHistorySheet({super.key, required this.history});

  final EntryHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final a = s.strings.attribution;
    final team = _teamFor(ref, history);
    final events = history.newestFirst;

    String verb(ProvenanceEvent e) {
      final self = e.actor.isSelf;
      final name = attributionName(e.actor, s, team);
      return switch (e.action) {
        ProvenanceAction.added => self ? a.you_added(s.gender) : a.added_this(name),
        ProvenanceAction.edited => self ? a.you_edited(s.gender) : a.edited_this(name),
        ProvenanceAction.shared => a.shared_this(name),
      };
    }

    String meta(ProvenanceEvent e) => [
          switch (e.actor.kind) {
            ProvenanceActorKind.self => '',
            ProvenanceActorKind.family => a.role_family,
            ProvenanceActorKind.doctor => a.role_doctor,
            ProvenanceActorKind.clinic => a.role_clinic,
          },
          _date(e.at, s, long: true),
        ].where((p) => p.isNotEmpty).join(' · ');

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        const SheetGrab(),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 8, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.history_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(a.history_sub, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
              ]),
            ),
            RoundBtn(
              icon: LucideIcons.x,
              semanticLabel: s.strings.common.a11y_close,
              ghost: true,
              iconSize: 18,
              onTap: () => Navigator.pop(context),
            ),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, sheetBottomInset(context, base: 24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...events.indexed.map((e) => _HistoryLine(
                    event: e.$2,
                    verb: verb(e.$2),
                    meta: meta(e.$2),
                    last: e.$1 == events.length - 1,
                  )),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(LucideIcons.lock, size: 13, color: T.fg3),
                const SizedBox(width: 6),
                Expanded(child: Text(a.locked, style: Typo.meta(ar: s.rtl))),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({required this.event, required this.verb, required this.meta, required this.last});

  final ProvenanceEvent event;
  final String verb;
  final String meta;
  final bool last;

  static IconData _icon(ProvenanceEvent e) => switch (e.action) {
        ProvenanceAction.edited => LucideIcons.pencil,
        ProvenanceAction.shared => LucideIcons.share2,
        ProvenanceAction.added => switch (e.actor.kind) {
            ProvenanceActorKind.self => LucideIcons.userRoundCheck,
            ProvenanceActorKind.doctor => LucideIcons.stethoscope,
            ProvenanceActorKind.clinic => LucideIcons.building2,
            ProvenanceActorKind.family => LucideIcons.userRound,
          },
      };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final self = event.actor.isSelf;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: self ? s.accent.bg : T.hueBlue50, shape: BoxShape.circle),
            child: Icon(_icon(event), size: 16, color: self ? s.accent.d : T.hueBlue),
          ),
          if (!last)
            Expanded(
              child: Container(
                width: 2,
                constraints: const BoxConstraints(minHeight: 14),
                margin: const EdgeInsetsDirectional.symmetric(vertical: 4),
                color: T.ink100,
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(verb, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
              Text(meta, style: Typo.meta(ar: s.rtl)),
            ]),
          ),
        ),
      ]),
    );
  }
}
