/// Previews for the design-system primitives in `kit.dart`.
///
/// Run from `app/` with the pinned SDK's `flutter` directly, NOT through fvm —
/// see `preview_harness.dart` for why fvm breaks this one command.
///
/// The previewer only discovers `@Preview` functions under the project it is
/// started in, so everything previewable lives inside `app/lib` — widgets in
/// `packages/core` and `modules/*` are not reachable from here.
///
/// Grouped so the previewer's sidebar stays navigable: one group per family of
/// primitive, rather than three dozen flat entries.
///
/// Nothing here carries patient data. These are pure presentation primitives,
/// which is exactly why they are the first thing worth previewing — see
/// `preview_harness.dart` for the PHI rule that shapes the rest.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/widget_previews.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../kit.dart';
import '../tokens.dart';
import 'preview_harness.dart';

// ── Buttons ─────────────────────────────────────────────────────────────────

@Preview(name: 'PButton — variants', group: 'Buttons', wrapper: balsmPreviewPadded)
Widget pButtonVariants() => Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        PButton('Primary', onTap: () {}),
        PButton('Secondary', variant: BtnVariant.secondary, onTap: () {}),
        PButton('Ghost', variant: BtnVariant.ghost, onTap: () {}),
        PButton('Soft', variant: BtnVariant.soft, onTap: () {}),
        PButton('Danger', variant: BtnVariant.danger, onTap: () {}),
        PButton('Link', variant: BtnVariant.link, onTap: () {}),
      ],
    );

/// A null `onTap` is the disabled state — worth seeing beside the enabled one,
/// because "disabled" here is an absent callback rather than a flag, and it is
/// easy to ship a button that looks live and does nothing.
@Preview(name: 'PButton — states', group: 'Buttons', wrapper: balsmPreviewPadded)
Widget pButtonStates() => Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        PButton('Enabled', onTap: () {}),
        const PButton('Disabled (no onTap)'),
        PButton('With icon', icon: LucideIcons.download, onTap: () {}),
        PButton('Large', large: true, onTap: () {}),
        PButton('Gradient', gradient: true, onTap: () {}),
      ],
    );

/// Block buttons are the ones that overflow first, and Arabic is where a label
/// grows: this app ships Arabic as a first-class locale, not a translation
/// afterthought, so the RTL pass is worth its own preview rather than trust.
@Preview(name: 'PButton — Arabic / RTL', group: 'Buttons', wrapper: balsmPreviewAr)
Widget pButtonArabic() => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          PButton('حفظ التغييرات', ar: true, block: true, onTap: () {}),
          PButton('إلغاء', ar: true, variant: BtnVariant.secondary, block: true, onTap: () {}),
          PButton('تنزيل', ar: true, icon: LucideIcons.download, onTap: () {}),
        ],
      ),
    );

@Preview(name: 'RoundBtn', group: 'Buttons', wrapper: balsmPreviewPadded)
Widget roundBtn() => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        RoundBtn(icon: LucideIcons.x, onTap: () {}),
        RoundBtn(icon: LucideIcons.download, ghost: true, onTap: () {}),
        RoundBtn(icon: LucideIcons.locateFixed, bg: Colors.white, fg: T.fg2, onTap: () {}),
      ],
    );

@Preview(name: 'Chevron', group: 'Buttons', wrapper: balsmPreviewPadded)
Widget chevron() => const Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 24,
      children: [Chevron(), Chevron(rtl: true)],
    );

// ── Containers ──────────────────────────────────────────────────────────────

@Preview(name: 'PCard', group: 'Containers', size: Size(390, 260), wrapper: balsmPreviewPadded)
Widget pCard() => const Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        PCard(padding: EdgeInsets.all(16), child: Text('Default card')),
        PCard(flat: true, padding: EdgeInsets.all(16), child: Text('Flat card')),
      ],
    );

@Preview(name: 'DashedBorder', group: 'Containers', size: Size(390, 220), wrapper: balsmPreviewPadded)
Widget dashedBorder() => const DashedBorder(
      child: SizedBox(
        height: 120,
        width: 280,
        child: Center(child: Text('Drop zone')),
      ),
    );

@Preview(name: 'IconSquare', group: 'Containers', wrapper: balsmPreviewPadded)
Widget iconSquare() => const Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        IconSquare(LucideIcons.pill, bg: T.hueBlue50, fg: T.hueBlue),
        IconSquare(LucideIcons.stethoscope, bg: T.hueViolet50, fg: T.hueViolet),
        IconSquare(LucideIcons.flaskConical, bg: T.hueMint50, fg: T.hueMint600),
        IconSquare(LucideIcons.building2, bg: T.dangerBg, fg: T.danger, size: 52, iconSize: 26),
      ],
    );

@Preview(name: 'Avatar', group: 'Containers', wrapper: balsmPreviewPadded)
Widget avatar() => const Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        Avatar(initials: 'SA', color: T.hueBlue, size: 32),
        Avatar(initials: 'SA', color: T.hueViolet),
        Avatar(initials: 'SA', color: T.hueMint600, size: 64),
      ],
    );

@Preview(name: 'AppBarRow', group: 'Containers', size: Size(390, 140), wrapper: balsmPreviewPadded)
Widget appBarRow() => AppBarRow(
      leading: RoundBtn(icon: LucideIcons.arrowLeft, ghost: true, onTap: () {}),
      children: [Text('Screen title', style: Typo.subhead().copyWith(fontWeight: FontWeight.w700))],
    );

@Preview(name: 'RowHead', group: 'Containers', size: Size(390, 120), wrapper: balsmPreviewPadded)
Widget rowHead() => RowHead('Section title', action: 'See all', onAction: () {});

// ── Labels ──────────────────────────────────────────────────────────────────

/// Every pill kind at once: a status palette only works if the kinds stay
/// distinguishable from each other, which a single-kind preview cannot show.
@Preview(name: 'Pill — all kinds', group: 'Labels', size: Size(390, 260), wrapper: balsmPreviewPadded)
Widget pillKinds() => const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Pill('Success', kind: PillKind.success),
        Pill('Info', kind: PillKind.info),
        Pill('Warn', kind: PillKind.warn),
        Pill('Danger', kind: PillKind.danger),
        Pill('Violet', kind: PillKind.violet),
        Pill('Expiring', kind: PillKind.expiring),
        Pill('Emerald', kind: PillKind.emerald),
        Pill('Neutral', kind: PillKind.neutral),
        Pill('Brand', kind: PillKind.brand),
        Pill('Outline', kind: PillKind.outline),
      ],
    );

@Preview(name: 'Pill — small / no dot', group: 'Labels', wrapper: balsmPreviewPadded)
Widget pillSmall() => const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Pill('Small', kind: PillKind.info, small: true),
        Pill('No dot', kind: PillKind.info, dot: false),
        Pill('صغير', kind: PillKind.info, small: true, ar: true),
      ],
    );

@Preview(name: 'BChip', group: 'Labels', wrapper: balsmPreviewPadded)
Widget bChip() => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        BChip('Inactive', active: false, accent: T.hueViolet, onTap: () {}),
        BChip('Active', active: true, accent: T.hueViolet, onTap: () {}),
        BChip('Blue accent', active: true, accent: T.hueBlue, onTap: () {}),
      ],
    );

@Preview(name: 'BCheck — checkbox & radio', group: 'Labels', size: Size(390, 240), wrapper: balsmPreviewPadded)
Widget bCheck() => Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        BCheck(label: 'Unchecked', checked: false, accent: Accent.violet, onTap: () {}),
        BCheck(label: 'Checked', checked: true, accent: Accent.violet, onTap: () {}),
        BCheck(label: 'Radio off', checked: false, radio: true, accent: Accent.violet, onTap: () {}),
        BCheck(label: 'Radio on', checked: true, radio: true, accent: Accent.violet, onTap: () {}),
      ],
    );

// ── Progress & loading ──────────────────────────────────────────────────────

@Preview(name: 'Spinner', group: 'Progress', wrapper: balsmPreviewPadded)
Widget spinner() => const Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        Spinner(size: 18, stroke: 2),
        Spinner(),
        Spinner(size: 44, stroke: 4, color: T.hueViolet),
      ],
    );

/// 0 and 1 are the two values a ring most often gets wrong — an empty ring
/// that still paints a cap, and a full one that leaves a hairline gap.
@Preview(name: 'RingProgress', group: 'Progress', size: Size(390, 180), wrapper: balsmPreviewPadded)
Widget ringProgress() => const Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        RingProgress(progress: 0, color: T.hueViolet, label: '0%'),
        RingProgress(progress: 0.35, color: T.hueViolet, label: '35%'),
        RingProgress(progress: 1, color: T.hueMint600, label: 'Done'),
      ],
    );

@Preview(name: 'LinearProgress', group: 'Progress', size: Size(390, 200), wrapper: balsmPreviewPadded)
Widget linearProgress() => const Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        LinearProgress(value: 0),
        LinearProgress(value: 0.45),
        LinearProgress(value: 1),
        LinearProgress(indeterminate: true),
      ],
    );

@Preview(name: 'Shimmer', group: 'Progress', size: Size(390, 220), wrapper: balsmPreviewPadded)
Widget shimmer() => const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Shimmer(width: 260),
        Shimmer(width: 200),
        Shimmer(width: 240),
        Shimmer(width: 44, height: 44, circle: true),
      ],
    );

@Preview(name: 'LoadingOverlay', group: 'Progress', size: Size(390, 300), wrapper: balsmPreview)
Widget loadingOverlay() => const SizedBox(
      height: 280,
      width: 360,
      child: LoadingOverlay(message: 'Loading…', scrim: true),
    );

@Preview(name: 'TopLoadingBar', group: 'Progress', size: Size(390, 100), wrapper: balsmPreview)
Widget topLoadingBar() => const SizedBox(
      height: 80,
      width: 360,
      child: Align(alignment: Alignment.topCenter, child: TopLoadingBar(loading: true)),
    );

// ── Motion ──────────────────────────────────────────────────────────────────

@Preview(name: 'RiseIn', group: 'Motion', size: Size(390, 220), wrapper: balsmPreviewPadded)
Widget riseIn() => const RiseIn(
      child: PCard(padding: EdgeInsets.all(16), child: Text('Rises in on mount')),
    );

@Preview(name: 'Pressable', group: 'Motion', size: Size(390, 200), wrapper: balsmPreviewPadded)
Widget pressable() => Pressable(
      onTap: () {},
      child: const PCard(padding: EdgeInsets.all(16), child: Text('Scales on press')),
    );

@Preview(name: 'PressHighlight', group: 'Motion', size: Size(390, 200), wrapper: balsmPreviewPadded)
Widget pressHighlight() => PressHighlight(
      onTap: () {},
      radius: T.rLg,
      child: const Padding(padding: EdgeInsets.all(16), child: Text('Tints on press')),
    );

// ── Typography ──────────────────────────────────────────────────────────────

/// The whole ramp on one surface, which is the only way to catch a step that
/// no longer reads as distinct from its neighbour.
@Preview(name: 'Type ramp', group: 'Typography', size: Size(390, 460), wrapper: balsmPreviewPadded)
Widget typeRamp() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text('Display', style: Typo.display()),
        Text('Title', style: Typo.title()),
        Text('Heading', style: Typo.heading()),
        Text('Subhead', style: Typo.subhead()),
        Text('Body', style: Typo.body()),
        Text('Body small', style: Typo.bodySm()),
        Text('Meta', style: Typo.meta()),
        Text('Numerals 0123456789', style: Typo.num()),
        Text('Mono 0123456789', style: Typo.mono()),
      ],
    );

/// The same ramp in Arabic. A different face is used per script, so a step
/// that reads correctly in Latin can still collide or clip here — the two
/// previews are worth comparing side by side rather than trusting one.
@Preview(name: 'Type ramp — Arabic', group: 'Typography', size: Size(390, 460), wrapper: balsmPreviewAr)
Widget typeRampArabic() => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text('عنوان كبير', style: Typo.display(ar: true)),
          Text('عنوان', style: Typo.title(ar: true)),
          Text('ترويسة', style: Typo.heading(ar: true)),
          Text('عنوان فرعي', style: Typo.subhead(ar: true)),
          Text('نص أساسي', style: Typo.body(ar: true)),
          Text('نص صغير', style: Typo.bodySm(ar: true)),
          Text('بيانات وصفية', style: Typo.meta(ar: true)),
        ],
      ),
    );

@Preview(name: 'LIcon', group: 'Typography', wrapper: balsmPreviewPadded)
Widget lIcon() => const Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        LIcon(LucideIcons.heart, size: 18),
        LIcon(LucideIcons.pill, size: 24),
        LIcon(LucideIcons.stethoscope, size: 32, color: T.hueViolet),
        LIcon(LucideIcons.flaskConical, size: 32, stroke: 2.6),
      ],
    );

// ── Colour ──────────────────────────────────────────────────────────────────

/// Every colour token on one surface. A palette is the one thing that has to
/// be seen rather than read: a hex in a diff says nothing about whether two
/// swatches are still distinguishable from each other.
@Preview(name: 'Palette', group: 'Colour', size: Size(390, 560), wrapper: balsmPreviewPadded)
Widget palette() => const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        _Swatches('Hues', [T.hueAqua, T.hueEmerald, T.hueBlue, T.hueMint, T.hueViolet]),
        _Swatches('Hues 600', [
          T.hueAqua600,
          T.hueEmerald600,
          T.hueBlue600,
          T.hueMint600,
          T.hueViolet600,
        ]),
        _Swatches('Ink', [T.ink900, T.ink700, T.ink500, T.ink300, T.ink100]),
        _Swatches('Status', [T.success, T.warning, T.danger, T.controlled, T.expiring]),
        _Swatches('Cream', [T.cream50, T.cream100, T.cream200]),
        _Swatches('Sun', [T.sun400, T.sun500, T.sun600]),
      ],
    );

/// Each accent the app can be themed with, so a change to one is checked
/// against the rest rather than in isolation.
@Preview(name: 'Accents', group: 'Colour', size: Size(390, 320), wrapper: balsmPreviewPadded)
Widget accents() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        _Swatches('blue', [Accent.blue.main, Accent.blue.d, Accent.blue.bg]),
        _Swatches('aqua', [Accent.aqua.main, Accent.aqua.d, Accent.aqua.bg]),
        _Swatches('emerald', [Accent.emerald.main, Accent.emerald.d, Accent.emerald.bg]),
        _Swatches('violet', [Accent.violet.main, Accent.violet.d, Accent.violet.bg]),
        _Swatches('mint', [Accent.mint.main, Accent.mint.d, Accent.mint.bg]),
      ],
    );

class _Swatches extends StatelessWidget {
  const _Swatches(this.label, this.colors);

  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Typo.meta()),
          const SizedBox(height: 4),
          Row(
            children: colors
                .map((c) => Container(
                      width: 52,
                      height: 38,
                      margin: const EdgeInsetsDirectional.only(end: 6),
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(T.rSm),
                        border: Border.all(color: T.border),
                      ),
                    ))
                .toList(),
          ),
        ],
      );
}
