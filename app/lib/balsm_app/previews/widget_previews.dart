/// Previews for the standalone presentation widgets in `balsm_app/widgets/`.
///
/// Companion to `kit_previews.dart` — same harness, same rules. Only widgets
/// that render from plain presentation inputs appear here.
///
/// ## What is deliberately absent
///
/// `BodyMap`, `NotePhotoAttach`, `UploadDropzone`, `VaultImage`,
/// `AccountSwitcher` and `LegalSheet` are not previewed. Each one either
/// renders patient data, reads the encrypted vault, or needs a live provider
/// graph — and `balsm_app/CLAUDE.md` forbids fabricating sample PHI to feed a
/// fixture. `MoodFace` and `LineChartView` appear because their inputs are a
/// bare int and a list of doubles: a mood face at level 4 and a line at
/// [3, 7, 5] are shapes, not a person's health record.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/widget_previews.dart';

import '../storage_target.dart';
import '../tokens.dart';
import '../widgets/badges.dart';
import '../widgets/balsm_mark.dart';
import '../widgets/line_chart.dart';
import '../widgets/mood_face.dart';
import '../widgets/num_pad.dart';
import 'preview_harness.dart';

// ── Brand ───────────────────────────────────────────────────────────────────

@Preview(name: 'BalsmFlower', group: 'Brand', size: Size(390, 260), wrapper: balsmPreviewPadded)
Widget balsmFlower() => const Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        BalsmFlower(size: 44),
        BalsmFlower(size: 92),
        BalsmFlower(size: 92, opacity: 0.35),
      ],
    );

@Preview(name: 'MarkSpinner', group: 'Brand', wrapper: balsmPreviewPadded)
Widget markSpinner() => const Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [MarkSpinner(size: 32), MarkSpinner(), MarkSpinner(size: 72)],
    );

// ── Badges ──────────────────────────────────────────────────────────────────

/// One badge per storage target, which is the only way to see that the four
/// stay distinguishable at a glance — the point of the badge.
@Preview(name: 'StorageBadge — all targets', group: 'Badges', size: Size(390, 240), wrapper: balsmPreviewPadded)
Widget storageBadges() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: StorageTarget.picker.map((t) => StorageBadge(storage: t)).toList(),
    );

// ── Mood ────────────────────────────────────────────────────────────────────

/// The full 1–5 range side by side. A mood scale only works if adjacent
/// levels read as different, which a single-level preview cannot show.
@Preview(name: 'MoodFace — 1 to 5', group: 'Mood', size: Size(390, 160), wrapper: balsmPreviewPadded)
Widget moodFaces() => const Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        MoodFace(level: 1, color: T.danger),
        MoodFace(level: 2, color: T.expiring),
        MoodFace(level: 3, color: T.warning),
        MoodFace(level: 4, color: T.hueMint600),
        MoodFace(level: 5, color: T.success),
      ],
    );

@Preview(name: 'MoodFaceButton', group: 'Mood', size: Size(390, 160), wrapper: balsmPreviewPadded)
Widget moodFaceButtons() => const Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        MoodFaceButton(level: 1, color: T.danger, size: 44),
        MoodFaceButton(level: 3, color: T.warning, size: 44),
        MoodFaceButton(level: 5, color: T.success, size: 44),
      ],
    );

// ── Charts ──────────────────────────────────────────────────────────────────

/// Synthetic shapes, not readings: a flat line, a rising one, and two series
/// crossing — the three cases where axis scaling and overlap go wrong.
@Preview(name: 'LineChartView', group: 'Charts', size: Size(390, 420), wrapper: balsmPreviewPadded)
Widget lineChart() => const Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 20,
      children: [
        SizedBox(
          width: 320,
          child: LineChartView(series: [
            ChartSeries([5, 5, 5, 5, 5, 5], T.hueBlue),
          ]),
        ),
        SizedBox(
          width: 320,
          child: LineChartView(series: [
            ChartSeries([1, 3, 2, 6, 5, 9], T.hueViolet),
          ]),
        ),
        SizedBox(
          width: 320,
          child: LineChartView(series: [
            ChartSeries([1, 3, 2, 6, 5, 9], T.hueViolet),
            ChartSeries([8, 6, 7, 3, 4, 2], T.hueMint600),
          ]),
        ),
      ],
    );

/// RTL mirrors the x-axis, so the same data must read right-to-left here.
@Preview(name: 'LineChartView — RTL', group: 'Charts', size: Size(390, 200), wrapper: balsmPreviewAr)
Widget lineChartRtl() => const Padding(
      padding: EdgeInsets.all(16),
      child: SizedBox(
        width: 320,
        child: LineChartView(
          rtl: true,
          series: [
            ChartSeries([1, 3, 2, 6, 5, 9], T.hueViolet),
          ],
        ),
      ),
    );

// ── Input ───────────────────────────────────────────────────────────────────

@Preview(name: 'NumPad', group: 'Input', size: Size(390, 460), wrapper: balsmPreviewPadded)
Widget numPad() => NumPad(onKey: (_) {}, onBack: () {});

@Preview(name: 'NumPad — decimal', group: 'Input', size: Size(390, 460), wrapper: balsmPreviewPadded)
Widget numPadDecimal() => NumPad(onKey: (_) {}, onBack: () {}, decimal: true, onDot: () {});
