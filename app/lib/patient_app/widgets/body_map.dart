import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app_state.dart';
import '../data.dart';
import '../kit.dart';
import '../tokens.dart';

/// A tappable hotspot on the body figure.
class Hotspot {
  const Hotspot(this.id, this.label, this.cx, this.cy);
  final String id;
  final L label;
  final double cx;
  final double cy;
}

const List<Hotspot> kHpFront = [
  Hotspot('head', {'en': 'Head', 'ar': 'الرأس'}, 100, 32),
  Hotspot('neck', {'en': 'Neck', 'ar': 'الرقبة'}, 100, 62),
  Hotspot('l-shoulder', {'en': 'L. Shoulder', 'ar': 'كتف أيسر'}, 52, 89),
  Hotspot('r-shoulder', {'en': 'R. Shoulder', 'ar': 'كتف أيمن'}, 148, 89),
  Hotspot('chest', {'en': 'Chest', 'ar': 'الصدر'}, 100, 106),
  Hotspot('l-upper-arm', {'en': 'L. Upper arm', 'ar': 'عضد أيسر'}, 58, 120),
  Hotspot('r-upper-arm', {'en': 'R. Upper arm', 'ar': 'عضد أيمن'}, 142, 120),
  Hotspot('abdomen', {'en': 'Abdomen', 'ar': 'البطن'}, 100, 150),
  Hotspot('l-elbow', {'en': 'L. Elbow', 'ar': 'مرفق أيسر'}, 56, 168),
  Hotspot('r-elbow', {'en': 'R. Elbow', 'ar': 'مرفق أيمن'}, 144, 168),
  Hotspot('l-forearm', {'en': 'L. Forearm', 'ar': 'ساعد أيسر'}, 56, 196),
  Hotspot('r-forearm', {'en': 'R. Forearm', 'ar': 'ساعد أيمن'}, 144, 196),
  Hotspot('pelvis', {'en': 'Pelvis', 'ar': 'الحوض'}, 100, 197),
  Hotspot('l-hand', {'en': 'L. Hand', 'ar': 'يد يسرى'}, 58, 212),
  Hotspot('r-hand', {'en': 'R. Hand', 'ar': 'يد يمنى'}, 142, 212),
  Hotspot('l-thigh', {'en': 'L. Thigh', 'ar': 'فخذ أيسر'}, 80, 256),
  Hotspot('r-thigh', {'en': 'R. Thigh', 'ar': 'فخذ أيمن'}, 120, 256),
  Hotspot('l-knee', {'en': 'L. Knee', 'ar': 'ركبة يسرى'}, 80, 298),
  Hotspot('r-knee', {'en': 'R. Knee', 'ar': 'ركبة يمنى'}, 120, 298),
  Hotspot('l-shin', {'en': 'L. Shin', 'ar': 'ساق يسرى'}, 80, 330),
  Hotspot('r-shin', {'en': 'R. Shin', 'ar': 'ساق يمنى'}, 120, 330),
  Hotspot('l-foot', {'en': 'L. Foot', 'ar': 'قدم يسرى'}, 80, 372),
  Hotspot('r-foot', {'en': 'R. Foot', 'ar': 'قدم يمنى'}, 120, 372),
];

const List<Hotspot> kHpBack = [
  Hotspot('bk-head', {'en': 'Head', 'ar': 'الرأس'}, 100, 32),
  Hotspot('bk-neck', {'en': 'Neck', 'ar': 'الرقبة'}, 100, 62),
  Hotspot('bk-l-shoulder', {'en': 'L. Shoulder', 'ar': 'كتف أيسر'}, 52, 89),
  Hotspot('bk-r-shoulder', {'en': 'R. Shoulder', 'ar': 'كتف أيمن'}, 148, 89),
  Hotspot('bk-upper', {'en': 'Upper back', 'ar': 'أعلى الظهر'}, 100, 110),
  Hotspot('bk-mid', {'en': 'Mid back', 'ar': 'وسط الظهر'}, 100, 140),
  Hotspot('bk-lower', {'en': 'Lower back', 'ar': 'أسفل الظهر'}, 100, 166),
  Hotspot('bk-l-glute', {'en': 'L. Glute', 'ar': 'أرداف أيسر'}, 82, 206),
  Hotspot('bk-r-glute', {'en': 'R. Glute', 'ar': 'أرداف أيمن'}, 118, 206),
  Hotspot('bk-l-hamstr', {'en': 'L. Hamstring', 'ar': 'أوتار ركبة يسرى'}, 80, 256),
  Hotspot('bk-r-hamstr', {'en': 'R. Hamstring', 'ar': 'أوتار ركبة يمنى'}, 120, 256),
  Hotspot('bk-l-calf', {'en': 'L. Calf', 'ar': 'بطة ساق يسرى'}, 80, 330),
  Hotspot('bk-r-calf', {'en': 'R. Calf', 'ar': 'بطة ساق يمنى'}, 120, 330),
  Hotspot('bk-l-heel', {'en': 'L. Heel', 'ar': 'كعب أيسر'}, 80, 358),
  Hotspot('bk-r-heel', {'en': 'R. Heel', 'ar': 'كعب أيمن'}, 120, 358),
];


/// Tappable anatomical body figure (bodymap.jsx, surface layer).
class BodyMap extends StatefulWidget {
  const BodyMap({super.key, required this.selected, required this.onToggle, this.initialGender = 'female'});
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String initialGender;
  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> {
  String view = 'front';
  late String gender = widget.initialGender;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final hotspots = view == 'front' ? kHpFront : kHpBack;
    final all = [...kHpFront, ...kHpBack].where((h) => widget.selected.contains(h.id)).map((h) => h.label.of(s.lang)).toList();
    return Column(children: [
      // Controls
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          _chip(s, s.rtl ? 'أمامي' : 'Front', view == 'front', () => setState(() => view = 'front')),
          const SizedBox(width: 5),
          _chip(s, s.rtl ? 'خلفي' : 'Back', view == 'back', () => setState(() => view = 'back')),
        ]),
        Row(children: [
          _chip(s, s.rtl ? 'أنثى' : '♀', gender == 'female', () => setState(() => gender = 'female'), neutral: true),
          const SizedBox(width: 4),
          _chip(s, s.rtl ? 'ذكر' : '♂', gender == 'male', () => setState(() => gender = 'male'), neutral: true),
        ]),
      ]),
      const SizedBox(height: 8),
      // Location label
      Text(
        widget.selected.isEmpty ? (s.rtl ? 'انقر لتحديد الموقع' : 'Tap to mark location') : all.join(' · '),
        textAlign: TextAlign.center,
        style: Typo.meta(ar: s.rtl).copyWith(
            fontSize: FS.xs, fontWeight: FontWeight.w700, letterSpacing: s.rtl ? 0 : 0.8,
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
                Positioned.fill(child: SvgPicture.asset('assets/body/${gender}_$view.svg', fit: BoxFit.contain)),
                for (final h in hotspots)
                  Positioned(
                    left: h.cx / 200 * c.maxWidth - 14,
                    top: h.cy / 384 * c.maxHeight - 14,
                    child: GestureDetector(
                      onTap: () => widget.onToggle(h.id),
                      child: SizedBox(width: 28, height: 28, child: Center(child: _dot(widget.selected.contains(h.id), s.accent))),
                    ),
                  ),
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
      width: r, height: r,
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
        height: 32, padding: const EdgeInsets.symmetric(horizontal: 13), alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? bg : Colors.white,
          borderRadius: BorderRadius.circular(T.rPill),
          border: Border.all(color: on ? border : T.border, width: 1.5),
        ),
        child: Text(label, style: Typo.meta(ar: s.rtl).copyWith(fontSize: FS.xs, fontWeight: FontWeight.w600, color: on ? color : T.fg3)),
      ),
    );
  }
}
