import 'package:flutter/material.dart';
import '../_tokens.dart';

enum BalsmPillVariant { success, warn, danger, neutral, info, controlled }

/// Status pill porting prototype `.pill`.
/// Optional leading dot (6×6 colored circle).
class BalsmPill extends StatelessWidget {
  const BalsmPill({
    super.key,
    required this.label,
    required this.variant,
    this.showDot = false,
  });

  final String label;
  final BalsmPillVariant variant;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(variant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(BalsmRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: style.dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: style.fg,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  _PillStyle _styleFor(BalsmPillVariant v) {
    switch (v) {
      case BalsmPillVariant.success:
        return _PillStyle(
          bg: BalsmColors.successBg,
          fg: const Color(0xFF1F6A36),
          dot: BalsmColors.petalMint,
        );
      case BalsmPillVariant.warn:
        return _PillStyle(
          bg: BalsmColors.warningBg,
          fg: const Color(0xFF7A5A0F),
          dot: BalsmColors.warning,
        );
      case BalsmPillVariant.danger:
        return _PillStyle(
          bg: BalsmColors.dangerBg,
          fg: const Color(0xFF7A2A20),
          dot: BalsmColors.danger,
        );
      case BalsmPillVariant.neutral:
        return _PillStyle(
          bg: BalsmColors.ink100,
          fg: BalsmColors.ink700,
          dot: BalsmColors.ink500,
        );
      case BalsmPillVariant.info:
        return _PillStyle(
          bg: BalsmColors.petalBlue50,
          fg: const Color(0xFF08407A),
          dot: BalsmColors.petalBlue,
        );
      case BalsmPillVariant.controlled:
        return _PillStyle(
          bg: BalsmColors.controlledBg,
          fg: const Color(0xFF3D2872),
          dot: BalsmColors.controlled,
        );
    }
  }
}

class _PillStyle {
  const _PillStyle({required this.bg, required this.fg, required this.dot});
  final Color bg;
  final Color fg;
  final Color dot;
}
