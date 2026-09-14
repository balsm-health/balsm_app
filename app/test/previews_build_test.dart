import 'package:app/balsm_app/previews/kit_previews.dart' as kit;
import 'package:app/balsm_app/previews/preview_harness.dart';
import 'package:app/balsm_app/previews/widget_previews.dart' as w;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every `@Preview` function must actually build.
///
/// The previewer renders a failed preview as a red error box rather than
/// failing a build, so a broken fixture is invisible until someone opens the
/// previewer and scrolls to it. These pump each preview through the same
/// harness the annotations name, which turns that into a failing test.
///
/// Kept as one list rather than a test per preview: the point is coverage of
/// the set, and a named entry in the list already identifies whichever one
/// breaks.
void main() {
  // (label, builder, wrapper) — wrapper mirrors the `wrapper:` argument on
  // each preview's own annotation, since that is the context it is declared
  // to need.
  final previews = <(String, Widget Function(), Widget Function(Widget))>[
    // kit_previews.dart
    ('PButton variants', kit.pButtonVariants, balsmPreviewPadded),
    ('PButton states', kit.pButtonStates, balsmPreviewPadded),
    ('PButton Arabic', kit.pButtonArabic, balsmPreviewAr),
    ('RoundBtn', kit.roundBtn, balsmPreviewPadded),
    ('Chevron', kit.chevron, balsmPreviewPadded),
    ('PCard', kit.pCard, balsmPreviewPadded),
    ('DashedBorder', kit.dashedBorder, balsmPreviewPadded),
    ('IconSquare', kit.iconSquare, balsmPreviewPadded),
    ('Avatar', kit.avatar, balsmPreviewPadded),
    ('AppBarRow', kit.appBarRow, balsmPreviewPadded),
    ('RowHead', kit.rowHead, balsmPreviewPadded),
    ('Pill kinds', kit.pillKinds, balsmPreviewPadded),
    ('Pill small', kit.pillSmall, balsmPreviewPadded),
    ('BChip', kit.bChip, balsmPreviewPadded),
    ('BCheck', kit.bCheck, balsmPreviewPadded),
    ('Spinner', kit.spinner, balsmPreviewPadded),
    ('RingProgress', kit.ringProgress, balsmPreviewPadded),
    ('LinearProgress', kit.linearProgress, balsmPreviewPadded),
    ('Shimmer', kit.shimmer, balsmPreviewPadded),
    ('LoadingOverlay', kit.loadingOverlay, balsmPreview),
    ('TopLoadingBar', kit.topLoadingBar, balsmPreview),
    ('RiseIn', kit.riseIn, balsmPreviewPadded),
    ('Pressable', kit.pressable, balsmPreviewPadded),
    ('PressHighlight', kit.pressHighlight, balsmPreviewPadded),
    ('Type ramp', kit.typeRamp, balsmPreviewPadded),
    ('Type ramp Arabic', kit.typeRampArabic, balsmPreviewAr),
    ('LIcon', kit.lIcon, balsmPreviewPadded),
    ('Palette', kit.palette, balsmPreviewPadded),
    ('Accents', kit.accents, balsmPreviewPadded),
    // widget_previews.dart
    ('BalsmFlower', w.balsmFlower, balsmPreviewPadded),
    ('PetalSpinner', w.petalSpinner, balsmPreviewPadded),
    ('StorageBadge', w.storageBadges, balsmPreviewPadded),
    ('MoodFace', w.moodFaces, balsmPreviewPadded),
    ('MoodFaceButton', w.moodFaceButtons, balsmPreviewPadded),
    ('LineChartView', w.lineChart, balsmPreviewPadded),
    ('LineChartView RTL', w.lineChartRtl, balsmPreviewAr),
    ('NumPad', w.numPad, balsmPreviewPadded),
    ('NumPad decimal', w.numPadDecimal, balsmPreviewPadded),
  ];

  for (final (label, build, wrapper) in previews) {
    testWidgets('$label builds', (tester) async {
      // Tall surface: several previews stack a whole family of primitives and
      // would overflow a default 800x600 test window, which would fail as a
      // layout error rather than the build error this is looking for.
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrapper(build()));
      expect(tester.takeException(), isNull);
    });
  }
}
