import 'package:core/core.dart' show accountSummaryProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../data.dart';
import '../kit.dart';
import '../responsive.dart';
import '../tokens.dart';
import '../widgets/mood_face.dart';
import '../widgets/account_switcher.dart';
import 'personal_details.dart';
import 'profile_subscreens.dart';
import 'report_flow.dart';

/// Home tab — faithful port of `home.jsx` HomeScreen.
///
/// Carries the onboarding nudges from the folded `modules/home`: claim handle
/// (real — hidden once the account summary has a handle), emergency card and
/// first medication (placeholder-gated until sibling modules expose
/// completion flags). T173 locale refresh lives in `main_patient.dart`.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final lang = s.lang;
    final checkedIn = s.today != null;
    final cur = s.today ??
        CheckinResult(bp: kHistory[0].bp, glu: kHistory[0].glu, mood: kHistory[0].mood, pain: kHistory[0].pain);
    final moodLbl = cur.mood != null ? s.t('mood_${cur.mood}') : '—';

    final nextAppt = kAppointments.where((a) => a.status == 'upcoming').cast<Appointment?>().firstOrNull;
    final apptDoc = nextAppt != null ? doctorById(nextAppt.doctorId) : null;

    return ContentColumn(
      maxWidth: 720,
      child: ListView(
      padding: EdgeInsets.zero,
      children: [
        const PadTop(),

        // App bar: avatar + greeting + bell
        AppBarRow(children: [
          _AvatarButton(onTap: () => showAccountSwitcher(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.t('greet'), style: Typo.meta(ar: s.rtl)),
              Text(s.account.name.of(lang).split(' ').first,
                  style: Typo.heading(ar: s.rtl).copyWith(fontSize: FS.xl)),
            ]),
          ),
          RoundBtn(icon: LucideIcons.bell, onTap: () {}),
        ]),

        // Travel banner (only when away from home country)
        if (!s.country.home) _TravelBanner(),

        // Hero check-in
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: checkedIn ? _HeroDone() : _HeroCheckin(),
        ),

        // Onboarding nudges (from the folded modules/home). Handle nudge is
        // driven by the real account summary; the other two are shown until
        // sibling modules expose completion flags.
        const _NudgeSection(),

        // Upcoming appointment strip
        if (nextAppt != null && apptDoc != null)
          PCard(
            margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            onTap: () => s.setTab('appts'),
            child: Row(children: [
              IconSquare(LucideIcons.calendar, bg: s.accent.bg, fg: s.accent.main),
              const SizedBox(width: 13),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.t('upcoming_appt').toUpperCase(),
                      style: Typo.eyebrow(s.accent.main, ar: s.rtl).copyWith(fontSize: FS.xs2, letterSpacing: s.rtl ? 0 : 0.8)),
                  const SizedBox(height: 2),
                  Text('${apptDoc.name.of(lang)} · ${nextAppt.date.of(lang)} ${nextAppt.time}',
                      style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
                ]),
              ),
              Chevron(rtl: s.rtl),
            ]),
          ),

        // Streak
        PCard(
          margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            RingProgress(progress: 6 / 7, color: s.accent.main, label: '6'),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('6', style: Typo.num(size: FS.md, weight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Text(s.t('streak'), style: Typo.subhead(ar: s.rtl).copyWith(fontSize: FS.md)),
                ]),
                const SizedBox(height: 2),
                Text(s.t('streak_help'), style: Typo.meta(ar: s.rtl)),
              ]),
            ),
            const Icon(LucideIcons.flame, size: 24, color: T.sun500),
          ]),
        ),

        // Nearby care shortcut
        _Shortcut(
          icon: LucideIcons.mapPin, iconBg: T.petalBlue50, iconFg: T.petalBlue,
          title: s.t('map_nearby'),
          subtitle: '${kHealthEntities.length} ${lang == 'ar' ? 'مكان بالقرب منك' : 'places mapped nearby'}',
          onTap: () => s.setTab('map'),
        ),

        // Health records shortcut
        _Shortcut(
          icon: LucideIcons.folderHeart, iconBg: T.petalViolet50, iconFg: T.petalViolet,
          title: s.t('records'),
          subtitle: '${kHealthRecords.length} ${lang == 'ar' ? 'مستند' : 'documents'}',
          onTap: () => s.setTab('records'),
        ),

        // Latest readings
        RowHead(s.t('latest'), ar: s.rtl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _MetricGrid(cur: cur, moodLbl: moodLbl),
        ),

        // Today's medications
        RowHead(s.t('meds_today'), action: s.t('see_all'), onAction: () => s.setTab('meds'), ar: s.rtl),
        PCard(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            for (var i = 0; i < kMeds.length; i++)
              _MedRow(med: kMeds[i], done: checkedIn || i == 0, first: i == 0),
          ]),
        ),

        // Recent reports
        RowHead(s.t('recent'), action: s.t('see_all'), onAction: () => s.setTab('trends'), ar: s.rtl),
        PCard(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            for (var i = 0; i < 3; i++) HistoryRow(h: kHistory[i], onTap: () => s.setTab('trends'), first: i == 0),
          ]),
        ),

        const SizedBox(height: 24),
      ],
      ),
    );
  }
}

/// Onboarding nudge cards. Rendered in the home's own `_Shortcut` language;
/// gating logic ported from the folded `modules/home` dashboard.
class _NudgeSection extends ConsumerWidget {
  const _NudgeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    // Real signal: hide the handle nudge once the account has one. While the
    // summary is loading/errored, stay quiet rather than flash a wrong nudge.
    final summary = ref.watch(accountSummaryProvider).valueOrNull;
    final needsHandle =
        ref.watch(accountSummaryProvider).hasValue && summary?.handle == null;
    // Owned by sibling modules; offered until they expose completion flags.
    const needsEmergencyCard = true;
    const needsFirstMedication = true;

    return Column(children: [
      if (needsHandle)
        _Shortcut(
          icon: LucideIcons.atSign,
          iconBg: T.petalMint50,
          iconFg: T.petalMint,
          title: s.t('nudge_handle'),
          subtitle: s.t('nudge_handle_sub'),
          onTap: () => openPersonalDetails(context),
        ),
      if (needsEmergencyCard)
        _Shortcut(
          icon: LucideIcons.shieldAlert,
          iconBg: T.petalAqua50,
          iconFg: T.petalAqua,
          title: s.t('nudge_ec'),
          subtitle: s.t('nudge_ec_sub'),
          onTap: () => openEmergency(context),
        ),
      if (needsFirstMedication)
        _Shortcut(
          icon: LucideIcons.pill,
          iconBg: T.petalViolet50,
          iconFg: T.petalViolet,
          title: s.t('nudge_med'),
          subtitle: s.t('nudge_med_sub'),
          onTap: () => s.setTab('meds'),
        ),
    ]);
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Pressable(
      onTap: onTap,
      scale: 0.95,
      child: Stack(clipBehavior: Clip.none, children: [
        Avatar(initials: s.account.initials, color: s.account.color, ar: s.rtl),
        if (kFamilyAccounts.length > 1)
          Positioned(
            right: -1, bottom: -1,
            child: Container(
              width: 14, height: 14,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Center(
                child: Container(width: 8, height: 8, decoration: BoxDecoration(color: s.accent.main, shape: BoxShape.circle)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _TravelBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: T.sun500, borderRadius: BorderRadius.circular(T.rLg)),
      child: Row(children: [
        const Icon(LucideIcons.plane, size: 20, color: Color(0xFF3A2E05)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s.t('away_banner')} · ${s.country.name.of(s.lang)}',
                style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF3A2E05))),
            Text('${s.t('emergency')} ${s.country.emergency}',
                style: Typo.meta(ar: s.rtl).copyWith(color: const Color(0xCC3A2E05))),
          ]),
        ),
      ]),
    );
  }
}

class _HeroCheckin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: s.accent.main, borderRadius: BorderRadius.circular(T.rXl), boxShadow: s.accent.boxShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.t('today_lbl'), style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: const Color(0xE6FFFFFF))),
        const SizedBox(height: 2),
        Text(s.t('hero_q'),
            style: Typo.title(ar: s.rtl).copyWith(fontSize: FS.xl2, color: Colors.white)),
        const SizedBox(height: 14),
        Pressable(
          onTap: () => openCheckin(context),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(T.rMd)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.plusCircle, size: 20, color: s.accent.d),
              const SizedBox(width: 8),
              Text(s.t('hero_cta'),
                  style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: s.accent.d)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(LucideIcons.clock, size: 15, color: Color(0xE6FFFFFF)),
          const SizedBox(width: 6),
          Text(s.t('hero_time'), style: Typo.bodySm(ar: s.rtl).copyWith(color: const Color(0xE6FFFFFF))),
        ]),
      ]),
    );
  }
}

class _HeroDone extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PCard(
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Container(width: 52, height: 52,
            decoration: const BoxDecoration(color: T.petalMint50, shape: BoxShape.circle),
            child: const Icon(LucideIcons.check, size: 28, color: T.petalMint600)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.t('done_lbl'), style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: s.accent.main)),
            Text(s.t('done_q'), style: Typo.subhead(ar: s.rtl).copyWith(fontSize: FS.md)),
          ]),
        ),
        RoundBtn(icon: LucideIcons.chevronRight, onTap: () => s.setTab('trends')),
      ]),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.iconBg, required this.iconFg, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return PCard(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      onTap: onTap,
      child: Row(children: [
        IconSquare(icon, bg: iconBg, fg: iconFg),
        const SizedBox(width: 13),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            const SizedBox(height: 1),
            Text(subtitle, style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ]),
        ),
        Chevron(rtl: s.rtl),
      ]),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.cur, required this.moodLbl});
  final CheckinResult cur;
  final String moodLbl;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final metrics = <_Metric>[
      _Metric(LucideIcons.activity, s.t('m_bp'), cur.bp ?? '—', s.t('unit_bp'), s.t('bp_normal'), 'down'),
      _Metric(LucideIcons.droplet, s.t('m_glucose'), '${cur.glu ?? '—'}', s.t('unit_glu'), s.t('bp_high'), 'up'),
      _Metric(LucideIcons.smile, s.t('m_mood'), moodLbl, '', '', ''),
      _Metric(LucideIcons.thermometer, s.t('m_pain'), '${cur.pain ?? 0}/10', '', '', ''),
    ];
    return LayoutBuilder(builder: (context, c) {
      // 2 columns on phones, 4 once the content pane is wide enough.
      final cols = c.maxWidth >= 560 ? 4 : 2;
      return GridView.count(
        crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: cols == 4 ? 1.1 : 1.3,
        children: [for (final m in metrics) _MetricTile(m)],
      );
    });
  }
}

class _Metric {
  _Metric(this.icon, this.label, this.value, this.unit, this.foot, this.tone);
  final IconData icon;
  final String label, value, unit, foot, tone;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.m);
  final _Metric m;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final hasNum = RegExp(r'[0-9]').hasMatch(m.value);
    final footColor = m.tone == 'up' ? T.danger : const Color(0xFF1F6A36);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(T.rLg),
        border: Border.all(color: T.border), boxShadow: T.shadowXs),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(children: [
          Icon(m.icon, size: 15, color: T.fg3),
          const SizedBox(width: 7),
          Flexible(child: Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: RichText(
            maxLines: 1,
            textDirection: hasNum ? TextDirection.ltr : null,
            text: TextSpan(children: [
              TextSpan(text: m.value, style: (hasNum ? Typo.num(size: FS.xl2, weight: FontWeight.w800) : Typo.display().copyWith(fontSize: FS.xl2))),
              if (m.unit.isNotEmpty)
                TextSpan(text: ' ${m.unit}', style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg3)),
            ]),
          ),
        ),
        if (m.foot.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(m.tone == 'up' ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight, size: 14, color: footColor),
            const SizedBox(width: 6),
            Flexible(child: Text(m.foot, maxLines: 1, overflow: TextOverflow.ellipsis, style: Typo.meta(ar: s.rtl).copyWith(color: footColor))),
          ]),
        ],
      ]),
    );
  }
}

class _MedRow extends StatelessWidget {
  const _MedRow({required this.med, required this.done, required this.first});
  final Med med;
  final bool done;
  final bool first;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tone = medTone(med.tone);
    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: T.ink100))),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(children: [
        Container(width: 42, height: 42, alignment: Alignment.center,
            decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(T.rMd)),
            child: Icon(med.icon, size: 21, color: tone.fg)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(med.name.of(s.lang), style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg1)),
            Text(med.dose.of(s.lang), style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
          ]),
        ),
        if (done)
          Pill(s.t('taken'), kind: PillKind.success, ar: s.rtl)
        else
          PButton(s.t('take'), variant: BtnVariant.soft, accent: s.accent, ar: s.rtl),
      ]),
    );
  }
}

/// History summary row (.history-row).
class HistoryRow extends StatelessWidget {
  const HistoryRow({super.key, required this.h, required this.onTap, this.first = false});
  final HistoryDay h;
  final VoidCallback onTap;
  final bool first;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pinfo = h.pain <= 3 ? PillKind.success : (h.pain <= 6 ? PillKind.warn : PillKind.danger);
    // `.history-row:active { background: ink50 }`.
    return PressHighlight(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: T.ink100))),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          SizedBox(width: 50, child: Column(children: [
            Text('${h.d}', style: Typo.num(size: FS.lg, weight: FontWeight.w800)),
            Text(h.m.of(s.lang), style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs2, letterSpacing: 1.2)),
          ])),
          const SizedBox(width: 14),
          Expanded(
            child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.activity, size: 14, color: T.petalViolet),
                const SizedBox(width: 4),
                Text(h.bp, textDirection: TextDirection.ltr, style: Typo.num(weight: FontWeight.w600, size: FS.md)),
              ]),
              const Text('·', style: TextStyle(color: T.ink300)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(LucideIcons.droplet, size: 14, color: T.petalMint600),
                const SizedBox(width: 4),
                Text('${h.glu}', style: Typo.num(weight: FontWeight.w600, size: FS.md)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          MoodFace(level: h.mood, size: 26, color: kMoodColors[h.mood - 1]),
          const SizedBox(width: 8),
          Pill('${h.pain}', kind: pinfo, dot: false, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3)),
        ]),
      ),
    );
  }
}
