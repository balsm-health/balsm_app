import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../data.dart';
import '../tokens.dart';

({IconData icon, Color color, Color bg, Color border, L label}) storageCfg(String which) => switch (which) {
      'icloud' => (icon: LucideIcons.cloud, color: T.petalBlue, bg: T.petalBlue50, border: const Color(0xFFB8D4FF), label: const {'en': 'iCloud', 'ar': 'آي كلاود'}),
      'gdrive' => (icon: LucideIcons.cloud, color: T.petalMint600, bg: T.petalMint50, border: const Color(0xFFA8ECD8), label: const {'en': 'Google Drive', 'ar': 'جوجل درايف'}),
      _ => (icon: LucideIcons.smartphone, color: T.ink600, bg: T.ink100, border: T.ink200, label: const {'en': 'On this device', 'ar': 'على هذا الجهاز'}),
    };

/// Small storage indicator chip.
class StorageBadge extends StatelessWidget {
  const StorageBadge({super.key, required this.storage});
  final String storage;
  @override
  Widget build(BuildContext context) {
    final c = storageCfg(storage);
    return Container(
      width: 26, height: 26, alignment: Alignment.center,
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(T.rSm)),
      child: Icon(c.icon, size: 14, color: c.color),
    );
  }
}
