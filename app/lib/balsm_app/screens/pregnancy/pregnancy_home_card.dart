import 'package:core/core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pregnancy/pregnancy.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../../tokens.dart';
import '../family/family_kit.dart';
import 'pregnancy_kit.dart';
import 'pregnancy_screen.dart';

/// Home's pregnancy card, or the prompt to start tracking (home-mc.jsx /
/// mother-child.jsx `MCHomeCards`), on the account holder's own Home.
///
/// The prompt shows only while nothing has been tracked on this profile and
/// it has not been dismissed ("Not now", kept per account on this device);
/// it is not offered to an account holder who said they are male. Nothing
/// shows until both have loaded, so it never flashes in.
class PregnancyHomeCards extends ConsumerWidget {
  const PregnancyHomeCards({super.key, this.gutter = 16});

  /// Home's side gutter (16 on a phone, 24 from 600 wide).
  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final all = ref.watch(pregnanciesProvider).valueOrNull;
    final dismissed = ref.watch(pregnancyPromptDismissedProvider).valueOrNull;
    if (all == null) return const SizedBox.shrink();
    final preg = all.where((x) => x.isActive).firstOrNull;
    final Widget child;
    if (preg != null) {
      child = _TrackerCard(pregnancy: preg);
    } else if (all.isEmpty && dismissed == false && s.gender != Gender.male) {
      child = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PCard(
          onTap: () => openPregnancy(context, ref),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            const IconSquare(LucideIcons.sprout, bg: babyWash, fg: babyInk, size: 44, iconSize: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.title, style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: T.fg1)),
                Text(p.prompt_b, style: Typo.meta(ar: s.rtl)),
              ]),
            ),
            Icon(s.rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight, size: 18, color: T.fg4),
          ]),
        ),
        TextButton(
          onPressed: () => ref.read(pregnancyPromptDismissedProvider.notifier).dismiss(),
          child: Text(p.not_now, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600)),
        ),
      ]);
    } else {
      return const SizedBox.shrink();
    }
    return Padding(padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 14), child: child);
  }
}

class _TrackerCard extends ConsumerWidget {
  const _TrackerCard({required this.pregnancy});
  final Pregnancy pregnancy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final info = pregnancy.infoOn(DateTime.now());
    final visit = pregnancy.nextVisit;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: () => openPregnancy(context, ref),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: babyWash, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.title, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: babyInk)),
                  Text(p.week_n(info.week), style: Typo.heading(ar: s.rtl).copyWith(fontWeight: FontWeight.w800)),
                  Text(
                    '${trimesterLabel(s, info.trimester)} · ${p.days_to_go(info.daysLeft < 0 ? 0 : info.daysLeft)}',
                    style: Typo.bodySm(ar: s.rtl),
                  ),
                ]),
              ),
              const IconSquare(LucideIcons.sprout, bg: Colors.white, fg: T.hueAqua, size: 40, iconSize: 20, radius: 12),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(T.rPill),
              child: Container(
                height: 6,
                color: Colors.white,
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: (info.week / 40).clamp(0.0, 1.0),
                  child: Container(color: T.hueAqua),
                ),
              ),
            ),
            if (visit != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Icon(LucideIcons.calendar, size: 15, color: T.fg2),
                const SizedBox(width: 6),
                Text('${p.next_visit} ', style: Typo.bodySm(ar: s.rtl)),
                Text(formatDay(visit.date),
                    textDirection: TextDirection.ltr, style: Typo.num(size: FS.sm, weight: FontWeight.w700)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
