import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pregnancy/pregnancy.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../family/family_kit.dart';

/// Weekly pregnancy guidance (mother-child.jsx `MCPregScreen` guidance card,
/// `MCWeeksScreen`). The copy — titles, bodies, source, disclaimer, the
/// multiples note — comes from the API in the patient's language; only the
/// chrome around it is the app's own. With no guidance on the device and no
/// server to ask, the card is simply left out.

/// Opens "Week by week".
Future<void> openPregnancyWeeks(BuildContext context, {HealthProfileId? mother}) =>
    pushFamilyScreen<void>(context, (_) => PregnancyWeeksScreen(mother: mother));

/// This week's guidance, "All weeks", source and disclaimer.
class PregnancyGuidanceCard extends ConsumerWidget {
  const PregnancyGuidanceCard({required this.week, required this.multiples, super.key, this.mother});

  /// Whose pregnancy (null = the account holder's own).
  final HealthProfileId? mother;

  /// The pregnancy's current gestational week.
  final int week;

  /// More than one baby: the content describes a single pregnancy.
  final bool multiples;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guidance = ref.watch(pregnancyGuidanceProvider).value;
    final entry = guidance?.forWeek(week);
    if (guidance == null || entry == null) return const SizedBox.shrink();
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final lang = s.lang.value;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: PCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.bookOpen, size: 15, color: AppColors.hueEmeraldInk),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p.guidance_week(week),
                    style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.hueEmeraldInk),
                  ),
                ),
                Semantics(
                  button: true,
                  child: Pressable(
                    onTap: () => openPregnancyWeeks(context, mother: mother),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.all_weeks,
                            style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: s.accent.d),
                          ),
                          const SizedBox(width: 2),
                          Icon(forwardChevron(context), size: 14, color: s.accent.d),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.title.inLanguage(lang),
              style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(entry.body.inLanguage(lang), style: Typo.bodySm(ar: s.rtl)),
            if (multiples) ...[
              const SizedBox(height: 8),
              _MultiplesNote(guidance.multiplesNote.inLanguage(lang)),
            ],
            const SizedBox(height: 8),
            Text(p.content_from(guidance.source.inLanguage(lang)), style: Typo.meta(ar: s.rtl)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.ink100))),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(guidance.disclaimer.inLanguage(lang), style: Typo.meta(ar: s.rtl))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "This content describes a single pregnancy…" on a grey wash.
class _MultiplesNote extends StatelessWidget {
  const _MultiplesNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: AppColors.ink50, borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.info, size: 15, color: AppColors.textTertiary),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Typo.bodySm(ar: s.rtl))),
        ],
      ),
    );
  }
}

/// "Week by week": every week the content covers, the current one ringed in
/// aqua, opened and scrolled to.
class PregnancyWeeksScreen extends ConsumerStatefulWidget {
  const PregnancyWeeksScreen({super.key, this.mother});

  /// Whose pregnancy (null = the account holder's own).
  final HealthProfileId? mother;

  @override
  ConsumerState<PregnancyWeeksScreen> createState() => _PregnancyWeeksScreenState();
}

class _PregnancyWeeksScreenState extends ConsumerState<PregnancyWeeksScreen> {
  final GlobalKey<State<StatefulWidget>> _current = GlobalKey();
  int? _open;
  bool _opened = false;
  bool _scrolled = false;

  void _scrollToCurrent() {
    if (_scrolled) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _current.currentContext;
      if (target != null && target.mounted) Scrollable.ensureVisible(target, alignment: 0.05);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final lang = s.lang.value;
    final preg = ref.watch(activePregnancyOfProvider(widget.mother));
    final guidance = ref.watch(pregnancyGuidanceProvider).value;
    if (preg == null || guidance == null) return FamilyScaffold(title: p.weeks_title, children: const []);
    final current = preg.infoOn(DateTime.now()).week;
    if (!_opened) {
      _opened = true;
      _open = current;
    }
    final babies = ref.watch(pregnancyBabiesProvider(preg.id)).value ?? const <PregnancyBaby>[];
    final multiples = babies.length > 1;
    if (guidance.forWeek(current) != null) _scrollToCurrent();

    return FamilyScaffold(
      title: p.weeks_title,
      children: [
        // One child, so the whole list is laid out and the current week can
        // be scrolled to however far down it sits.
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${guidance.disclaimer.inLanguage(lang)} ${p.content_from(guidance.source.inLanguage(lang))}',
                      style: Typo.meta(ar: s.rtl),
                    ),
                  ),
                ],
              ),
            ),
            for (final w in guidance.weeks) ...[
              const SizedBox(height: 8),
              _WeekTile(
                key: w.week == current ? _current : ValueKey(w.week),
                entry: w,
                guidance: guidance,
                current: w.week == current,
                open: w.week == _open,
                multiples: multiples,
                onToggle: () => setState(() => _open = _open == w.week ? null : w.week),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _WeekTile extends StatelessWidget {
  const _WeekTile({
    required this.entry,
    required this.guidance,
    required this.current,
    required this.open,
    required this.multiples,
    required this.onToggle,
    super.key,
  });
  final GuidanceWeek entry;
  final WeeklyGuidance guidance;
  final bool current;
  final bool open;
  final bool multiples;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = s.strings.pregnancy;
    final lang = s.lang.value;
    final title = entry.title.inLanguage(lang);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: current ? AppColors.hueAqua : AppColors.border),
        boxShadow: open ? AppShadows.sm : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              onTap: onToggle,
              child: Container(
                color: current ? AppColors.hueAqua50 : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: current ? AppColors.white : AppColors.ink50,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Text(
                        '${entry.week}',
                        style: Typo.num(
                          weight: FontWeight.w700,
                          color: current ? AppColors.hueAquaInk : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.week_n(entry.week),
                            style: Typo.body(ar: s.rtl)
                                .copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          Text(
                            current ? p.this_week : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Typo.meta(ar: s.rtl),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(entry.body.inLanguage(lang), style: Typo.bodySm(ar: s.rtl)),
                  if (multiples) ...[
                    const SizedBox(height: 8),
                    _MultiplesNote(guidance.multiplesNote.inLanguage(lang)),
                  ],
                  const SizedBox(height: 8),
                  Text(p.content_from(guidance.source.inLanguage(lang)), style: Typo.meta(ar: s.rtl)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
