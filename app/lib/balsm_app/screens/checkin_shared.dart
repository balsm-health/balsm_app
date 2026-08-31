import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:self_report/self_report.dart';
import '../app_state.dart';
import '../kit.dart';
import '../tokens.dart';
import '../widgets/mood_face.dart';

/// MoodFace stroke color per level (1 = rough … 5 = great).
const moodColors = <Color>[
  T.danger,
  Color(0xFFD97A20),
  T.sun600,
  T.petalMint,
  T.petalMint600,
];

/// The self-report symptom catalog paired with its display icon. Ids come from
/// the module's [SymptomId] catalog; icons are presentation-only.
const symptomIcons = <(SymptomId, IconData)>[
  (SymptomId.headache, LucideIcons.brain),
  (SymptomId.dizzy, LucideIcons.rotateCw),
  (SymptomId.fatigue, LucideIcons.batteryLow),
  (SymptomId.blurredVision, LucideIcons.eye),
  (SymptomId.swelling, LucideIcons.droplet),
  (SymptomId.chestTightness, LucideIcons.heartPulse),
  (SymptomId.nausea, LucideIcons.frown),
  (SymptomId.thirst, LucideIcons.cupSoda),
];

String moodLabel(PatientAppState s, int lv) => switch (lv) {
      1 => s.strings.checkin.mood_1,
      2 => s.strings.checkin.mood_2,
      3 => s.strings.checkin.mood_3,
      4 => s.strings.checkin.mood_4,
      _ => s.strings.checkin.mood_5,
    };

String symptomLabel(PatientAppState s, SymptomId id) {
  final c = s.strings.checkin;
  if (id == SymptomId.headache) return c.sym_headache;
  if (id == SymptomId.dizzy) return c.sym_dizzy;
  if (id == SymptomId.fatigue) return c.sym_fatigue;
  if (id == SymptomId.blurredVision) return c.sym_blurred_vision;
  if (id == SymptomId.swelling) return c.sym_swelling;
  if (id == SymptomId.chestTightness) return c.sym_chest_tightness;
  if (id == SymptomId.nausea) return c.sym_nausea;
  if (id == SymptomId.thirst) return c.sym_thirst;
  return id.id;
}

({String lbl, Color color}) painInfo(PatientAppState s, int n) {
  final c = s.strings.checkin;
  if (n == 0) return (lbl: c.pain_0, color: T.petalMint);
  if (n <= 3) return (lbl: c.pain_mild, color: T.petalMint600);
  if (n <= 6) return (lbl: c.pain_mod, color: T.sun600);
  if (n <= 9) return (lbl: c.pain_sev, color: T.expiring);
  return (lbl: c.pain_worst, color: T.danger);
}

/// One of the five mood faces (`.mood` cell) — shared by the full check-in
/// and the one-metric log templates.
class MoodCell extends StatelessWidget {
  const MoodCell({super.key, required this.lv, required this.selected, required this.s, required this.onTap});
  final int lv;
  final bool selected;
  final PatientAppState s;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.easeOut,
            transform: Matrix4.translationValues(0, selected ? -2 : 0, 0),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? s.accent.bg : Colors.white,
              borderRadius: BorderRadius.circular(T.rLg),
              border: Border.all(color: selected ? s.accent.main : T.border, width: 1.5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              MoodFace(level: lv, size: 34, color: selected ? moodColors[lv - 1] : T.ink400),
              const SizedBox(height: 8),
              Text(moodLabel(s, lv),
                  style: Typo.meta(ar: s.rtl)
                      .copyWith(fontSize: FS.xs2, fontWeight: FontWeight.w600, color: selected ? s.accent.d : T.fg3)),
            ]),
          ),
        ),
      );
}
