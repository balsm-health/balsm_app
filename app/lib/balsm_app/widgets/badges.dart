import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../assets.dart';
import '../storage_target.dart';
import '../tokens.dart';

/// Visual chrome for a [StorageTarget] (icon + hue). Copy is on the enum.
typedef StorageChrome = ({IconData icon, Color color, Color bg, Color border});

StorageChrome storageCfg(StorageTarget which) => switch (which) {
      StorageTarget.icloud => (
          icon: LucideIcons.cloud,
          color: T.hueBlue,
          bg: T.hueBlue50,
          border: const Color(0xFFB8D4FF),
        ),
      // Drive keeps Google's own green rather than a Balsm hue: it is a vendor
      // mark in a list of vendors, and `storage.jsx` sets it literally for the
      // same reason. Deliberately not a token.
      StorageTarget.gdrive => (
          icon: LucideIcons.folderOpen,
          color: const Color(0xFF1E8E3E),
          bg: const Color(0xFFE6F4EA),
          border: const Color(0xFFB3DFBB),
        ),
      // Ours, so it does use tokens. Drawn as the Balsm mark by [StorageIcon];
      // `icon` here is only the glyph fallback.
      StorageTarget.balsmCloud => (
          icon: LucideIcons.flower,
          color: T.hueAqua600,
          bg: T.hueAqua50,
          border: const Color(0xFFB8EDE8),
        ),
      StorageTarget.local => (
          icon: LucideIcons.smartphone,
          color: T.ink600,
          bg: T.ink100,
          border: T.ink200,
        ),
    };

/// `BRAND_ICONS` in the design's `base.jsx`: the clouds are drawn as their own
/// marks, not as Lucide stand-ins.
const _kICloudSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 42"><path d="M17 42C7.6 42 0 35.3 0 27c0-7 5.4-12.9 12.7-14.6C15.4 5.1 22.6 0 31 0c9.2 0 17 6.1 19 14.4C58 15 64 21 64 28.5 64 36 57.8 42 50 42H17z" fill="#2B8CF7"/></svg>';
const _kGDriveSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 87.3 78"><path d="m6.6 66.85 3.85 6.65c.8 1.4 1.95 2.5 3.3 3.3l13.75-23.8h-27.5c0 1.55.4 3.1 1.2 4.5z" fill="#0066da"/><path d="m43.65 25-13.75-23.8c-1.35.8-2.5 1.9-3.3 3.3l-25.4 44a9.06 9.06 0 0 0 -1.2 4.5h27.5z" fill="#00ac47"/><path d="m73.55 76.8c1.35-.8 2.5-1.9 3.3-3.3l1.6-2.75 7.65-13.25c.8-1.4 1.2-2.95 1.2-4.5h-27.502l5.852 11.5z" fill="#ea4335"/><path d="m43.65 25 13.75-23.8c-1.35-.8-2.9-1.2-4.5-1.2h-18.5c-1.6 0-3.15.45-4.5 1.2z" fill="#00832d"/><path d="m59.8 53h-32.3l-13.75 23.8c1.35.8 2.9 1.2 4.5 1.2h50.8c1.6 0 3.15-.45 4.5-1.2z" fill="#2684fc"/><path d="m73.4 26.5-12.7-22c-.8-1.4-1.95-2.5-3.3-3.3l-13.75 23.8 16.15 28h27.45c0-1.55-.4-3.1-1.2-4.5z" fill="#ffba00"/></svg>';

/// `filter: grayscale(1)` as a colour matrix (Rec. 709 luma).
const _kGrayscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// The glyph for a [StorageTarget] — `Icon` in the design's `base.jsx`.
///
/// The three clouds are vendor marks in their own colours (iCloud, Google
/// Drive, the Balsm mark), so [color] applies to the device glyph only.
/// [muted] is the design's `grayscale(1) opacity(.55)`, for a cloud that is
/// off or not connected.
class StorageIcon extends StatelessWidget {
  const StorageIcon(this.target, {super.key, required this.size, this.color, this.muted = false});
  final StorageTarget target;
  final double size;
  final Color? color;
  final bool muted;

  /// Whether [target] is drawn as a brand mark rather than a tinted glyph.
  static bool isBrand(StorageTarget t) => !t.isLocal;

  @override
  Widget build(BuildContext context) {
    final Widget mark = switch (target) {
      StorageTarget.local => Icon(storageCfg(target).icon, size: size, color: color),
      StorageTarget.icloud => SvgPicture.string(_kICloudSvg, width: size, height: size),
      StorageTarget.gdrive => SvgPicture.string(_kGDriveSvg, width: size, height: size),
      StorageTarget.balsmCloud => SvgPicture.asset(Assets.brand_icon, width: size, height: size),
    };
    if (target.isLocal) return mark;
    final boxed = SizedBox(width: size, height: size, child: Center(child: mark));
    if (!muted) return boxed;
    return Opacity(opacity: 0.55, child: ColorFiltered(colorFilter: _kGrayscale, child: boxed));
  }
}

/// Small storage indicator chip.
class StorageBadge extends StatelessWidget {
  const StorageBadge({super.key, required this.storage});
  final StorageTarget storage;
  @override
  Widget build(BuildContext context) {
    final c = storageCfg(storage);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(T.rSm)),
      child: StorageIcon(storage, size: 14, color: c.color),
    );
  }
}
