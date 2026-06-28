import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../data.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/badges.dart';

/// Appointments sub-screen (appointments.jsx) — read-only for MVP.
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final upcoming = kAppointments.where((a) => a.status == 'upcoming').toList();
    final past = kAppointments.where((a) => a.status == 'past').toList();
    return ContentColumn(maxWidth: 720, child: ListView(padding: EdgeInsets.zero, children: [
      const PadTop(),
      AppBarRow(
        leading: RoundBtn(icon: LucideIcons.arrowLeft, onTap: () => s.setTab('home')),
        children: [Expanded(child: Text(s.t('appts'), style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl)))],
      ),
      if (upcoming.isNotEmpty)
        for (final a in upcoming) _UpcomingCard(appt: a)
      else
        PCard(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(children: [
            const Icon(LucideIcons.calendar, size: 36, color: T.fg4),
            const SizedBox(height: 14),
            Text(s.t('no_appts'), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
            const SizedBox(height: 8),
            Text(s.t('book_via_doctor'), textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
          ]),
        ),
      if (past.isNotEmpty) ...[
        RowHead(s.t('past_appts'), ar: s.rtl),
        PCard(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            for (var i = 0; i < past.length; i++) _PastRow(appt: past[i], first: i == 0),
          ]),
        ),
      ],
      const SizedBox(height: 24),
    ]));
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.appt});
  final Appointment appt;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final doc = doctorById(appt.doctorId);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: s.accent.main, borderRadius: BorderRadius.circular(T.rXl), boxShadow: s.accent.boxShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.t('upcoming_appt').toUpperCase(), style: Typo.eyebrow(const Color(0xD9FFFFFF), ar: s.rtl).copyWith(fontSize: FS.xs, letterSpacing: s.rtl ? 0 : 0.7)),
        const SizedBox(height: 14),
        Row(children: [
          if (doc != null) DoctorAvatar(doctor: doc, size: 52),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc?.name.of(s.lang) ?? '', style: Typo.subhead(ar: s.rtl).copyWith(color: Colors.white)),
            const SizedBox(height: 2),
            Text(doc?.specialty.of(s.lang) ?? '', style: Typo.bodySm(ar: s.rtl).copyWith(color: const Color(0xD9FFFFFF))),
          ]),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _info(LucideIcons.calendar, appt.date.of(s.lang), s),
          const SizedBox(width: 20),
          _info(LucideIcons.clock, appt.time, s),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(LucideIcons.mapPin, size: 13, color: Color(0xC7FFFFFF)),
          const SizedBox(width: 6),
          Expanded(child: Text(appt.location.of(s.lang), style: Typo.meta(ar: s.rtl).copyWith(color: const Color(0xC7FFFFFF)))),
        ]),
        const SizedBox(height: 18),
        Container(
          height: 42, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0x2EFFFFFF), borderRadius: BorderRadius.circular(T.rMd), border: Border.all(color: const Color(0x47FFFFFF))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.calendarPlus, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(s.t('add_calendar'), style: Typo.bodySm(ar: s.rtl).copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  Widget _info(IconData icon, String text, PatientAppState s) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: const Color(0xEBFFFFFF)),
        const SizedBox(width: 6),
        Text(text, style: Typo.bodySm(ar: s.rtl).copyWith(color: const Color(0xEBFFFFFF))),
      ]);
}

class _PastRow extends StatelessWidget {
  const _PastRow({required this.appt, required this.first});
  final Appointment appt;
  final bool first;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final doc = doctorById(appt.doctorId);
    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: T.ink100))),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        if (doc != null) DoctorAvatar(doctor: doc, size: 42),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(doc?.name.of(s.lang) ?? '', style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
          Text('${appt.date.of(s.lang)} · ${appt.time}', style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
        ])),
        Pill(s.t(appt.type == 'follow-up' ? 'follow_up' : 'check_up'), kind: PillKind.neutral, dot: false, ar: s.rtl),
      ]),
    );
  }
}
