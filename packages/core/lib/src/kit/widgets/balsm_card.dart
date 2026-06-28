import 'package:flutter/material.dart';
import '../_tokens.dart';

enum BalsmCardVariant { standard, accent, danger, cream }

/// Card porting prototype `.card` (white, border, radius-lg, shadow-sm).
/// Variants: standard (white), accent (blue-50 gradient), danger (danger-bg), cream (cream-100).
class BalsmCard extends StatelessWidget {
  const BalsmCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.variant = BalsmCardVariant.standard,
  });

  const BalsmCard.accent({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  }) : variant = BalsmCardVariant.accent;

  const BalsmCard.danger({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  }) : variant = BalsmCardVariant.danger;

  const BalsmCard.cream({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  }) : variant = BalsmCardVariant.cream;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BalsmCardVariant variant;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        gradient: _gradient,
        borderRadius: BorderRadius.circular(BalsmRadius.lg),
        border: Border.all(color: BalsmColors.border),
        boxShadow: BalsmShadow.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BalsmRadius.lg),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  Color? get _bgColor {
    switch (variant) {
      case BalsmCardVariant.standard:
        return BalsmColors.surface;
      case BalsmCardVariant.danger:
        return BalsmColors.dangerBg;
      case BalsmCardVariant.cream:
        return BalsmColors.cream100;
      case BalsmCardVariant.accent:
        return null; // uses gradient
    }
  }

  Gradient? get _gradient {
    if (variant == BalsmCardVariant.accent) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [BalsmColors.petalBlue50, Color(0xFFEAF3FF)],
      );
    }
    return null;
  }
}
