import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:self_report/self_report.dart' show BodyRegion, BodyView;
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';

/// Localized label for a [BodyRegion]. Copy lives on the enum (module i69n).
String regionLabel(PatientAppState s, BodyRegion region) => region.labelForLang(s.lang.value);

/// Tappable anatomical body figure (bodymap.jsx, surface layer).
///
/// Regions and selection are the self-report module's [BodyRegion] catalog —
/// a closed enum, not free-form ids.
class BodyMap extends StatefulWidget {
  const BodyMap({
    super.key,
    required this.selected,
    required this.onToggle,
    this.initialGender = 'female',
  });
  final Set<BodyRegion> selected;
  final ValueChanged<BodyRegion> onToggle;
  final String initialGender;
  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> {
  BodyView view = BodyView.front;
  late String gender = widget.initialGender;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final regions = view == BodyView.front ? BodyRegion.front : BodyRegion.back;
    final c = s.strings.checkin;
    final selectedLabels = BodyRegion.all.where(widget.selected.contains).map((r) => regionLabel(s, r)).toList();
    final viewName = view == BodyView.front ? 'front' : 'back';
    return Column(children: [
      // Controls
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          _chip(s, c.body_view_front, view == BodyView.front, () => setState(() => view = BodyView.front)),
          const SizedBox(width: 5),
          _chip(s, c.body_view_back, view == BodyView.back, () => setState(() => view = BodyView.back)),
        ]),
        Row(children: [
          _chip(s, c.body_sex_female, gender == 'female', () => setState(() => gender = 'female'), neutral: true),
          const SizedBox(width: 4),
          _chip(s, c.body_sex_male, gender == 'male', () => setState(() => gender = 'male'), neutral: true),
        ]),
      ]),
      const SizedBox(height: 8),
      // Location label
      Text(
        widget.selected.isEmpty ? c.body_tap : selectedLabels.join(c.list_mid),
        textAlign: TextAlign.center,
        style: Typo.meta(ar: s.rtl).copyWith(
            fontSize: FS.xs,
            fontWeight: FontWeight.w700,
            letterSpacing: s.rtl ? 0 : 0.8,
            color: widget.selected.isEmpty ? T.fg4 : T.fg2),
      ),
      const SizedBox(height: 8),
      // Figure + hotspots
      Center(
        child: SizedBox(
          width: 190,
          child: AspectRatio(
            aspectRatio: 200 / 384,
            child: LayoutBuilder(builder: (context, c) {
              return Stack(children: [
                Positioned.fill(
                  child: SvgPicture.asset(
                    'assets/body/${gender}_$viewName.svg',
                    fit: BoxFit.contain,
                  ),
                ),
                ...regions.map((r) => Positioned(
                      left: r.cx / 200 * c.maxWidth - 14,
                      top: r.cy / 384 * c.maxHeight - 14,
                      child: GestureDetector(
                        onTap: () => widget.onToggle(r),
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: Center(child: _dot(widget.selected.contains(r), s.accent)),
                        ),
                      ),
                    )),
              ]);
            }),
          ),
        ),
      ),
    ]);
  }

  Widget _dot(bool active, Accent accent) {
    final r = active ? 17.0 : 13.0;
    return Container(
      width: r,
      height: r,
      decoration: BoxDecoration(
        color: active ? accent.main : const Color(0xE0FFFFFF),
        shape: BoxShape.circle,
        border: active ? null : Border.all(color: const Color(0xFF9A9990), width: 1.5),
      ),
    );
  }

  Widget _chip(PatientAppState s, String label, bool active, VoidCallback onTap, {bool neutral = false}) {
    final on = active;
    final color = neutral ? T.fg1 : s.accent.d;
    final bg = neutral ? T.ink100 : s.accent.bg;
    final border = neutral ? T.fg2 : s.accent.main;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? bg : Colors.white,
          borderRadius: BorderRadius.circular(T.rPill),
          border: Border.all(color: on ? border : T.border, width: 1.5),
        ),
        child: Text(label,
            style:
                Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs, fontWeight: FontWeight.w600, color: on ? color : T.fg3)),
      ),
    );
  }
}
