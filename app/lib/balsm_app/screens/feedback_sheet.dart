import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import '../widgets/balsm_flower.dart';

/// In-app rating + feedback.
///
/// The brand's flower is the rating unit rather than stars, and submissions
/// stay on-device: the team reads them inside Balsm, never an app store. Only
/// the rating and the send date are retained — the note is not health data and
/// is not stored after sending.
Future<void> showFeedbackSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const _FeedbackSheet(),
        ),
      ),
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

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  int _rating = 0;
  final _selected = <String>{};
  final _note = TextEditingController();
  bool _sent = false;
  DateTime? _lastSentAt;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    final prefs = AppScope.of(context).prefs;
    if (prefs == null) return;
    final rating = await prefs.feedbackRating();
    final at = await prefs.feedbackSentAt();
    if (!mounted) return;
    setState(() {
      _rating = rating ?? 0;
      _lastSentAt = at;
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    final prefs = AppScope.of(context).prefs;
    await prefs?.setFeedbackRating(_rating);
    await prefs?.setFeedbackSentAt(DateTime.now());
    if (mounted) setState(() => _sent = true);
  }

  String _ratingLabel(PatientAppState s) => switch (_rating) {
        1 => s.strings.feedback.fb_r1,
        2 => s.strings.feedback.fb_r2,
        3 => s.strings.feedback.fb_r3,
        4 => s.strings.feedback.fb_r4,
        5 => s.strings.feedback.fb_r5,
        _ => s.strings.feedback.fb_rate_q,
      };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final f = s.strings.feedback;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(T.rXl)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(
            width: 38, height: 4, decoration: BoxDecoration(color: T.ink200, borderRadius: BorderRadius.circular(999))),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
          child: Row(children: [
            Expanded(
              child: Text(f.fb_title, style: Typo.subhead(ar: s.rtl).copyWith(fontWeight: FontWeight.w700)),
            ),
            RoundBtn(icon: LucideIcons.x, ghost: true, iconSize: 17, onTap: () => Navigator.of(context).pop()),
          ]),
        ),
        const Divider(height: 1, color: T.ink100),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, sheetBottomInset(context, base: 34)),
            child: _sent ? _thanks(s) : _form(s),
          ),
        ),
      ]),
    );
  }

  Widget _thanks(PatientAppState s) {
    final f = s.strings.feedback;
    return Column(children: [
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
    ]);
  }

  Widget _form(PatientAppState s) {
    final f = s.strings.feedback;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 14),
      Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var n = 1; n <= 5; n++) ...[
            _RatePetal(lit: n <= _rating, onTap: () => setState(() => _rating = n)),
            if (n < 5) const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 20,
          child: Text(_ratingLabel(s),
              style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w700, color: _rating > 0 ? T.fg2 : T.fg3)),
        ),
        if (_lastSentAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('${f.fb_last} ${_fmt(_lastSentAt!)}', style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs2)),
          ),
      ]),
      const SizedBox(height: 20),
      Text(f.fb_about, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (id, label) in _topics)
            _TopicChip(
              label: label(s),
              selected: _selected.contains(id),
              onTap: () => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id)),
            ),
        ],
      ),
      const SizedBox(height: 20),
      Row(children: [
        Text(f.fb_note_lbl, style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: T.fg2)),
        Text(' · ${f.fb_optional}', style: Typo.bodySm(ar: s.rtl).copyWith(color: T.fg3)),
      ]),
      const SizedBox(height: 10),
      TextField(
        controller: _note,
        maxLines: null,
        minLines: 4,
        style: Typo.body(ar: s.rtl).copyWith(color: T.fg1),
        decoration: InputDecoration(
          hintText: f.fb_ph,
          hintStyle: Typo.body(ar: s.rtl).copyWith(color: T.fg4),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: _b(T.border),
          enabledBorder: _b(T.border),
          focusedBorder: _b(s.accent.main),
        ),
      ),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(LucideIcons.shieldCheck, size: 16, color: T.fg3),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(f.fb_privacy, style: Typo.meta(ar: s.rtl))),
      ]),
      const SizedBox(height: 18),
      PButton(f.fb_send,
          icon: LucideIcons.send,
          block: true,
          accent: s.accent,
          ar: s.rtl,
          // Disabled until a rating is picked — the note alone is not a signal.
          onTap: _rating == 0 ? null : _submit),
    ]);
  }

  static String _fmt(DateTime d) {
    final l = d.toLocal();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(l.day)}/${p(l.month)}/${l.year}';
  }

  OutlineInputBorder _b(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(T.rMd), borderSide: BorderSide(color: c, width: 1.5));
}

/// One tappable petal mark — full colour when lit, ink when not.
class _RatePetal extends StatelessWidget {
  const _RatePetal({required this.lit, required this.onTap});
  final bool lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
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
                    // `.fb-petal-off .petal { fill: ink-200 }` — one flat ink
                    // wash, not a desaturation of the five petal hues.
                    colorFilter: ColorFilter.mode(T.ink200, BlendMode.srcIn),
                    child: BalsmFlower(size: 42),
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
          color: selected ? s.accent.bg : Colors.white,
          borderRadius: BorderRadius.circular(T.rPill),
          border: Border.all(color: selected ? s.accent.main : T.border, width: 1.5),
        ),
        child: Text(label,
            style: Typo.bodySm(ar: s.rtl).copyWith(fontWeight: FontWeight.w600, color: selected ? s.accent.d : T.fg2)),
      ),
    );
  }
}
