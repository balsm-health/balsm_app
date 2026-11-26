import 'dart:async';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../kit.dart';
import '../widgets/balsm_mark.dart';
import 'feedback_draft.dart';

/// In-app rating + feedback.
///
/// The brand's flower is the rating unit rather than stars. A submission goes
/// to the Balsm team through [feedbackReporterProvider] (Sentry's User Feedback
/// inbox), never an app store. The sheet asks the patient to leave health
/// details out of the note. On-device, only the rating and the send date are
/// kept; the note is not stored after sending.
Future<void> showFeedbackSheet(BuildContext context) => showAppSheet<void>(
      context,
      builder: (_) => const _FeedbackSheet(),
    );

/// Topic chips — ids are stable, labels come from the i69n bundle.
const _topics = <(String, String Function(PatientAppState))>[
  ('general', _tGeneral),
  ('ease', _tEase),
  ('records', _tRecords),
  ('meds', _tMeds),
  ('arabic', _tArabic),
];

String _tGeneral(PatientAppState s) => s.strings.feedback.fb_t_general;
String _tEase(PatientAppState s) => s.strings.feedback.fb_t_ease;
String _tRecords(PatientAppState s) => s.strings.feedback.fb_t_records;
String _tMeds(PatientAppState s) => s.strings.feedback.fb_t_meds;
String _tArabic(PatientAppState s) => s.strings.feedback.fb_t_arabic;

class _FeedbackSheet extends ConsumerStatefulWidget {
  const _FeedbackSheet();

  @override
  ConsumerState<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<_FeedbackSheet> {
  final _note = TextEditingController();
  bool _sent = false;
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    final s = AppScope.of(context);
    setState(() => _sending = true);
    final ok = await ref.read(feedbackDraftProvider(s.prefs).notifier).submit(
          note: _note.text,
          topicOrder: _topics.map((t) => t.$1).toList(),
        );
    if (!mounted) return;
    if (!ok) {
      setState(() => _sending = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(s.strings.feedback.fb_failed(s.gender))));
      return;
    }
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.feedback;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          const SheetGrab(),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(f.fb_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
                ),
                RoundBtn(
                  icon: LucideIcons.x,
                  semanticLabel: s.strings.common.a11y_close,
                  ghost: true,
                  iconSize: 17,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.ink100),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, sheetBottomInset(context, base: 34)),
              child: _sent ? _Thanks(s) : _FeedbackForm(note: _note, sending: _sending, onSubmit: _submit),
            ),
          ),
        ],
      ),
    );
  }
}

/// The rating, topics and note. Watches the draft (loaded with the last
/// rating), so a tap rebuilds the form and not the sheet.
class _FeedbackForm extends ConsumerWidget {
  const _FeedbackForm({required this.note, required this.sending, required this.onSubmit});
  final TextEditingController note;
  final bool sending;
  final VoidCallback onSubmit;

  static String _ratingLabel(PatientAppState s, int rating) => switch (rating) {
        1 => s.strings.feedback.fb_r1,
        2 => s.strings.feedback.fb_r2,
        3 => s.strings.feedback.fb_r3,
        4 => s.strings.feedback.fb_r4,
        5 => s.strings.feedback.fb_r5,
        _ => s.strings.feedback.fb_rate_q(s.gender),
      };

  static String _fmt(DateTime d) {
    final l = d.toLocal();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(l.day)}/${p(l.month)}/${l.year}';
  }

  static OutlineInputBorder _b(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: c, width: 1.5),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppScope.of(context);
    final f = s.strings.feedback;
    final provider = feedbackDraftProvider(s.prefs);
    final draft = ref.watch(provider).value ?? FeedbackDraft();
    final notifier = ref.read(provider.notifier);
    final rating = draft.rating;
    final lastSentAt = draft.lastSentAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var n = 1; n <= 5; n++) ...[
                  _RateMark(lit: n <= rating, label: '$n/5', onTap: () => notifier.rate(n)),
                  if (n < 5) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 20,
              child: Text(
                _ratingLabel(s, rating),
                style: Typo.bodySm(ar: s.rtl).copyWith(
                  fontWeight: FontWeight.w700,
                  color: rating > 0 ? AppColors.textSecondary : AppColors.textTertiary,
                ),
              ),
            ),
            if (lastSentAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '${f.fb_last} ${_fmt(lastSentAt)}',
                  style: Typo.meta(ar: s.rtl).copyWith(fontSize: FontSizes.eyebrow),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          f.fb_about,
          style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._topics.map(
              (t) => _TopicChip(
                label: t.$2(s),
                selected: draft.topics.contains(t.$1),
                onTap: () => notifier.toggleTopic(t.$1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              f.fb_note_lbl,
              style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            Text(' · ${f.fb_optional}', style: Typo.bodySm(ar: s.rtl).copyWith(color: AppColors.textTertiary)),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: note,
          maxLines: null,
          // A multi-line field's return key adds a line, so tapping anywhere
          // else is the only way to put the keyboard away (it covers Send).
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          minLines: 4,
          style: Typo.body(ar: s.rtl).copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: f.fb_ph,
            hintStyle: Typo.body(ar: s.rtl).copyWith(color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: _b(AppColors.border),
            enabledBorder: _b(AppColors.border),
            focusedBorder: _b(s.accent.main),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.textTertiary),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(f.fb_privacy, style: Typo.meta(ar: s.rtl))),
          ],
        ),
        const SizedBox(height: 18),
        PButton(
          f.fb_send,
          icon: LucideIcons.send,
          block: true,
          accent: s.accent,
          ar: s.rtl,
          // Disabled until a rating is picked — the note alone is not a signal.
          onTap: rating == 0 || sending ? null : onSubmit,
        ),
      ],
    );
  }
}

/// One tappable mark — the brand mark in full colour when lit, flat ink when
/// not.
///
/// `feedback.jsx` paints a lit mark one uniform gold (#F0AE1A, "no two-tone,
/// no sweep"). Deliberately NOT followed: the rating is the one place the
/// five-hue mark earns its keep, and flattening it to gold threw the brand
/// away for a star metaphor the mark is not. Only the unlit wash follows the
/// design. If this is ever reconciled, the gold is the design's value.
class _RateMark extends StatelessWidget {
  const _RateMark({required this.lit, required this.onTap, required this.label});
  final bool lit;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        button: true,
        selected: lit,
        child: Pressable(
          onTap: onTap,
          scale: 0.94,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: lit
                  ? const BalsmFlower(size: 42)
                  : const ColorFiltered(
                      // `.fb-petal-off` — one flat ink wash, not a
                      // desaturation of the five brand hues.
                      colorFilter: ColorFilter.mode(AppColors.ink200, BlendMode.srcIn),
                      child: BalsmFlower(size: 42),
                    ),
            ),
          ),
        ),
      );
}

/// `.chip` — pill outline that fills with the accent wash when selected.
class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? s.accent.bg : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: selected ? s.accent.main : AppColors.border, width: 1.5),
        ),
        child: Text(
          label,
          style: Typo.bodySm(ar: s.rtl)
              .copyWith(fontWeight: FontWeight.w600, color: selected ? s.accent.d : AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _Thanks extends StatelessWidget {
  const _Thanks(this.s);
  final PatientAppState s;

  @override
  Widget build(BuildContext context) {
    final f = s.strings.feedback;
    return Column(
      children: [
        const SizedBox(height: 14),
        const BalsmFlower(size: 58),
        const SizedBox(height: 18),
        Text(f.fb_thanks, textAlign: TextAlign.center, style: Typo.heading(ar: s.rtl)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(f.fb_thanks_sub, textAlign: TextAlign.center, style: Typo.meta(ar: s.rtl)),
        ),
        const SizedBox(height: 26),
        PButton(f.fb_done, block: true, accent: s.accent, ar: s.rtl, onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}
