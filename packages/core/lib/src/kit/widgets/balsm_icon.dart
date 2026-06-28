import 'package:flutter/material.dart';
import '../_tokens.dart';

// Note: lucide_icons package added in T035al to core/pubspec.yaml.
// Import via: import 'package:lucide_icons/lucide_icons.dart';
// For now re-exporting Material icons as a standardization layer;
// individual screens import LucideIcons directly where fine-grained
// icon choice is needed.

enum BalsmIconSize {
  xs(16),
  sm(20),
  md(24);

  const BalsmIconSize(this.pt);
  final double pt;
}

enum BalsmIconWeight { outline, emphasis }

/// Standardized icon wrapper per design.md §8.
/// Default: outline 1.75pt stroke, sizes 16/20/24.
/// Emphasis: 2pt stroke (bolder appearance).
class BalsmIcon extends StatelessWidget {
  const BalsmIcon(
    this.icon, {
    super.key,
    this.size = BalsmIconSize.md,
    this.weight = BalsmIconWeight.outline,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final BalsmIconSize size;
  final BalsmIconWeight weight;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size.pt,
      color: color ?? BalsmColors.fg2,
      semanticLabel: semanticLabel,
      // Stroke weight emulated via opticalSize (best-effort on Material icons)
      opticalSize: weight == BalsmIconWeight.emphasis ? 24 : 20,
    );
  }
}
