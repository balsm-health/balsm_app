import 'dart:async';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pregnancy/pregnancy.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../family/family_kit.dart';
import 'pregnancy_kit.dart';
import 'pregnancy_screen.dart';

/// Home's pregnancy card, or the prompt to start tracking (home-mc.jsx /
/// mother-child.jsx `MCHomeCards`), on the account holder's own Home.
///
/// The prompt shows only while nothing has been tracked on this profile and
/// it has not been hidden (its ✕, confirmed in a sheet; kept per account on
/// this device);
/// it is not offered to an account holder who said they are male. Nothing
/// shows until both have loaded, so it never flashes in.
///
/// With [mother] it is on a family member's Home (design `MCHomeCards`
/// with `member`): her pregnancy card, named for her, and never the prompt.
class PregnancyHomeCards extends ConsumerWidget {
  const PregnancyHomeCards({super.key, this.gutter = 16, this.mother});

  /// Whose pregnancy (null = the account holder's own).
  final HealthProfileId? mother;

  /// Home's side gutter (16 on a phone, 24 from 600 wide).
  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final all = ref.watch(pregnanciesOfProvider(mother)).value;
    final owner = pregnancyOwner(ref, mother);
    final dismissed = ref.watch(pregnancyPromptDismissedProvider).value;
    if (all == null) return const SizedBox.shrink();
    final preg = all.where((x) => x.isActive).firstOrNull;
    final Widget child;
    if (preg != null) {
      child =
          _TrackerCard(pregnancy: preg, mother: mother, title: owner == null ? p.title : p.title_of(owner.shortName));
    } else if (mother == null && all.isEmpty && dismissed == false && s.gender != Gender.male) {
      child = Stack(
        children: [
          PCard(
            onTap: () => openPregnancy(context, ref),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const IconSquare(LucideIcons.sprout, bg: babyWash, fg: babyInk, size: 44, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      Text(p.prompt_b, style: Typo.meta(ar: s.rtl)),
                    ],
                  ),
                ),
                // Room for the ✕, which sits over the card's end.
                const SizedBox(width: 28),
              ],
            ),
          ),
          PositionedDirectional(
            end: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: RoundBtn(
                icon: LucideIcons.x,
                semanticLabel: p.hide_a11y,
                ghost: true,
                fg: AppColors.textTertiary,
                iconSize: 17,
                onTap: () => _askToHide(context, ref, s),
              ),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
    return Padding(padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter, 14), child: child);
  }
}

/// "Hide the pregnancy card?" (mother-child.jsx `MCHomeCards` hideAsk): the
/// prompt goes for good on this device; tracking stays one tap away in
/// Profile › Pregnancy.
Future<void> _askToHide(BuildContext context, WidgetRef ref, PatientAppState s) {
  final p = s.strings.pregnancy;
  return showAppSheet<void>(
    context,
    textDirection: s.dir,
    builder: (sheet) => FamilySheet(
      title: p.hide_title,
      sub: p.hide_sub,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
          decoration: BoxDecoration(color: AppColors.ink50, borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsetsDirectional.only(top: 2),
                child: Icon(LucideIcons.info, size: 16, color: AppColors.textTertiary),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(p.hide_note, style: Typo.bodySm(ar: s.rtl))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PButton(
          p.hide_btn,
          block: true,
          large: true,
          accent: s.accent,
          ar: s.rtl,
          onTap: () {
            unawaited(ref.read(pregnancyPromptDismissedProvider.notifier).dismiss());
            Navigator.of(sheet).pop();
          },
        ),
        const SizedBox(height: 10),
        PButton(
          s.strings.common.cancel,
          variant: BtnVariant.ghost,
          size: BtnSize.md,
          block: true,
          accent: s.accent,
          ar: s.rtl,
          onTap: () => Navigator.of(sheet).pop(),
        ),
        const SizedBox(height: 4),
      ],
    ),
  );
}

class _TrackerCard extends ConsumerWidget {
  const _TrackerCard({required this.pregnancy, required this.mother, required this.title});
  final Pregnancy pregnancy;
  final HealthProfileId? mother;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final info = pregnancy.infoOn(DateTime.now());
    final visit = pregnancy.nextVisit;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: () => openPregnancy(context, ref, mother: mother),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: babyWash, borderRadius: BorderRadius.circular(AppRadii.xl)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: babyInk)),
                        Text(p.week_n(info.week), style: Typo.heading(ar: s.rtl).copyWith(fontWeight: FontWeight.w800)),
                        Text(
                          '${trimesterLabel(s, info.trimester)} · ${dueLine(s, info)}',
                          style: Typo.bodySm(ar: s.rtl),
                        ),
                      ],
                    ),
                  ),
                  const IconSquare(
                    LucideIcons.sprout,
                    bg: AppColors.white,
                    fg: AppColors.hueAqua,
                    size: 40,
                    iconSize: 20,
                    radius: 12,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: Container(
                  height: 6,
                  color: AppColors.white,
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: (info.week / 40).clamp(0.0, 1.0),
                    child: Container(color: AppColors.hueAqua),
                  ),
                ),
              ),
              if (visit != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text('${p.next_visit} ', style: Typo.bodySm(ar: s.rtl)),
                    Text(
                      formatDay(visit.date),
                      textDirection: TextDirection.ltr,
                      style: Typo.num(size: FontSizes.bodySm, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
