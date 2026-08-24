import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../storage_target.dart';
import '../tokens.dart';

/// Visual chrome for a [StorageTarget] (icon + petal). Copy is on the enum.
typedef StorageChrome = ({IconData icon, Color color, Color bg, Color border});

StorageChrome storageCfg(StorageTarget which) => switch (which) {
      StorageTarget.icloud => (
          icon: LucideIcons.cloud,
          color: T.petalBlue,
          bg: T.petalBlue50,
          border: const Color(0xFFB8D4FF),
        ),
      StorageTarget.gdrive => (
          icon: LucideIcons.cloud,
          color: T.petalMint600,
          bg: T.petalMint50,
          border: const Color(0xFFA8ECD8),
        ),
      StorageTarget.balsmCloud => (
          icon: LucideIcons.cloud,
          color: T.petalAqua,
          bg: T.petalAqua50,
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
