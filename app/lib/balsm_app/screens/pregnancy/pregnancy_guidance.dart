import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pregnancy/pregnancy.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../kit.dart';
import '../family/family_kit.dart';

/// Weekly pregnancy guidance (mother-child.jsx `MCPregScreen` guidance card,
/// `MCWeeksScreen`, `MCWeekGuide`). Everything the guide says — titles,
/// bodies, sizes, its section headings and units, test, danger-sign and topic
/// names, sources, source, disclaimer, the multiples note — comes from the
/// API in the patient's language, so it changes with the content and no app
/// release; only the card's frame ("Week n guidance", "All weeks"), the
/// layout and the topic icons are the app's own. A piece the content leaves
/// out is left out. With no guidance on the device and no server to ask, the
/// card is simply left out.

/// Opens "Week by week".
Future<void> openPregnancyWeeks(BuildContext context, {HealthProfileId? mother}) =>
    pushFamilyScreen<void>(context, (_) => PregnancyWeeksScreen(mother: mother));

/// "General information, not medical advice. Based on …." — the line under
/// the guidance.
String _footer(WeeklyGuidance g) => '${g.disclaimer} ${g.source}.';

/// This week's guidance with its compact guide, "All weeks" and the footer.
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
                _LinkButton(label: p.all_weeks, onTap: () => openPregnancyWeeks(context, mother: mother)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.title,
              style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(entry.summary, style: Typo.bodySm(ar: s.rtl)),
            const SizedBox(height: 8),
            PregnancyWeekGuide(
              entry: entry,
              guidance: guidance,
              multiples: multiples,
              compact: true,
              onMore: () => openPregnancyWeeks(context, mother: mother),
            ),
            const SizedBox(height: 8),
            _Footer(_footer(guidance), divider: true),
          ],
        ),
      ),
    );
  }
}

/// "All weeks ›", "Sources (n) and more ›": a small accent text button.
class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap, this.size});
  final String label;
  final VoidCallback onTap;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final style = (size == null ? Typo.meta(ar: s.rtl) : Typo.bodySm(ar: s.rtl))
        .copyWith(fontWeight: FontWeight.w600, color: s.accent.d);
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(label, style: style)),
              const SizedBox(width: 2),
              Icon(forwardChevron(context), size: 14, color: s.accent.d),
            ],
          ),
        ),
      ),
    );
  }
}

/// The info-marked line under the guidance.
class _Footer extends StatelessWidget {
  const _Footer(this.text, {this.divider = false});
  final String text;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: EdgeInsets.only(top: divider ? 8 : 0),
      decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: AppColors.ink100))) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.info, size: 14, color: AppColors.textTertiary),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: Typo.meta(ar: s.rtl))),
        ],
      ),
    );
  }
}

/// A week's guide (`MCWeekGuide`): the artwork (when it loads), the baby's size, tests
/// due, danger signs, topics, the multiples note and — in full — the sources.
/// [compact] (the Pregnancy screen's card) leaves out the topics heading, the
/// "Danger signs to know" list for a week without warnings and the sources,
/// offering [onMore] instead.
class PregnancyWeekGuide extends ConsumerStatefulWidget {
  const PregnancyWeekGuide({
    required this.entry,
    required this.guidance,
    required this.multiples,
    super.key,
    this.compact = false,
    this.onMore,
  });

  final GuidanceWeek entry;
  final WeeklyGuidance guidance;
  final bool multiples;
  final bool compact;
  final VoidCallback? onMore;

  @override
  ConsumerState<PregnancyWeekGuide> createState() => _PregnancyWeekGuideState();
}

class _PregnancyWeekGuideState extends ConsumerState<PregnancyWeekGuide> {
  bool _allDangers = false;
  String? _openSymptom;
  bool _sourcesOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ask the CDN for every week's artwork, and every option the user could
    // switch it to, not just this one: a lone request for week-12.jpg would
    // tell it how far along the patient is.
    unawaited(
      precacheMedia(context, [
        for (final w in widget.guidance.weeks)
          if (w.illustration case final art?) art.media,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final g = widget.guidance;
    String? label(String key, [Map<String, Object> args = const {}]) => g.label(key, args);
    final tests = [
      for (final id in entry.testsDue)
        if (g.testLabels[id] case final label?) label,
    ];
    final dangers = [
      for (final id in entry.dangerSigns)
        if (g.dangerSignLabels[id] case final label?) label,
    ];
    final topics = [
      for (final id in entry.topics)
        if (g.topicLabels[id] case final name?) (_topicIcon(id), name),
    ];
    final sources = g.sourcesOf(entry);
    final gap = <Widget>[];
    void add(Widget w) => gap
      ..add(const SizedBox(height: 12))
      ..add(w);

    if (!widget.compact && label('baby_title') != null) {
      add(_SectionHead(icon: LucideIcons.baby, color: AppColors.hueAquaInk, text: label('baby_title')!));
    }
    final art = entry.illustration;
    if (art != null) {
      add(
        _WeekArtwork(
          art: art,
          credit: g.illustrationCredits[art.credit]?.text,
          label: label('illustration', {'week': entry.week}),
          height: widget.compact ? 112 : 150,
          compact: widget.compact,
        ),
      );
    }
    if (entry.babyFact.isNotEmpty) add(Text(entry.babyFact, style: Typo.bodySm(ar: AppScope.of(context).rtl)));
    if (!entry.fetalSize.isEmpty) add(_SizeRow(size: entry.fetalSize, guidance: g));
    final symptoms = [
      for (final id in entry.symptoms)
        if (g.symptomGuide[id] case final symptom?) (id, symptom),
    ];
    if (symptoms.isNotEmpty) {
      add(
        widget.compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label('symptoms_common') case final head?)
                    _SectionHead(icon: LucideIcons.thermometer, color: AppColors.textSecondary, text: head),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final (_, x) in symptoms) _TopicChip(label: x.label)],
                  ),
                ],
              )
            : _SymptomList(
                title: label('symptoms_title'),
                helps: label('symptom_helps'),
                callIf: label('symptom_call'),
                symptoms: symptoms,
                open: _openSymptom,
                onToggle: (id) => setState(() => _openSymptom = _openSymptom == id ? null : id),
              ),
      );
    }
    if (!widget.compact && entry.feelings.isNotEmpty) {
      add(_Feelings(title: label('feelings_title'), text: entry.feelings));
    }
    if (!widget.compact && entry.tips.isNotEmpty) {
      add(_Tips(title: label('tips_title'), tips: entry.tips));
    }
    if (tests.isNotEmpty) {
      add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label('tests_due') case final head?)
              _SectionHead(icon: LucideIcons.clipboardCheck, color: AppColors.hueBlue600, text: head),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final t in tests) _TestChip(t)]),
          ],
        ),
      );
    }
    if (dangers.isNotEmpty) {
      add(_DangerCard(title: label('dangers_now'), labels: dangers));
    } else if (!widget.compact && g.dangerSignLabels.isNotEmpty && label('dangers_all') != null) {
      add(
        _DangersToKnow(
          title: label('dangers_all')!,
          labels: [for (final label in g.dangerSignLabels.values) label],
          open: _allDangers,
          onToggle: () => setState(() => _allDangers = !_allDangers),
        ),
      );
    }
    if (topics.isNotEmpty) {
      add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.compact && label('topics_title') != null)
              _SectionHead(icon: LucideIcons.tags, color: AppColors.textSecondary, text: label('topics_title')!),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final t in topics) _TopicChip(icon: t.$1, label: t.$2)]),
          ],
        ),
      );
    }
    if (widget.multiples) add(_MultiplesNote(g.multiplesNote));
    if (widget.compact) {
      if ((widget.onMore, label('sources_more', {'n': sources.length})) case (final onMore?, final more?)) {
        add(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _LinkButton(label: more, onTap: onMore, size: 13),
          ),
        );
      }
    } else if (sources.isNotEmpty) {
      add(
        _SourceList(
          title: label('sources_title'),
          sources: sources,
          open: _sourcesOpen,
          onToggle: () => setState(() => _sourcesOpen = !_sourcesOpen),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: gap.skip(1).toList());
  }

  /// The app's own icon for a topic key; a tag for one it doesn't know.
  static IconData _topicIcon(String id) => switch (id) {
        'supplements' => LucideIcons.pill,
        'visits' => LucideIcons.stethoscope,
        'symptoms' => LucideIcons.thermometer,
        'rest' => LucideIcons.moon,
        'lifestyle' => LucideIcons.leaf,
        'tests' => LucideIcons.flaskConical,
        'nutrition' => LucideIcons.apple,
        'vaccines' => LucideIcons.syringe,
        'activity' => LucideIcons.footprints,
        'movements' => LucideIcons.activity,
        'bonding' => LucideIcons.heart,
        'birth_prep' => LucideIcons.briefcaseMedical,
        _ => LucideIcons.tag,
      };
}

/// The week's artwork and its credit, opening the page it was published on.
/// [MediaView] draws nothing until the image arrives, and if it cannot be
/// fetched the guide has no picture at all — never an empty frame.
class _WeekArtwork extends StatelessWidget {
  const _WeekArtwork({
    required this.art,
    required this.credit,
    required this.label,
    required this.height,
    required this.compact,
  });
  final GuidanceIllustration art;

  /// "Illustration: …, CC BY-ND 4.0", from the content; null leaves it out.
  final String? credit;

  /// Spoken description ("Week 12 illustration"), from the content.
  final String? label;
  final double height;

  /// On the card: the thumbnail when the content has one.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return MediaView(
      media: art.media,
      compact: compact,
      height: height,
      semanticLabel: label,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.ink100),
        gradient: const RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.2,
          colors: [AppColors.hueAqua50, AppColors.white],
          stops: [0, 0.7],
        ),
      ),
      footer: switch (credit) {
        final credit? => Padding(
            padding: const EdgeInsetsDirectional.only(top: 4),
            child: Semantics(
              link: true,
              child: GestureDetector(
                onTap: () => _SourceList._open(art.sourceUrl),
                child: Text(credit, style: Typo.meta(ar: s.rtl).copyWith(fontSize: FontSizes.micro)),
              ),
            ),
          ),
        null => null,
      },
    );
  }
}

/// "About the size of a plum · Length 8.7 cm · Weight 45 g".
class _SizeRow extends StatelessWidget {
  const _SizeRow({required this.size, required this.guidance});
  final GuidanceFetalSize size;
  final WeeklyGuidance guidance;

  static String _n(num v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    String? label(String key, [Map<String, Object> args = const {}]) => guidance.label(key, args);
    String? amount(num v, String unit) => label(unit) == null ? null : '${_n(v)} ${label(unit)}';
    final mm = size.lengthMm;
    final g = size.weightG;
    final length = mm == null ? null : (mm >= 10 ? amount(mm / 10, 'unit_cm') : amount(mm, 'unit_mm'));
    final weight = g == null ? null : (g >= 1000 ? amount(g / 1000, 'unit_kg') : amount(g, 'unit_g'));
    final figures = [
      if (length != null)
        if (label('size_length', {'value': length}) case final line?) line,
      if (weight != null)
        if (label('size_weight', {'value': weight}) case final line?) line,
    ];
    final comparison = size.comparison;
    final heading = comparison == null ? label('size_title') : label('size_about', {'thing': comparison});
    if (heading == null && figures.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.hueAqua50, borderRadius: BorderRadius.circular(AppRadii.lg)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadii.md)),
            child: const Icon(LucideIcons.ruler, size: 17, color: AppColors.hueAquaInk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (heading != null)
                  Text(
                    heading,
                    style: Typo.body(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                if (figures.isNotEmpty) Text(figures.join(' · '), style: Typo.meta(ar: s.rtl)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

class _TestChip extends StatelessWidget {
  const _TestChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(color: AppColors.hueBlue50, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.calendarCheck, size: 14, color: AppColors.hueBlue600),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A danger sign: a red dot and its name on a pill.
class _DangerChip extends StatelessWidget {
  const _DangerChip(this.label, {required this.background});
  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Call your doctor straight away if you have:" and the week's signs.
class _DangerCard extends StatelessWidget {
  const _DangerCard({required this.title, required this.labels});
  final String? title;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerBackground,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.siren, size: 16, color: AppColors.danger),
              const SizedBox(width: 8),
              if (title case final title?)
                Expanded(
                  child: Text(
                    title,
                    style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.danger),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final l in labels) _DangerChip(l, background: AppColors.white)],
          ),
        ],
      ),
    );
  }
}

/// "Danger signs to know": every sign, folded, for a week that warns of none.
class _DangersToKnow extends StatelessWidget {
  const _DangersToKnow({required this.title, required this.labels, required this.open, required this.onToggle});
  final String title;
  final List<String> labels;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.ink100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(LucideIcons.siren, size: 15, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Typo.bodySm(ar: s.rtl)
                            .copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                      ),
                    ),
                    Icon(
                      open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final l in labels) _DangerChip(l, background: AppColors.dangerBackground)],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.label, this.icon});
  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.ink50, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// "What you may feel": each symptom of the week, opening to what helps and,
/// where the content names it, when to call the doctor.
class _SymptomList extends StatelessWidget {
  const _SymptomList({
    required this.title,
    required this.helps,
    required this.callIf,
    required this.symptoms,
    required this.open,
    required this.onToggle,
  });
  final String? title;
  final String? helps;
  final String? callIf;
  final List<(String, GuidanceSymptom)> symptoms;
  final String? open;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget line(IconData icon, String? lead, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 15, color: AppColors.textTertiary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (lead != null) TextSpan(text: '$lead ', style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: text),
                    ],
                  ),
                  style: Typo.bodySm(ar: s.rtl),
                ),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title case final title?)
          _SectionHead(icon: LucideIcons.thermometer, color: AppColors.textSecondary, text: title),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.ink100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, (id, x)) in symptoms.indexed) ...[
                if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.ink100),
                Semantics(
                  button: true,
                  expanded: open == id,
                  child: InkWell(
                    onTap: () => onToggle(id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              x.label,
                              style: Typo.bodySm(ar: s.rtl)
                                  .copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                          if (x.callDoctorIf != null) ...[
                            const Icon(LucideIcons.stethoscope, size: 14, color: AppColors.danger),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            open == id ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (open == id)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        line(LucideIcons.handHeart, helps, x.selfCare),
                        if (x.callDoctorIf case final call?) line(LucideIcons.phone, callIf, call),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "How you may feel": the week's feelings line.
class _Feelings extends StatelessWidget {
  const _Feelings({required this.title, required this.text});
  final String? title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.hueViolet50, borderRadius: BorderRadius.circular(AppRadii.lg)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.heart, size: 16, color: AppColors.hueVioletInk),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (title != null)
                    TextSpan(
                      text: '$title\n',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.hueVioletInk),
                    ),
                  TextSpan(text: text),
                ],
              ),
              style: Typo.bodySm(ar: s.rtl),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Tips for this week": each tip with a check.
class _Tips extends StatelessWidget {
  const _Tips({required this.title, required this.tips});
  final String? title;
  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title case final title?) _SectionHead(icon: LucideIcons.listChecks, color: s.accent.d, text: title),
        for (final (i, tip) in tips.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(LucideIcons.checkCircle2, size: 16, color: s.accent.main),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(tip, style: Typo.bodySm(ar: s.rtl))),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Sources": each as its title (opening the page) — publisher. Source
/// titles are English, so the list reads left to right in either language.
class _SourceList extends StatelessWidget {
  const _SourceList({required this.title, required this.sources, required this.open, required this.onToggle});
  final String? title;

  /// Folded by default: the list opens on a tap of its heading.
  final bool open;
  final VoidCallback onToggle;
  final List<GuidanceSource> sources;

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(ClipboardData(text: url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final style = Typo.meta().copyWith(height: 1.45, color: AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.ink100))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(LucideIcons.bookMarked, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${title ?? ''} (${sources.length})'.trimLeft(),
                        style:
                            Typo.meta(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: AppColors.textTertiary),
                      ),
                    ),
                    Icon(
                      open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open) const SizedBox(height: 6),
          if (open)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, src) in sources.indexed)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 18, child: Text('${i + 1}.', style: style)),
                          Expanded(
                            child: Semantics(
                              link: true,
                              child: GestureDetector(
                                onTap: () => _open(src.url),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: src.title,
                                        style: style.copyWith(fontWeight: FontWeight.w600, color: s.accent.d),
                                      ),
                                      TextSpan(
                                        text: ' — ${src.publisher}',
                                        style: style.copyWith(color: AppColors.textTertiary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
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
            Padding(padding: const EdgeInsets.only(bottom: 6), child: _Footer(_footer(guidance))),
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
    final title = entry.title;
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
                            current ? '${p.this_week} · $title' : title,
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
                  const SizedBox(height: 10),
                  Text(entry.summary, style: Typo.bodySm(ar: s.rtl)),
                  const SizedBox(height: 10),
                  PregnancyWeekGuide(entry: entry, guidance: guidance, multiples: multiples),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
