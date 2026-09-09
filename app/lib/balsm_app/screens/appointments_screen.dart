import 'package:appointments/appointments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/balsm_flower.dart';

/// Appointments — read-only for MVP, as in the design.
///
/// Patient-entered and on-device: there is no provider directory to book
/// against, so the screen shows what the patient recorded and points them at
/// their clinician to schedule. Consistent with `CareTeamScreen`, it never
/// fabricates a clinician.
class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final all = ref.watch(appointmentListProvider).valueOrNull ?? const <Appointment>[];
    final now = DateTime.now();
    // Soonest first reads better for a hero; history stays newest-first.
    final upcoming = all.where((a) => a.isUpcoming(now)).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final past = all.where((a) => !a.isUpcoming(now)).toList();

    return ContentColumn(
      maxWidth: 720,
      child: ListView(padding: EdgeInsets.zero, children: [
        const PadTop(),
        AppBarRow(children: [
          RoundBtn(icon: backArrow(context), onTap: () => s.setTab('home')),
          const SizedBox(width: 12),
          Expanded(child: Text(s.strings.care.appts, style: Typo.heading(ar: s.rtl))),
        ]),
        if (upcoming.isEmpty)
          const _NoUpcoming()
        else
          for (final a in upcoming) _UpcomingHero(appointment: a),
        if (past.isNotEmpty) ...[
          RowHead(s.strings.care.past_appts, ar: s.rtl),
          PCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (i, a) in past.indexed) _PastRow(appointment: a, zebra: i.isOdd),
            ]),
          ),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

/// Accent hero for the next visit, with the petal watermark from the design.
class _UpcomingHero extends StatelessWidget {
  const _UpcomingHero({required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final a = appointment;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: s.accent.main,
        borderRadius: BorderRadius.circular(T.rXl),
        boxShadow: s.accent.boxShadow,
      ),
      child: Stack(children: [
        const PositionedDirectional(
          top: -20,
          end: -20,
          child: Opacity(
            opacity: 0.12,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
              child: BalsmFlower(size: 120),
            ),
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.strings.care.upcoming_appt.toUpperCase(),
              style: Typo.eyebrow(Colors.white.withValues(alpha: 0.85), ar: s.rtl)),
          const SizedBox(height: 14),
          Row(children: [
            Avatar(
              initials: _initials(a.clinician),
              color: Colors.white.withValues(alpha: 0.22),
              size: 52,
              fontSize: FS.lg,
              ar: s.rtl,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.clinician,
                    style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                if (a.specialty != null && a.specialty!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(a.specialty!,
                        style: Typo.bodySm(ar: s.rtl).copyWith(color: Colors.white.withValues(alpha: 0.85))),
                  ),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _HeroFact(icon: LucideIcons.calendar, label: formatAppointmentDate(a.startsAt, s)),
            const SizedBox(width: 20),
            _HeroFact(icon: LucideIcons.clock, label: formatAppointmentTime(a.startsAt)),
          ]),
          if (a.location != null && a.location!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _HeroFact(icon: LucideIcons.mapPin, label: a.location!, dim: true, iconSize: 13),
          ],
          const SizedBox(height: 18),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Material(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(T.rMd),
              child: InkWell(
                borderRadius: BorderRadius.circular(T.rMd),
                onTap: () => _addToCalendar(a),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(T.rMd),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(LucideIcons.calendarPlus, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(s.strings.settings.add_calendar,
                        style: Typo.bodySm(ar: s.rtl).copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.icon, required this.label, this.dim = false, this.iconSize = 14});
  final IconData icon;
  final String label;
  final bool dim;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final color = Colors.white.withValues(alpha: dim ? 0.78 : 0.92);
    return Flexible(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: iconSize, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dim ? Typo.meta(ar: s.rtl) : Typo.bodySm(ar: s.rtl)).copyWith(color: color)),
        ),
      ]),
    );
  }
}

class _NoUpcoming extends StatelessWidget {
  const _NoUpcoming();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(children: [
        const Icon(LucideIcons.calendarHeart, size: 36, color: T.fg4),
        const SizedBox(height: 14),
        Text(s.strings.common.no_appts,
            textAlign: TextAlign.center,
            style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
        const SizedBox(height: 8),
        Text(s.strings.care.book_via_doctor, textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
      ]),
    );
  }
}

class _PastRow extends StatelessWidget {
  const _PastRow({required this.appointment, required this.zebra});
  final Appointment appointment;
  final bool zebra;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final a = appointment;
    return Container(
      color: zebra ? T.ink50 : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Avatar(
            initials: _UpcomingHero._initials(a.clinician), color: T.petalAqua, size: 36, fontSize: FS.sm, ar: s.rtl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.clinician,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            Text('${formatAppointmentDate(a.startsAt, s)} · ${formatAppointmentTime(a.startsAt)}',
                style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ]),
        ),
        const SizedBox(width: 8),
        Pill(
          a.kind == AppointmentKind.followUp ? s.strings.care.follow_up : s.strings.care.check_up,
          kind: PillKind.neutral,
          dot: false,
          small: true,
          ar: s.rtl,
        ),
      ]),
    );
  }
}

Future<void> _addToCalendar(Appointment a) async {
  String stamp(DateTime d) {
    final u = d.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  final start = a.startsAt;
  final end = start.add(const Duration(hours: 1));
  final uri = Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': a.clinician,
    'dates': '${stamp(start)}/${stamp(end)}',
    if (a.location != null && a.location!.isNotEmpty) 'location': a.location!,
  });
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// Localized via i69n `settings.cal_months` (was a hardcoded EN/AR ternary;
// CODING_STANDARDS: no inline bilingual ternaries) — the same bundle key the
// date pickers in auth_flow.dart / personal_details.dart already use.
String formatAppointmentDate(DateTime d, PatientAppState s) {
  final months = s.strings.settings.cal_months.split('|');
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')} ${months[l.month - 1]} ${l.year}';
}

String formatAppointmentTime(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}
