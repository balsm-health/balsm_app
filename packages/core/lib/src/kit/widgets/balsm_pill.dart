import 'package:material_ui/material_ui.dart';
import '../tokens.dart';

enum BalsmPillVariant { success, warn, danger, neutral, info, controlled }

/// Status pill porting prototype `.pill`.
/// Optional leading dot (6×6 colored circle).
class BalsmPill extends StatelessWidget {
  const BalsmPill({
    required this.label,
    required this.variant,
    super.key,
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
        borderRadius: BorderRadius.circular(AppRadii.pill),
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
              fontSize: FontSizes.meta,
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
        return const _PillStyle(
          bg: AppColors.successBackground,
          fg: AppColors.onSuccessBackground,
          dot: AppColors.hueMint,
        );
      case BalsmPillVariant.warn:
        return const _PillStyle(
          bg: AppColors.warningBackground,
          fg: AppColors.onWarningBackground,
          dot: AppColors.warning,
        );
      case BalsmPillVariant.danger:
        return const _PillStyle(
          bg: AppColors.dangerBackground,
          fg: AppColors.onDangerBackground,
          dot: AppColors.danger,
        );
      case BalsmPillVariant.neutral:
        return const _PillStyle(
          bg: AppColors.ink100,
          fg: AppColors.ink700,
          dot: AppColors.ink500,
        );
      case BalsmPillVariant.info:
        return const _PillStyle(
          bg: AppColors.hueBlue50,
          fg: AppColors.onInfoBackground,
          dot: AppColors.hueBlue,
        );
      case BalsmPillVariant.controlled:
        return const _PillStyle(
          bg: AppColors.controlledBackground,
          fg: AppColors.onControlledBackground,
          dot: AppColors.controlled,
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
