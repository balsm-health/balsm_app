import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
      // Ours, so it does use tokens — and the petal, not a third cloud glyph
      // in a row of clouds.
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
      child: Icon(c.icon, size: 14, color: c.color),
    );
  }
}
